// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SafeL2} from "@safe-contracts/SafeL2.sol";
import {SafeProxyFactory} from "@safe-contracts/proxies/SafeProxyFactory.sol";
import {TokenCallbackHandler} from "@safe-contracts/handler/TokenCallbackHandler.sol";

import {ISafe} from "@src/interfaces/ISafe.sol";

import {Kernel, Policy, Permissions, Keycode} from "@src/Kernel.sol";
import {toKeycode} from "@src/libraries/KernelUtils.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {Storage} from "@src/modules/Storage.sol";
import {Stop} from "@src/policies/Stop.sol";
import {Guard} from "@src/policies/Guard.sol";

/**
 * @title Factory
 * @notice Acts as an interface for all behavior related to deploying rental safes.
 */
contract Factory is Policy {
    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    // Modules that the policy depends on.
    Storage public STORE;

    // policies.
    Stop public immutable stopPolicy;
    Guard public immutable guardPolicy;

    // External contracts.
    TokenCallbackHandler public immutable fallbackHandler;
    SafeProxyFactory public immutable safeProxyFactory;
    SafeL2 public immutable safeSingleton;

    /**
     * @dev Instantiate this contract as a policy.
     *
     * @param kernel_           Address of the kernel contract.
     * @param stopPolicy_       Address of the stop policy.
     * @param guardPolicy_      Address of the guard policy.
     * @param fallbackHandler_  Gnosis safe fallback handler address.
     * @param safeProxyFactory_ Gnosis safe proxy factory address.
     * @param safeSingleton_    Gnosis safe logic contract address.
     */
    constructor(
        Kernel kernel_,
        Stop stopPolicy_,
        Guard guardPolicy_,
        TokenCallbackHandler fallbackHandler_,
        SafeProxyFactory safeProxyFactory_,
        SafeL2 safeSingleton_
    ) Policy(kernel_) {
        stopPolicy = stopPolicy_;
        guardPolicy = guardPolicy_;
        fallbackHandler = fallbackHandler_;
        safeProxyFactory = safeProxyFactory_;
        safeSingleton = safeSingleton_;
    }

    /**
     * @notice Upon policy activation, configures the modules that the policy depends on.
     *         If a module is ever upgraded that this policy depends on, the kernel will
     *         call this function again to ensure this policy has the current address
     *         of the module.
     *
     * @return dependencies Array of keycodes which represent modules that
     *                      this policy depends on.
     */
    function configureDependencies()
        external
        override
        onlyKernel
        returns (Keycode[] memory dependencies)
    {
        dependencies = new Keycode[](1);

        dependencies[0] = toKeycode("STORE");
        STORE = Storage(getModuleAddress(toKeycode("STORE")));
    }

    /**
     * @notice Upon policy activation, permissions are requested from the kernel to access
     *         particular keycode <> function selector pairs. Once these permissions are
     *         granted, they do not change and can only be revoked when the policy is
     *         deactivated by the kernel.
     *
     * @return requests Array of keycode <> function selector pairs which represent
     *                  permissions for the policy.
     */
    function requestPermissions()
        external
        view
        override
        onlyKernel
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](1);
        requests[0] = Permissions(toKeycode("STORE"), STORE.addRentalSafe.selector);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Initializes a rental safe by setting it up with the stop policy and
     *         rental guard during deployment.
     *
     *          Warning: This function assumes the invariant that delegate call will be
     *          disabled or restricted by the guard policy. If delegate call were to be
     *          freely allowed, then a safe could call this function after deployment
     *          and change the module/guard contacts which would allow transferring
     *          of rented assets out of the safe.
     *
     * @param _stopPolicy  Address of the stop policy to add as a module to the safe.
     * @param _guardPolicy Address of the guard policy to add as a guard on the safe.
     */
    function initializeRentalSafe(address _stopPolicy, address _guardPolicy) external {
        // Enable the module.
        ISafe(address(this)).enableModule(_stopPolicy);

        // Set the guard.
        ISafe(address(this)).setGuard(_guardPolicy);
    }

    /**
     * @notice Deploys and initializes a rental safe.
     *
     * @param owners    Array of owner addresses which will have the ability to sign
     *                  transactions for the safe.
     * @param threshold Number of signatures required to executed a transaction
     *                  on the safe.
     */
    function deployRentalSafe(
        address[] calldata owners,
        uint256 threshold
    ) external returns (address safe) {
        // Require that the threshold is valid.
        if (threshold == 0 || threshold > owners.length) {
            revert Errors.FactoryPolicy_InvalidSafeThreshold(threshold, owners.length);
        }

        // Delegate call from the safe so that the rental manager module can be enabled
        // right after the safe is deployed.
        bytes memory data = abi.encodeCall(
            Factory.initializeRentalSafe,
            (address(stopPolicy), address(guardPolicy))
        );

        // Create gnosis initializer payload.
        bytes memory initializerPayload = abi.encodeCall(
            ISafe.setup,
            (
                // owners array.
                owners,
                // number of signatures needed to execute transactions.
                threshold,
                // Address to direct the payload to.
                address(this),
                // Encoded call to execute.
                data,
                // Fallback manager address.
                address(fallbackHandler),
                // Payment token.
                address(0),
                // Payment amount.
                0,
                // Payment receiver
                payable(address(0))
            )
        );

        // Deploy a safe proxy using initializer values for the Safe.setup() call
        // with a salt nonce that is unique to each chain to guarantee cross-chain
        // unique safe addresses.
        safe = address(
            safeProxyFactory.createProxyWithNonce(
                address(safeSingleton),
                initializerPayload,
                uint256(keccak256(abi.encode(STORE.totalSafes() + 1, block.chainid)))
            )
        );

        // Store the deployed safe.
        STORE.addRentalSafe(safe);

        // Emit the event.
        emit Events.RentalSafeDeployment(safe, owners, threshold);
    }
}
