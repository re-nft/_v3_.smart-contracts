// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ItemType, Role, Keycode} from "@src/libraries/RentalStructs.sol";

import {
    ItemType as SeaportItemType,
    OrderType as SeaportOrderType
} from "@seaport-types/lib/ConsiderationStructs.sol";

/**
 * @title Errors
 * @notice Contains errors defined for the protocol.
 */
library Errors {
    /////////////////////////////////////////////////////////////////////////////////
    //                                     Shared                                  //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when an order is assigned an invalid OrderType.
     *
     * @param orderType The invalid order type enum value.
     */
    error Shared_OrderTypeNotSupported(uint8 orderType);

    /**
     * @dev Thrown when trying to interact with a hook that is disabled.
     *
     * @param hook The hook addess on which an interaction was attempted.
     */
    error Shared_DisabledHook(address hook);

    /**
     * @dev Thrown when a hook is specified for a non-ERC721 or non-ERC1155 item.
     *
     * @param itemIndex The index of the invalid item.
     */
    error Shared_NonRentalHookItem(uint256 itemIndex);

    /**
     * @dev Thrown when execution flow reverts during a call to a hook.
     *
     * @param revertReason The reason the execution reverted, as a string.
     */
    error Shared_HookFailString(string revertReason);

    /**
     * @dev Thrown when execution flow reverts during a call to a hook.
     *
     * @param revertData The reason the execution reverted, as bytes.
     */
    error Shared_HookFailBytes(bytes revertData);

    /**
     * @dev Thrown when an ERC20 transfer failed.
     *
     * @param token Address of the token being transferred.
     * @param from  Address that the token was sent from.
     * @param to    Address that the token was sent to.
     * @param value Amount of the token sent.
     */
    error Shared_ERC20TransferFailed(
        address token,
        address from,
        address to,
        uint256 value
    );

    /////////////////////////////////////////////////////////////////////////////////
    //                                 Create Policy                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when an order contains a Seaport item type that is not supported.
     *
     * @param itemType The seaport item type that is not supported.
     */
    error CreatePolicy_SeaportItemTypeNotSupported(SeaportItemType itemType);

    /**
     * @dev Thrown when an order contains a Seaport order type that is not supported.
     *
     * @param orderType The seaport order type that is not supported.
     */
    error CreatePolicy_SeaportOrderTypeNotSupported(SeaportOrderType orderType);

    /**
     * @dev Thrown when a `RentPayload` was signed with an expected order hash that was
     *      not used when fulfilling the order.
     *
     * @param payloadOrderHash Order hash that the payload expects.
     * @param seaportOrderHash Order hash of the order being fulfilled.
     */
    error CreatePolicy_InvalidPayloadForOrderHash(
        bytes32 payloadOrderHash,
        bytes32 seaportOrderHash
    );

    /**
     * @dev Thrown when the total number of offer items in an order is zero.
     */
    error CreatePolicy_OfferCountZero();

    /**
     * @dev Thrown when the total number of offer items in an order exceeds the maximum
     * 		amount allowed.
     *
     * @param offerCount Number of offer items in the order.
     */
    error CreatePolicy_OfferCountExceedsMax(uint256 offerCount);

    /**
     * @dev Thrown when the total number of offer items in an order is greater than zero.
     *
     * @param offerCount Number of offer items in the order.
     */
    error CreatePolicy_OfferCountNonZero(uint256 offerCount);

    /**
     * @dev Thrown when the total number of consideration items in an order is zero.
     */
    error CreatePolicy_ConsiderationCountZero();

    /**
     * @dev Thrown when the total number of consideration items in an order exceeds
     * 		the maximum	amount allowed.
     *
     * @param considerationCount Number of consideration items in the order.
     */
    error CreatePolicy_ConsiderationCountExceedsMax(uint256 considerationCount);

    /**
     * @dev Thrown when the total number of consideration items in an order is greater
     * 		than zero.
     *
     * @param considerationCount Number of consideration items in the order.
     */
    error CreatePolicy_ConsiderationCountNonZero(uint256 considerationCount);

    /**
     * @dev Thrown when the recipient of a token is unexpected.
     *
     * @param itemType      The seaport item type of the token.
     * @param token         Address of the token.
     * @param identifier    ID of the token.
     * @param amount        Amount of the token sent.
     * @param currentOwner  Address the token was actually sent to.
     * @param expectedOwner Address the token was expected to be sent to.
     */
    error CreatePolicy_UnexpectedTokenRecipient(
        SeaportItemType itemType,
        address token,
        uint256 identifier,
        uint256 amount,
        address currentOwner,
        address expectedOwner
    );

    /**
     * @dev Thrown when the count of either rental or payment items are zero.
     *
     * @param totalRentals  Total items in the orde which are rented assets.
     * @param totalPayments Total items in the order which are payments.
     */
    error CreatePolicy_ItemCountZero(uint256 totalRentals, uint256 totalPayments);

    /**
     * @dev Thrown when the recipient of a consideration payment is not set to the proper
     *      payment escrow contract.
     *
     * @param paymentRecipient Recipient address of the payment tokens.
     */
    error CreatePolicy_UnexpectedPaymentEscrowRecipient(address paymentRecipient);

    /**
     * @dev Thrown when a rent duration that is too long is specified.
     */
    error CreatePolicy_RentDurationTooLong(uint256 rentDuration);

    /**
     * @dev Thrown when a rent duration of zero is specified.
     */
    error CreatePolicy_RentDurationZero();

    /**
     * @dev Thrown when order metadata does not match zone hash.
     */
    error CreatePolicy_InvalidOrderMetadataHash();

    /**
     * @dev Thrown when the recipient is not a protocol-deployed safe.
     *
     * @param safe Address of the non-protocol safe.
     */
    error CreatePolicy_InvalidRentalSafe(address safe);

    /**
     * @dev Thrown when the fulfiller is not the owner of the recipient rental safe.
     *
     * @param unauthorizedOwner Address which is not an owner of the rental safe.
     * @param safe              Address of the rental safe.
     */
    error CreatePolicy_InvalidSafeOwner(address unauthorizedOwner, address safe);

    /**
     * @dev Thrown when a consideration item has the offerer selected as a recipient.
     */
    error CreatePolicy_OffererCannotBeRecipient();

    /**
     * @dev Thrown when an unauthorized address signs a create policy payloads.
     *
     * @param signer Address that signed the rent payload.
     */
    error CreatePolicy_UnauthorizedCreatePolicySigner(address signer);

    /**
     * @dev Thrown when creating a rental with an asset that does not exist
     *      in the whitelist.
     */
    error CreatePolicy_AssetNotWhitelisted(address token);

    /**
     * @dev Thrown when creating a rental with a payment that does not exist
     *      in the whitelist.
     */
    error CreatePolicy_PaymentNotWhitelisted(address token);

    /////////////////////////////////////////////////////////////////////////////////
    //                                  Stop Policy                                //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when an order hash does not exist.
     *
     * @param orderHash Hash of the rental order.
     */
    error StopPolicy_OrderDoesNotExist(bytes32 orderHash);

    /**
     * @dev Thrown when an order is stopped in the same transaction that it was started.
     *
     */
    error StopPolicy_StoppedTooSoon();

    /**
     * @dev Thrown when either the timestamp or the stopper address is invalid when
     *      stopping an order.
     *
     * @param timestamp Current timestamp of the attempted rental stop.
     * @param stopper   Address that initiated the rental stop.
     */
    error StopPolicy_CannotStopOrder(uint256 timestamp, address stopper);

    /**
     * @dev Thrown when the call to reclaim assets from a rental wallet fails.
     */
    error StopPolicy_ReclaimFailed();

    /////////////////////////////////////////////////////////////////////////////////
    //                                Factory Policy                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when attempting to deploy a safe with an incompatible threshhold and
     *      number of owners.
     *
     * @param threshold Minimum number of owners needed to sign a transaction.
     * @param owners    Maximum number of owners for the safe.
     */
    error FactoryPolicy_InvalidSafeThreshold(uint256 threshold, uint256 owners);

    /////////////////////////////////////////////////////////////////////////////////
    //                                 Guard Policy                                //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when attempting to call a restricted function selector on a rented
     *      item.
     *
     * @param selector Four byte selector of the call.
     */
    error GuardPolicy_UnauthorizedSelector(bytes4 selector);

    /**
     * @dev Thrown when attempting to call a restricted function selector with an amount
     *      that would result in less tokens being left in the safe than are actively
     *      rented out.
     *
     * @param selector Four byte selector of the call.
     * @param rentedAmount Amount that is actively rented.
     * @param remainingBalance Invalid remaining balance if the call had succeeded.
     */
    error GuardPolicy_UnauthorizedAssetAmount(
        bytes4 selector,
        uint256 rentedAmount,
        uint256 remainingBalance
    );

    /**
     * @dev Thrown when an unauthorized call to change the enabled/disabled status
     *      of an extension is made.
     *
     * @param extension An extension contract for the rental safe to add as a module.
     */
    error GuardPolicy_UnauthorizedExtension(address extension);

    /**
     * @dev Thrown when a target delegate call address is not whitelisted.
     *
     * @param to Address to direct a delegate call.
     */
    error GuardPolicy_UnauthorizedDelegateCall(address to);

    /**
     * @dev Thrown when attempting to execute a transaction throught a Guard Policy that
     *      is no longer active.
     */
    error GuardPolicy_Deactivated();

    /////////////////////////////////////////////////////////////////////////////////
    //                               Fallback Policy                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when attempting to validate a message hash that was not signed
     *      by any owners of the rental safe.
     *
     * @param messageHash Message digest that was signed.
     */
    error FallbackPolicy_HashNotSigned(bytes32 messageHash);

    /**
     * @dev Thrown when a signature is attempting to be validated from a token
     *      contract that has been whitelisted for renting on the protocol. This
     *      error is thrown to protect the assets from token approvals being gaslessly
     *      signed to transfer the asset from the rental safe.abi
     *
     * @param sender Address that requested the signature validation.
     */
    error FallbackPolicy_UnauthorizedSender(address sender);

    /**
     * @dev Thrown when attempting to validate a contract signature through the Fallback
     *      Policy that is no longer active.
     */
    error FallbackPolicy_Deactivated();

    /////////////////////////////////////////////////////////////////////////////////
    //                             Payment Escrow Module                           //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when attempting to make a payment of 0.
     */
    error PaymentEscrow_ZeroPayment();

    /**
     * @dev Thrown when attempting to see a fee numerator too high.
     */
    error PaymentEscrow_InvalidFeeNumerator();

    /////////////////////////////////////////////////////////////////////////////////
    //                                 Storage Module                              //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when attempting to enable a hook using a non-contract address.
     *
     * @param addr Address of the hook.
     */
    error StorageModule_NotContract(address addr);

    /**
     * @dev Thrown when an invalid bitmap is provided to the hook status.
     *
     * @param bitmap Used to identify what functions the hook supports.
     */
    error StorageModule_InvalidHookStatusBitmap(uint8 bitmap);

    /**
     * @dev Thrown when an invalid bitmap is provided to a whitelist.
     *
     * @param bitmap Used to identify the value of the whitelist.
     */
    error StorageModule_InvalidWhitelistBitmap(uint8 bitmap);

    /**
     * @dev Thrown when making a batch update to a token whitelist and the array of
     *  	tokens is not the same length as the array of booleans that distinguish
     * 		whether the asset is whitelisted or not.
     *
     * @param assetLength Length of the asset array.
     * @param boolLength Length of the bool array.
     */
    error StorageModule_WhitelistBatchLengthMismatch(
        uint256 assetLength,
        uint256 boolLength
    );

    /////////////////////////////////////////////////////////////////////////////////
    //                               Create2 Deployer                              //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when deployment has already been made at the address.
     *
     * @param deployed Address of the already deployed contract.
     * @param salt     Salt used to generated the address.
     */
    error Create2Deployer_AlreadyDeployed(address deployed, bytes32 salt);

    /**
     * @dev Thrown when deployment address and actual deployment address did not match.
     *
     * @param expected Expected deployment address based on the salt provided.
     * @param actual   Actual deployment address of the contract.
     */
    error Create2Deployer_MismatchedDeploymentAddress(address expected, address actual);

    /**
     * @dev Thrown when the salt does not begin with the sender.
     *
     * @param sender Address of the account initiating the deployment.
     * @param salt   Salt used to create the deployment.
     */
    error Create2Deployer_UnauthorizedSender(address sender, bytes32 salt);

    /////////////////////////////////////////////////////////////////////////////////
    //                              Reclaimer Package                              //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when interacting with the reclaimer without a delegate call.
     */
    error ReclaimerPackage_OnlyDelegateCallAllowed();

    /**
     * @dev Thrown when the initiator of the reclaim is not the rental wallet.
     *
     * @param reclaimer Address that attempted the reclaim.
     */
    error ReclaimerPackage_OnlyRentalSafeAllowed(address reclaimer);

    /////////////////////////////////////////////////////////////////////////////////
    //                                Signer Package                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when an unauthorized address attempts to fulfill an order.
     *
     * @param unauthorized Address that attempted the fulfillment.
     * @param expected     Address that was expected to be the fulfiller.
     */
    error SignerPackage_UnauthorizedFulfiller(address unauthorized, address expected);

    /**
     * @dev Thrown when a rental payload signature has expired.
     *
     * @param currentTimestamp Current timestamp when the signature was checked.
     * @param expiredAt        Timestamp that the signature expired.
     */
    error SignerPackage_SignatureExpired(uint256 currentTimestamp, uint256 expiredAt);

    /////////////////////////////////////////////////////////////////////////////////
    //                                    Proxy                                    //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when attempting to upgrade to a non-compatible proxy contract.
     *
     * @param newImplementation Address of the new proxy implementation contract.
     */
    error Proxy_NotCompatible(address newImplementation);

    /**
     * @dev Thrown when attempting to upgrade a frozen contract.
     */
    error Proxy_Frozen();

    /**
     * @dev Thrown when making a non-proxy call.
     */
    error Proxy_OnlyCallByProxy();

    /**
     * @dev Thrown when trying to initialize a proxy twice.
     */
    error Proxy_AlreadyInitialized();

    /////////////////////////////////////////////////////////////////////////////////
    //                              Kernel Adapter                                 //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when attempting to call a function that is only callable by the Kernel.
     *      The kernel is the only address authorized to migrate the kernel contract,
     *      initialize modules, and configure dependencies and permissions on policies.
     *
     * @param caller_ Address that attempted the call.
     */
    error KernelAdapter_OnlyKernel(address caller_);

    /////////////////////////////////////////////////////////////////////////////////
    //                                   Module                                    //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when a policy contract attempts to interact with a function on a
     *      module contract that it has not explicitly been given permission to access.
     *
     * @param policy_ Address of the policy contract attempting to make the call.
     */
    error Module_PolicyNotAuthorized(address policy_);

    /////////////////////////////////////////////////////////////////////////////////
    //                                   Policy                                    //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when an address attempts to call a function on a policy contract,
     *      but has not been authorized with the proper role first.
     *
     * @param role_ The role the caller must have to access the function.
     */
    error Policy_OnlyRole(Role role_);

    /**
     * @dev Thrown when a policy attempts to interact with module via a keycode that does
     *      not point to a module.
     *
     * @param keycode_ The keycode used to point to a module.
     */
    error Policy_ModuleDoesNotExist(Keycode keycode_);

    /////////////////////////////////////////////////////////////////////////////////
    //                                   Kernel                                    //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when attempting to access a function that is only reserved for the
     *      kernel executor role.
     *
     * @param caller_ Address that attempted a call to an executor-only function.
     */
    error Kernel_OnlyExecutor(address caller_);

    /**
     * @dev Thrown when attempting to access a function that is only reserved for the
     *      kernel admin role.
     *
     * @param caller_ Address that attemped a call to an admin-only function.
     */
    error Kernel_OnlyAdmin(address caller_);

    /**
     * @dev Thrown when attempting to install a module with a 5-character keycode
     *      that is already in use by another module.
     *
     * @param module_ Keycode for the module that is already in use.
     */
    error Kernel_ModuleAlreadyInstalled(Keycode module_);

    /**
     * @dev Thrown when an upgrade for a module is invalid. This can occur for two
     *      reasons: either the keycode to upgrade never had a module installed using it
     *      in the first place, or the module address to upgrade to is the same address
     *      as the previous module.
     *
     * @param module_ keycode for the module to upgrade.
     */
    error Kernel_InvalidModuleUpgrade(Keycode module_);

    /**
     * @dev Thrown when attempting to activate a policy that has already been activated.
     *      This action cannot be done more than once on a single policy, unless it is
     *      deactivated first.
     *
     * @param policy_ Address of the policy contract attempting the activation.
     */
    error Kernel_PolicyAlreadyApproved(address policy_);

    /**
     * @dev Thrown when attempting to deactivate a policy that has either already been
     *      deactivated or was never activated in the first place.
     *
     * @param policy_ Address of the policy contract attempting the deactivation.
     */
    error Kernel_PolicyNotApproved(address policy_);

    /**
     * @dev Thrown when attempting to grant a role to an address that has already been
     *      granted that role.
     *
     * @param addr_ Address receiving the role.
     * @param role_ Role to grant to the target address.
     */
    error Kernel_AddressAlreadyHasRole(address addr_, Role role_);

    /**
     * @dev Thrown when attempting to revoke a role from an address that has either
     *      already had the role revoked or was never granted the role in the first place.
     *
     * @param addr_ Address giving up the role.
     * @param role_ Role to revoke from the target address.
     */
    error Kernel_AddressDoesNotHaveRole(address addr_, Role role_);

    /**
     * @dev Thrown when attempting to revoke a role that has never been granted to
     *      any address.
     *
     * @param role_ Role which has never been granted.
     */
    error Kernel_RoleDoesNotExist(Role role_);

    /**
     * @dev Thrown when the target is not a contract
     *
     * @param target_ The address to check if it is a contract.
     */
    error Kernel_TargetNotAContract(address target_);

    /**
     * @dev Thrown when the keycode provided is invalid.
     *
     * @param keycode_ The five character keycode to check.
     */
    error Kernel_InvalidKeycode(Keycode keycode_);

    /**
     *
     * @dev Thrown when the role provided is invalid.
     *
     * @param role_ The role to check.
     */
    error Kernel_InvalidRole(Role role_);
}
