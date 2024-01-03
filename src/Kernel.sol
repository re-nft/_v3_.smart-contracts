// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    toRole,
    ensureContract,
    ensureValidKeycode,
    ensureValidRole
} from "@src/libraries/KernelUtils.sol";
import {Actions, Keycode, Role, Permissions} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "src/libraries/Events.sol";

/////////////////////////////////////////////////////////////////////////////////
//                         Module Abstract Contracts                           //
/////////////////////////////////////////////////////////////////////////////////

/**
 * @title KernelAdapter
 * @notice A base contract to be inherited by both policies and modules. Provides common
 *         access to logic related to the kernel contract.
 */
abstract contract KernelAdapter {
    // The active kernel contract.
    Kernel public kernel;

    /**
     * @dev Instantiate this contract as a a kernel adapter. When using a proxy, the kernel address
     *      should be set to address(0).
     *
     * @param kernel_ Address of the kernel contract.
     */
    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    /**
     * @dev Modifier which only allows calls from the active kernel contract.
     */
    modifier onlyKernel() {
        if (msg.sender != address(kernel))
            revert Errors.KernelAdapter_OnlyKernel(msg.sender);
        _;
    }

    /**
     * @notice Points the adapter to reference a new kernel address. This function can
     *         only be called by the active kernel, and is used to perform migrations by
     *         telling all policies and modules where the new kernel is located before
     *         actually performing the migration.
     *
     * @param newKernel_  Address of the new kernel contract.
     */
    function changeKernel(Kernel newKernel_) external onlyKernel {
        kernel = newKernel_;
    }
}

/**
 * @title Module
 * @notice A base contract to be inherited by all module implementations. Provides common
 *         logic related to module functionality.
 */
abstract contract Module is KernelAdapter {
    /**
     * @dev Instantiate this contract as a a module. When using a proxy, the kernel address
     *      should be set to address(0).
     *
     * @param kernel_ Address of the kernel contract.
     */
    constructor(Kernel kernel_) KernelAdapter(kernel_) {}

    /**
     * @dev Modifier which only allows calls to the module if the policy contract making the
     *      call has been given explicit permission by the kernel first.
     */
    modifier permissioned() {
        if (!kernel.modulePermissions(KEYCODE(), Policy(msg.sender), msg.sig)) {
            revert Errors.Module_PolicyNotAuthorized(msg.sender);
        }
        _;
    }

    /**
     * @notice The 5-character keycode used to uniquely represent the module. This
     *         must be implemented by the inheriting contract.
     *
     * @return Keycode represented by the module.
     */
    function KEYCODE() public pure virtual returns (Keycode);

    /**
     * @notice Specifies the version of the module being implemented. Minor version
     *         changes retain the interface, and major version upgrades indicated
     *         breaking changes to the interface.
     *
     * @return major Major version of the module.
     * @return minor Minor version of the module.
     */
    function VERSION() external pure virtual returns (uint8 major, uint8 minor) {}

    /**
     * @notice Initialization function for the module which is called when the module is
     *         first installed or upgraded by the kernel. Can only be called by the kernel.
     */
    function INIT() external virtual onlyKernel {}
}

/**
 * @title Policy
 * @notice A base contract to be inherited by all policy implementations. Provides common
 *         logic related to policy functionality.
 */
abstract contract Policy is KernelAdapter {
    // Whether the policy is active or not.
    bool public isActive;

    /**
     * @dev Instantiate this contract as a a policy. When using a proxy, the kernel address
     *      should be set to address(0).
     *
     * @param kernel_ Address of the kernel contract.
     */
    constructor(Kernel kernel_) KernelAdapter(kernel_) {}

    /**
     * @dev Modifier which only allows calls from addresses which have explicitly been
     *      granted a role by the kernel.
     */
    modifier onlyRole(bytes32 role_) {
        Role role = toRole(role_);
        if (!kernel.hasRole(msg.sender, role)) {
            revert Errors.Policy_OnlyRole(role);
        }
        _;
    }

    /**
     * @notice When a policy is activated, it must respond with all of the module
     *         keycodes that it depends on. The kernel stores these dependencies as a
     *         mapping from module keycode to an array of policies that depend on it.
     *         This is useful because when a module is upgraded, it can know exactly
     *         the policies that depend upon it and call out to each policy to
     *         reconfigure its dependencies to use the upgraded module contract address.
     *
     * @param dependencies Keycodes of all the modules that the policy depends on.
     */
    function configureDependencies()
        external
        virtual
        onlyKernel
        returns (Keycode[] memory dependencies)
    {}

    /**
     * @notice When a policy is activated, it must respond with a series of
     *         keycode <> function selector pairs which represent a request for the
     *         policy to call a specific function selector at a specific module.
     *         These requests are stored as a mapping in the kernel while the policy
     *         is active, and the kernel will reject any call from a policy to a module
     *         which has not first requested permission.
     *
     * @param requests Keycode <> function selector pairs which define the module access
     *                 requested by a policy.
     */
    function requestPermissions()
        external
        view
        virtual
        onlyKernel
        returns (Permissions[] memory requests)
    {}

    /**
     * @dev Used by a policy to get the current address of a module
     *      at a specific keycode.
     *
     * @param keycode_ Keycode used to get the address of the module.
     */
    function getModuleAddress(Keycode keycode_) internal view returns (address) {
        address moduleForKeycode = address(kernel.getModuleForKeycode(keycode_));
        if (moduleForKeycode == address(0))
            revert Errors.Policy_ModuleDoesNotExist(keycode_);
        return moduleForKeycode;
    }

    /**
     * @notice Allows the kernel to grant or revoke the active status of the policy.
     *
     * @param activate_ Whether to activate or deactivate the policy.
     */
    function setActiveStatus(bool activate_) external onlyKernel {
        isActive = activate_;
    }
}

/////////////////////////////////////////////////////////////////////////////////
//                               Kernel Contract                               //
/////////////////////////////////////////////////////////////////////////////////

/**
 * @title Kernel
 * @notice A registry contract that manages a set of policy and module contracts, as well
 *         as the permissions to interact with those contracts.
 */
contract Kernel {
    // Admin addresses.
    address public executor;
    address public admin;

    // Module Management.
    Keycode[] public allKeycodes;
    mapping(Keycode => Module) public getModuleForKeycode; // get contract for module keycode.
    mapping(Module => Keycode) public getKeycodeForModule; // get module keycode for contract.

    // Module dependents data. Manages module dependencies for policies.
    mapping(Keycode => Policy[]) public moduleDependents;
    mapping(Keycode => mapping(Policy => uint256)) public getDependentIndex;

    // Module <> Policy Permissions. Keycode -> Policy -> Function Selector -> Permission.
    mapping(Keycode => mapping(Policy => mapping(bytes4 => bool)))
        public modulePermissions; // for policy addr, check if they have permission to call the function in the module.

    // List of all active policies.
    Policy[] public activePolicies;
    mapping(Policy => uint256) public getPolicyIndex;

    // Policy roles data.
    mapping(address => mapping(Role => bool)) public hasRole;
    mapping(Role => bool) public isRole;

    /////////////////////////////////////////////////////////////////////////////////
    //                                Constructor                                  //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Instantiate the kernel with executor and admin addresses.
     *
     * @param _executor Address in charge of handling kernel executions.
     * @param _admin    Address in charge of granting and revoking roles.
     */
    constructor(address _executor, address _admin) {
        executor = _executor;
        admin = _admin;
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                                Modifiers                                    //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Modifier which only allows calls by an executing address.
     */
    modifier onlyExecutor() {
        if (msg.sender != executor) revert Errors.Kernel_OnlyExecutor(msg.sender);
        _;
    }

    /**
     * @dev modifier which only allows calls by an admin address.
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Errors.Kernel_OnlyAdmin(msg.sender);
        _;
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Executes an action on a target address.
     *
     * @param action_ Action which will be performed.
     * @param target_ Address upon which the action will operate.
     */
    function executeAction(Actions action_, address target_) external onlyExecutor {
        if (action_ == Actions.InstallModule) {
            ensureContract(target_);
            ensureValidKeycode(Module(target_).KEYCODE());
            _installModule(Module(target_));
        } else if (action_ == Actions.UpgradeModule) {
            ensureContract(target_);
            ensureValidKeycode(Module(target_).KEYCODE());
            _upgradeModule(Module(target_));
        } else if (action_ == Actions.ActivatePolicy) {
            ensureContract(target_);
            _activatePolicy(Policy(target_));
        } else if (action_ == Actions.DeactivatePolicy) {
            ensureContract(target_);
            _deactivatePolicy(Policy(target_));
        } else if (action_ == Actions.MigrateKernel) {
            ensureContract(target_);
            _migrateKernel(Kernel(target_));
        } else if (action_ == Actions.ChangeExecutor) {
            executor = target_;
        } else if (action_ == Actions.ChangeAdmin) {
            admin = target_;
        }

        emit Events.ActionExecuted(action_, target_);
    }

    /**
     * @dev Grants a role to the target address.
     *
     * @param role_ Role to grant to the target.
     * @param addr_ Address that will receive the role.
     */
    function grantRole(Role role_, address addr_) public onlyAdmin {
        // Check that the address does not already have the role.
        if (hasRole[addr_][role_])
            revert Errors.Kernel_AddressAlreadyHasRole(addr_, role_);

        // Ensure the role is properly formatted.
        ensureValidRole(role_);

        // Mark this role as having been granted.
        if (!isRole[role_]) isRole[role_] = true;

        // Grant the role to the target.
        hasRole[addr_][role_] = true;

        emit Events.RoleGranted(role_, addr_);
    }

    /**
     * @dev Revokes a role from the target address.
     *
     * @param role_ Role to revoke from the target.
     * @param addr_ Address that will have the role removed.
     */
    function revokeRole(Role role_, address addr_) public onlyAdmin {
        // Check if the role has been granted before.
        if (!isRole[role_]) revert Errors.Kernel_RoleDoesNotExist(role_);

        // Check if the target address currently has the role.
        if (!hasRole[addr_][role_])
            revert Errors.Kernel_AddressDoesNotHaveRole(addr_, role_);

        // Revoke the role.
        hasRole[addr_][role_] = false;

        emit Events.RoleRevoked(role_, addr_);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            Internal Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Installs a new module into the kernel.
     *
     * @param newModule_ Address of the new module.
     */
    function _installModule(Module newModule_) internal {
        // Fetch the module keycode.
        Keycode keycode = newModule_.KEYCODE();

        // Make sure the keycode isnt in use already.
        if (address(getModuleForKeycode[keycode]) != address(0)) {
            revert Errors.Kernel_ModuleAlreadyInstalled(keycode);
        }

        // Connect the keycode to the module address.
        getModuleForKeycode[keycode] = newModule_;

        // Connect the module address to the keycode.
        getKeycodeForModule[newModule_] = keycode;

        // Keep a running array of all module keycodes.
        allKeycodes.push(keycode);

        // Initialize the module contract.
        newModule_.INIT();
    }

    /**
     * @dev Upgrades a module by changing the address that the keycode points to.
     *
     * @param newModule_ Address of the new module.
     */
    function _upgradeModule(Module newModule_) internal {
        // Get the keycode of the new module
        Keycode keycode = newModule_.KEYCODE();

        // Get the address of the old module
        Module oldModule = getModuleForKeycode[keycode];

        // Check that the old module contract exists, and that the old module
        // address is not the same as the new module
        if (address(oldModule) == address(0) || oldModule == newModule_) {
            revert Errors.Kernel_InvalidModuleUpgrade(keycode);
        }

        // The old module no longer points to the keycode.
        getKeycodeForModule[oldModule] = Keycode.wrap(bytes5(0));

        // The new module points to the keycode.
        getKeycodeForModule[newModule_] = keycode;

        // The keycode points to the new module.
        getModuleForKeycode[keycode] = newModule_;

        // Initialize the new module contract.
        newModule_.INIT();

        // Reconfigure policies so that all policies that depended on the old
        // module will refetch the new module address from the kernel.
        _reconfigurePolicies(keycode);
    }

    /**
     * @dev Activates a new policy into the kernel.
     *
     * @param policy_ Address of the policy to activate.
     */
    function _activatePolicy(Policy policy_) internal {
        // Ensure that the policy is not already active.
        if (policy_.isActive())
            revert Errors.Kernel_PolicyAlreadyApproved(address(policy_));

        // Grant permissions for policy to access restricted module functions.
        Permissions[] memory requests = policy_.requestPermissions();
        _setPolicyPermissions(policy_, requests, true);

        // Add policy to list of active policies.
        activePolicies.push(policy_);

        // Set the index of the policy in the array of active policies.
        getPolicyIndex[policy_] = activePolicies.length - 1;

        // Fetch module dependencies.
        Keycode[] memory dependencies = policy_.configureDependencies();
        uint256 depLength = dependencies.length;

        // Loop through each keycode the policy depends on.
        for (uint256 i; i < depLength; ++i) {
            Keycode keycode = dependencies[i];

            // Push the policy to the array of dependents for the keycode
            moduleDependents[keycode].push(policy_);

            // Set the index of the policy in the array of dependents.
            getDependentIndex[keycode][policy_] = moduleDependents[keycode].length - 1;
        }

        // Set policy status to active.
        policy_.setActiveStatus(true);
    }

    /**
     * @dev Deactivates an active policy from the kernel
     *
     * @param policy_ Address of the policy to deactivate.
     */
    function _deactivatePolicy(Policy policy_) internal {
        if (!policy_.isActive()) revert Errors.Kernel_PolicyNotApproved(address(policy_));

        // Fetch originally granted permissions from the policy
        // and then revoke them.
        Permissions[] memory requests = policy_.requestPermissions();
        _setPolicyPermissions(policy_, requests, false);

        // Get the index of the policy in the active policies array.
        uint256 idx = getPolicyIndex[policy_];

        // Get the index of the last policy in the active policy array.
        Policy lastPolicy = activePolicies[activePolicies.length - 1];

        // Set the last policy at the index of the policy to deactivate.
        activePolicies[idx] = lastPolicy;

        // Pop the last policy from the array.
        activePolicies.pop();

        // Set the last policy's index to the index of the policy
        // that was removed.
        getPolicyIndex[lastPolicy] = idx;

        // Delete the index of the policy being deactivated.
        delete getPolicyIndex[policy_];

        // Remove policy from array of dependents for each keycode
        // that the policy depends upon.
        _pruneFromDependents(policy_);

        // Set policy status to inactive.
        policy_.setActiveStatus(false);
    }

    /**
     * @dev Migrates the kernel to a new contract.
     *
     *      WARNING: THIS ACTION WILL BRICK THIS KERNEL.
     *
     *      By performing a migration, this kernel will no longer have any authority
     *      over the current policies and modules.
     *
     *      All functionality will move to the new kernel. The new kernel will need
     *      to add all of the modules and policies again via `executeAction`. Until
     *      all policies and modules are re-activated on the new kernel, policies will
     *      not be able to access permissioned functions on modules, and privileged
     *      addresses will not be able to access role-gated functions on policies.
     *
     * @param newKernel_ Address of the new kernel.
     */
    function _migrateKernel(Kernel newKernel_) internal {
        uint256 keycodeLen = allKeycodes.length;

        // For each keycode stored in the kernel.
        for (uint256 i; i < keycodeLen; ++i) {
            // get the module represented by the keycode.
            Module module = Module(getModuleForKeycode[allKeycodes[i]]);
            // Instruct the module to change the kernel.
            module.changeKernel(newKernel_);
        }

        // For each active policy stored in the kernel
        uint256 policiesLen = activePolicies.length;
        for (uint256 j; j < policiesLen; ++j) {
            // Get the policy.
            Policy policy = activePolicies[j];

            // Deactivate the policy before changing kernel.
            policy.setActiveStatus(false);

            // Instruct the policy to change the kernel.
            policy.changeKernel(newKernel_);
        }
    }

    /**
     * @dev All policies that are dependent on the module represented by the keycode
     *      must be reconfigured so that the policies can request the current
     *      address of the module from the kernel.
     *
     * @param keycode_ Keycode representing the module.
     */
    function _reconfigurePolicies(Keycode keycode_) internal {
        // Get an array of all policies that depend on the keycode.
        Policy[] memory dependents = moduleDependents[keycode_];
        uint256 depLength = dependents.length;

        // Loop through each policy.
        for (uint256 i; i < depLength; ++i) {
            // Reconfigure its dependencies.
            dependents[i].configureDependencies();
        }
    }

    /**
     * @dev Sets the permissions for a policy to interact with a module. Once the policy has
     *      been activated, these permissions do not change until the policy is deactivated.
     *
     * @param policy_   Address of the policy.
     * @param requests_ Permission requests comprised of keycode and function selector pairs.
     * @param grant_    Whether to grant these permissions or revoke them.
     */
    function _setPolicyPermissions(
        Policy policy_,
        Permissions[] memory requests_,
        bool grant_
    ) internal {
        uint256 reqLength = requests_.length;
        for (uint256 i = 0; i < reqLength; ++i) {
            // Set the permission for the keycode -> policy -> function selector.
            Permissions memory request = requests_[i];
            modulePermissions[request.keycode][policy_][request.funcSelector] = grant_;

            emit Events.PermissionsUpdated(
                request.keycode,
                policy_,
                request.funcSelector,
                grant_
            );
        }
    }

    /**
     * @dev All keycodes store an array of the policies that depend upon them,
     *      so a policy must be pruned from this array when it is deactivated.
     *
     * @param policy_ Address of the policy to prune from the dependency array.
     */
    function _pruneFromDependents(Policy policy_) internal {
        // Retrieve all keycodes that the policy is dependent upon.
        Keycode[] memory dependencies = policy_.configureDependencies();
        uint256 depcLength = dependencies.length;

        // Loop through each keycode.
        for (uint256 i; i < depcLength; ++i) {
            // Get the stored array of policies that depend on the keycode.
            Keycode keycode = dependencies[i];
            Policy[] storage dependents = moduleDependents[keycode];

            // Get the index of the policy to prune in the array.
            uint256 origIndex = getDependentIndex[keycode][policy_];

            // Get the address of the last policy in the array.
            Policy lastPolicy = dependents[dependents.length - 1];

            // Overwrite the last policy with the policy being pruned.
            dependents[origIndex] = lastPolicy;

            // Since the last policy exists twice now in the array, pop it
            // from the end of the array.
            dependents.pop();

            // Set the index of the swapped policy to its correct spot.
            getDependentIndex[keycode][lastPolicy] = origIndex;

            // Delete the index of the of the pruned policy.
            delete getDependentIndex[keycode][policy_];
        }
    }
}
