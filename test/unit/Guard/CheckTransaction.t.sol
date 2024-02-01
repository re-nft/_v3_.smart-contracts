// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Enum} from "@safe-contracts/common/Enum.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {
    e721_transfer_from_selector,
    e721_safe_transfer_from_1_selector,
    e721_safe_transfer_from_2_selector,
    e721_approve_selector,
    e721_burn_selector,
    e1155_safe_transfer_from_selector,
    e1155_safe_batch_transfer_from_selector,
    e1155_burn_selector,
    e1155_burn_batch_selector,
    shared_set_approval_for_all_selector,
    gnosis_safe_set_guard_selector,
    gnosis_safe_enable_module_selector,
    gnosis_safe_disable_module_selector,
    gnosis_safe_set_fallback_handler_selector
} from "@src/libraries/RentalConstants.sol";
import {RentalUtils} from "@src/libraries/RentalUtils.sol";
import {RentalAssetUpdate, RentalId} from "@src/libraries/RentalStructs.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {
    MockHook_Success,
    MockHook_CheckTransactionRevert,
    MockHook_CheckTransactionRequire,
    MockHook_CheckTransactionPanic,
    MockHookErrors
} from "@test/mocks/MockHook.sol";
import {MockTarget} from "@test/mocks/MockTarget.sol";

// Tests functionality on the guard related to transaction checking
contract Guard_CheckTransaction_Unit_Test is BaseTestWithoutEngine {
    // Mock target contract that a hook will be placed between
    MockTarget public mockTarget;

    function setUp() public override {
        super.setUp();

        // set up a mock target contract
        mockTarget = new MockTarget();
    }

    // helper function to check a transaction
    function _checkTransaction(
        address from,
        address to,
        bytes memory transactionCalldata
    ) public {
        vm.prank(from);
        guard.checkTransaction(
            to,
            0 ether,
            transactionCalldata,
            Enum.Operation.Call,
            0,
            0,
            0 ether,
            ZERO_ADDRESS,
            payable(ZERO_ADDRESS),
            bytes(""),
            ZERO_ADDRESS
        );
    }

    // helper function for expecting a revert by unauthorized sender
    function _checkTransactionRevertUnauthorizedSelector(
        address from,
        address to,
        bytes4 unauthorizedSelector,
        bytes memory transactionCalldata
    ) internal {
        // Expect revert because of an unauthorized function selector
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.GuardPolicy_UnauthorizedSelector.selector,
                unauthorizedSelector
            )
        );

        // check the transaction
        _checkTransaction(from, to, transactionCalldata);
    }

    function _checkTransactionRevertUnauthorizedExtension(
        address from,
        address to,
        bytes memory transactionCalldata
    ) internal {
        // Expect revert because of an unauthorized extension
        vm.expectRevert(
            abi.encodeWithSelector(Errors.GuardPolicy_UnauthorizedExtension.selector, to)
        );

        // check the transaction
        _checkTransaction(from, to, transactionCalldata);
    }

    // helper function to mark rental IDs as active
    function _markRentalsAsActive(RentalAssetUpdate[] memory rentalAssets) internal {
        vm.prank(address(create));
        STORE.addRentals(keccak256(abi.encode("someRentalOrderHash")), rentalAssets);
    }

    function test_Success_CheckTransaction_DelegateCallAllowed() public {
        // impersonate the guard admin
        vm.startPrank(deployer.addr);

        // enable the target address to be delegate called by rental safes
        admin.toggleWhitelistDelegate(address(mockTarget), true);

        // check the transaction
        guard.checkTransaction(
            address(mockTarget),
            0 ether,
            hex"a0b1c2d3",
            Enum.Operation.DelegateCall,
            0,
            0,
            0 ether,
            ZERO_ADDRESS,
            payable(ZERO_ADDRESS),
            bytes(""),
            ZERO_ADDRESS
        );
    }

    function test_Reverts_CheckTransaction_DelegateCallNotAllowed() public {
        // expect revert because the target hasnt been whitelisted for delegatecall
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.GuardPolicy_UnauthorizedDelegateCall.selector,
                address(mockTarget)
            )
        );
        guard.checkTransaction(
            address(mockTarget),
            0 ether,
            hex"a0b1c2d3",
            Enum.Operation.DelegateCall,
            0,
            0,
            0 ether,
            ZERO_ADDRESS,
            payable(ZERO_ADDRESS),
            bytes(""),
            ZERO_ADDRESS
        );
    }

    function test_Reverts_CheckTransaction_NotEnoughData() public {
        // expect revert because the data is not long enough
        vm.expectRevert(
            abi.encodeWithSelector(Errors.GuardPolicy_FunctionSelectorRequired.selector)
        );

        // check the transaction
        _checkTransaction(address(this), address(mockTarget), hex"a0b1c2");
    }

    function test_Success_CheckTransaction_ForwardToHook() public {
        // deploy a mock hook contract
        MockHook_Success hook = new MockHook_Success();

        // impersonate the guard admin
        vm.startPrank(deployer.addr);

        // create a path from the hook to the target
        guard.updateHookPath(address(mockTarget), address(hook));

        // enable the `onTransaction` hook
        guard.updateHookStatus(address(hook), uint8(1));

        // stop impersonating
        vm.stopPrank();

        // check the transaction
        _checkTransaction(address(this), address(mockTarget), hex"a0b1c2d3");

        // assert that the hook was successfully reached
        assertTrue(hook.transactionChecked());
    }

    function test_Reverts_CheckTransaction_ForwardToHook_RevertFailure() public {
        // deploy a mock hook contract which will revert
        MockHook_CheckTransactionRevert hook = new MockHook_CheckTransactionRevert();

        // impersonate the guard admin
        vm.startPrank(deployer.addr);

        // create a path from the hook to the target
        guard.updateHookPath(address(mockTarget), address(hook));

        // enable the `onTransaction` hook
        guard.updateHookStatus(address(hook), uint8(1));

        // stop impersonating
        vm.stopPrank();

        // expect revert because the hook will fail with a revert.
        // the revert data will contain the function selector of the
        // custom error that reverted in the hook contract
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_HookFailBytes.selector,
                abi.encodeWithSelector(MockHookErrors.CheckTransactionRevert.selector)
            )
        );

        // check the transaction
        _checkTransaction(address(this), address(mockTarget), hex"a0b1c2d3");
    }

    function test_Reverts_CheckTransaction_ForwardToHook_RequireFailure() public {
        // deploy a mock hook contract which will cause a failed `require`
        MockHook_CheckTransactionRequire hook = new MockHook_CheckTransactionRequire();

        // impersonate the guard admin
        vm.startPrank(deployer.addr);

        // create a path from the hook to the target
        guard.updateHookPath(address(mockTarget), address(hook));

        // enable the `onTransaction` hook
        guard.updateHookStatus(address(hook), uint8(1));

        // stop impersonating
        vm.stopPrank();

        // expect revert because the hook will fail with a `require`
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "CheckTransactionRequire"
            )
        );

        // check the transaction
        _checkTransaction(address(this), address(mockTarget), hex"a0b1c2d3");
    }

    function test_Reverts_CheckTransaction_ForwardToHook_PanicFailure() public {
        // deploy a mock hook contract which will cause a panic
        MockHook_CheckTransactionPanic hook = new MockHook_CheckTransactionPanic();

        // impersonate the guard admin
        vm.startPrank(deployer.addr);

        // create a path from the hook to the target
        guard.updateHookPath(address(mockTarget), address(hook));

        // enable the `onTransaction` hook
        guard.updateHookStatus(address(hook), uint8(1));

        // stop impersonating
        vm.stopPrank();

        // expect revert because the hook will fail with a `require`
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Shared_HookFailString.selector,
                "Hook reverted: Panic code 17"
            )
        );

        // check the transaction
        _checkTransaction(address(this), address(mockTarget), hex"a0b1c2d3");
    }

    function test_Success_CheckTransaction_ERC721_TransferFrom() public {
        // Build up the `transferFrom(address from, address to, uint256 tokenId)` calldata
        bytes memory transferFromCalldata = abi.encodeWithSelector(
            e721_transfer_from_selector,
            alice.addr,
            bob.addr,
            0
        );

        // check the transaction
        _checkTransaction(address(this), address(erc721s[0]), transferFromCalldata);
    }

    function test_Success_CheckTransaction_ERC721_SafeTransferFrom() public {
        // Build up the `safeTransferFrom(address,address,uint256)` calldata
        bytes memory safeTransferFromCalldata = abi.encodeWithSelector(
            e721_safe_transfer_from_1_selector,
            alice.addr,
            bob.addr,
            0
        );

        // check the transaction
        _checkTransaction(address(this), address(erc721s[0]), safeTransferFromCalldata);
    }

    function test_Success_CheckTransaction_ERC721_SafeTransferFrom_WithData() public {
        // Build up the `safeTransferFrom(address,address,uint256,bytes)` calldata
        bytes memory safeTransferFromWithDataCalldata = abi.encodeWithSelector(
            e721_safe_transfer_from_2_selector,
            alice.addr,
            bob.addr,
            0,
            bytes("")
        );

        // check the transaction
        _checkTransaction(
            address(this),
            address(erc721s[0]),
            safeTransferFromWithDataCalldata
        );
    }

    function test_Success_CheckTransaction_ERC721_Approve() public {
        // Build up the `approve(address,uint256)` calldata
        bytes memory approveCalldata = abi.encodeWithSelector(
            e721_approve_selector,
            bob.addr,
            0
        );

        // Check the transaction
        _checkTransaction(address(this), address(erc721s[0]), approveCalldata);
    }

    function test_Success_CheckTransaction_ERC721_Burn() public {
        // Build up the `burn(uint256)` calldata
        bytes memory burnCalldata = abi.encodeWithSelector(e721_burn_selector, 0);

        // Check the transaction
        _checkTransaction(address(this), address(erc721s[0]), burnCalldata);
    }

    function test_Success_CheckTransaction_ERC1155_SafeTransferFrom() public {
        // Build up the `safeTransferFrom(address,address,uint256,uint256,bytes)` calldata
        bytes memory safeTransferFromCalldata = abi.encodeWithSelector(
            e1155_safe_transfer_from_selector,
            alice.addr,
            bob.addr,
            0,
            1,
            ""
        );

        // Check the transaction
        _checkTransaction(address(this), address(erc1155s[0]), safeTransferFromCalldata);
    }

    function test_Success_CheckTransaction_ERC1155_Burn() public {
        // Build up the `burn(address,uint256,uint256)` calldata
        bytes memory burnCalldata = abi.encodeWithSelector(
            e1155_burn_selector,
            address(this),
            2,
            1
        );

        // Check the transaction
        _checkTransaction(address(this), address(erc1155s[0]), burnCalldata);
    }

    function test_Success_CheckTransaction_Gnosis_EnableModule() public {
        // impersonate the admin policy admin
        vm.prank(deployer.addr);

        // enable this address to be added as a module by rental safes
        admin.toggleWhitelistExtension(address(mockTarget), true);

        // Build up the `enableModule(address)` calldata
        bytes memory enableModuleCalldata = abi.encodeWithSelector(
            gnosis_safe_enable_module_selector,
            address(mockTarget)
        );

        // Check the transaction
        _checkTransaction(address(this), address(mockTarget), enableModuleCalldata);
    }

    function test_Success_CheckTransaction_Gnosis_DisableModule() public {
        // impersonate the admin policy admin
        vm.prank(deployer.addr);

        // enable this address to be added as a module by rental safes
        admin.toggleWhitelistExtension(address(mockTarget), true);

        // Build up the `disableModule(address,address)` calldata
        bytes memory disableModuleCalldata = abi.encodeWithSelector(
            gnosis_safe_disable_module_selector,
            address(0x01), // sentinel
            address(mockTarget)
        );

        // Check the transaction
        _checkTransaction(address(this), address(mockTarget), disableModuleCalldata);
    }

    function test_Reverts_CheckTransaction_ERC721_TransferFrom() public {
        // Create a rentalId array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);
        rentalAssets[0] = RentalAssetUpdate(
            RentalUtils.getItemPointer(address(alice.safe), address(erc721s[0]), 0),
            1
        );

        // Mark the rental as actively rented in storage
        _markRentalsAsActive(rentalAssets);

        // Build up the `transferFrom(address from, address to, uint256 tokenId)` calldata
        bytes memory transferFromCalldata = abi.encodeWithSelector(
            e721_transfer_from_selector,
            alice.addr,
            bob.addr,
            0
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(alice.safe),
            address(erc721s[0]),
            e721_transfer_from_selector,
            transferFromCalldata
        );
    }

    function test_Reverts_CheckTransaction_ERC721_SafeTransferFrom() public {
        // Create a rentalId array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);
        rentalAssets[0] = RentalAssetUpdate(
            RentalUtils.getItemPointer(address(alice.safe), address(erc721s[0]), 0),
            1
        );

        // Mark the rental as actively rented in storage
        _markRentalsAsActive(rentalAssets);

        // Build up the `safeTransferFrom(address,address,uint256)` calldata
        bytes memory safeTransferFromCalldata = abi.encodeWithSelector(
            e721_safe_transfer_from_1_selector,
            alice.addr,
            bob.addr,
            0
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(alice.safe),
            address(erc721s[0]),
            e721_safe_transfer_from_1_selector,
            safeTransferFromCalldata
        );
    }

    function test_Reverts_CheckTransaction_ERC721_SafeTransferFrom_WithData() public {
        // Create a rentalId array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);
        rentalAssets[0] = RentalAssetUpdate(
            RentalUtils.getItemPointer(address(alice.safe), address(erc721s[0]), 0),
            1
        );

        // Mark the rental as actively rented in storage
        _markRentalsAsActive(rentalAssets);

        // Build up the `safeTransferFrom(address,address,uint256,bytes)` calldata
        bytes memory safeTransferFromWithDataCalldata = abi.encodeWithSelector(
            e721_safe_transfer_from_2_selector,
            alice.addr,
            bob.addr,
            0,
            bytes("")
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(alice.safe),
            address(erc721s[0]),
            e721_safe_transfer_from_2_selector,
            safeTransferFromWithDataCalldata
        );
    }

    function test_Reverts_CheckTransaction_ERC721_Approve() public {
        // Create a rentalId array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);
        rentalAssets[0] = RentalAssetUpdate(
            RentalUtils.getItemPointer(address(alice.safe), address(erc721s[0]), 0),
            1
        );

        // Mark the rental as actively rented in storage
        _markRentalsAsActive(rentalAssets);

        // Build up the `approve(address,uint256)` calldata
        bytes memory approveCalldata = abi.encodeWithSelector(
            e721_approve_selector,
            bob.addr,
            0
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(alice.safe),
            address(erc721s[0]),
            e721_approve_selector,
            approveCalldata
        );
    }

    function test_Reverts_CheckTransaction_ERC721_Burn() public {
        // Create a rentalId array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);
        rentalAssets[0] = RentalAssetUpdate(
            RentalUtils.getItemPointer(address(alice.safe), address(erc721s[0]), 2),
            1
        );

        // Mark the rental as actively rented in storage
        _markRentalsAsActive(rentalAssets);

        // Build up the `burn(uint256)` calldata
        bytes memory burnCalldata = abi.encodeWithSelector(e721_burn_selector, 2);

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(alice.safe),
            address(erc721s[0]),
            e721_burn_selector,
            burnCalldata
        );
    }

    function test_Reverts_CheckTransaction_ERC1155_SafeTransferFrom() public {
        // Create a rentalId array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);
        rentalAssets[0] = RentalAssetUpdate(
            RentalUtils.getItemPointer(address(alice.safe), address(erc1155s[0]), 0),
            10
        );

        // Mark the rental as actively rented in storage
        _markRentalsAsActive(rentalAssets);

        // Build up the `safeTransferFrom(address,address,uint256,uint256,bytes)` calldata
        bytes memory safeTransferFromCalldata = abi.encodeWithSelector(
            e1155_safe_transfer_from_selector,
            address(alice.safe),
            bob.addr,
            0,
            10,
            ""
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(alice.safe),
            address(erc1155s[0]),
            e1155_safe_transfer_from_selector,
            safeTransferFromCalldata
        );
    }

    function test_Reverts_CheckTransaction_ERC1155_SafeBatchTransferFrom() public {
        // Build up the `safeTransferFrom(address,address,uint256,uint256,bytes)` calldata
        bytes memory safeBatchTransferFromCalldata = abi.encodeWithSelector(
            e1155_safe_batch_transfer_from_selector,
            alice.addr,
            bob.addr,
            new uint256[](0),
            new uint256[](0),
            ""
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(alice.safe),
            address(erc1155s[0]),
            e1155_safe_batch_transfer_from_selector,
            safeBatchTransferFromCalldata
        );
    }

    function test_Reverts_CheckTransaction_ERC1155_Burn() public {
        // Create a rentalId array
        RentalAssetUpdate[] memory rentalAssets = new RentalAssetUpdate[](1);
        rentalAssets[0] = RentalAssetUpdate(
            RentalUtils.getItemPointer(address(alice.safe), address(erc1155s[0]), 2),
            10
        );

        // Mark the rental as actively rented in storage
        _markRentalsAsActive(rentalAssets);

        // Build up the `burn(address,uint256,uint256)` calldata
        bytes memory burnCalldata = abi.encodeWithSelector(
            e1155_burn_selector,
            address(this),
            2,
            10
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(alice.safe),
            address(erc1155s[0]),
            e1155_burn_selector,
            burnCalldata
        );
    }

    function test_Reverts_CheckTransaction_ERC1155_BurnBatch() public {
        // Build up the `burnBatch(address,uint256[],uint256[])` calldata
        bytes memory burnBatchCalldata = abi.encodeWithSelector(
            e1155_burn_batch_selector,
            address(this),
            new uint256[](0),
            new uint256[](0)
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(alice.safe),
            address(erc1155s[0]),
            e1155_burn_batch_selector,
            burnBatchCalldata
        );
    }

    function test_Reverts_CheckTransaction_Gnosis_EnableModule() public {
        // Build up the `enableModule(address)` calldata
        bytes memory enableModuleCalldata = abi.encodeWithSelector(
            gnosis_safe_enable_module_selector,
            address(mockTarget)
        );

        // Expect revert because of an unauthorized extension
        _checkTransactionRevertUnauthorizedExtension(
            address(this),
            address(mockTarget),
            enableModuleCalldata
        );
    }

    function test_Reverts_CheckTransaction_Gnosis_DisableModule() public {
        // Build up the `disableModule(address,address)` calldata
        bytes memory disableModuleCalldata = abi.encodeWithSelector(
            gnosis_safe_disable_module_selector,
            address(0x01), // sentinel
            address(mockTarget)
        );

        // Expect revert because of an unauthorized extension
        _checkTransactionRevertUnauthorizedExtension(
            address(this),
            address(mockTarget),
            disableModuleCalldata
        );
    }

    function test_Reverts_CheckTransaction_Shared_SetApprovalForAll() public {
        // Build up the `setApprovalForAll(address,bool)` calldata
        bytes memory setApproveForAllCalldata = abi.encodeWithSelector(
            shared_set_approval_for_all_selector,
            bob.addr,
            true
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(this),
            address(mockTarget),
            shared_set_approval_for_all_selector,
            setApproveForAllCalldata
        );
    }

    function test_Reverts_CheckTransaction_Gnosis_SetGuard() public {
        // Build up the `setGuard(address)` calldata
        bytes memory setGuardCalldata = abi.encodeWithSelector(
            gnosis_safe_set_guard_selector,
            address(mockTarget)
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(this),
            address(mockTarget),
            gnosis_safe_set_guard_selector,
            setGuardCalldata
        );
    }

    function test_Reverts_CheckTransaction_Gnosis_SetFallbackHandler() public {
        // Build up the `setFallbackHandler(address)` calldata
        bytes memory setFallbackHandlerCalldata = abi.encodeWithSelector(
            gnosis_safe_set_fallback_handler_selector,
            address(mockTarget)
        );

        // Expect revert because of an unauthorized function selector
        _checkTransactionRevertUnauthorizedSelector(
            address(this),
            address(mockTarget),
            gnosis_safe_set_fallback_handler_selector,
            setFallbackHandlerCalldata
        );
    }
}
