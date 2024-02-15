// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import {GuardManager} from "@safe-contracts/base/GuardManager.sol";
import {ModuleManager} from "@safe-contracts/base/ModuleManager.sol";
import {FallbackManager} from "@safe-contracts/base/FallbackManager.sol";

import {
    e721_transfer_from_selector,
    e721_safe_transfer_from_1_selector,
    e721_safe_transfer_from_2_selector,
    e721_approve_selector,
    e1155_safe_transfer_from_selector,
    e1155_safe_batch_transfer_from_selector,
    shared_set_approval_for_all_selector,
    gnosis_safe_set_guard_selector,
    gnosis_safe_enable_module_selector,
    gnosis_safe_disable_module_selector,
    gnosis_safe_set_fallback_handler_selector
} from "@src/libraries/RentalConstants.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";

// Tests that the function selectors protected by the guard are the correct
// selectors that are found on the corresponding interfaces
contract Guard_GuardedSelectors_Unit_Test is BaseTestWithoutEngine {
    function test_Sucesss_ERC721_TransferFrom() public {
        assertEq(e721_transfer_from_selector, IERC721.transferFrom.selector);
    }

    // Cannot directly get the function selector because of overloading on the interface
    function test_Success_ERC721_SafeTransferFrom() public {
        assertEq(
            e721_safe_transfer_from_1_selector,
            bytes4(keccak256("safeTransferFrom(address,address,uint256)"))
        );
    }

    // Cannot directly get the function selector because of overloading on the interface
    function test_Success_ERC721_SafeTransferFrom_WithData() public {
        assertEq(
            e721_safe_transfer_from_2_selector,
            bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))
        );
    }

    function test_Sucesss_ERC721_Approve() public {
        assertEq(e721_approve_selector, IERC721.approve.selector);
    }

    function test_Success_ERC721_SetApprovalForAll() public {
        assertEq(
            shared_set_approval_for_all_selector,
            IERC721.setApprovalForAll.selector
        );
    }

    function test_Success_ERC1155_SetApprovalForAll() public {
        assertEq(
            shared_set_approval_for_all_selector,
            IERC1155.setApprovalForAll.selector
        );
    }

    function test_Success_ERC1155_SafeTransferFrom() public {
        assertEq(e1155_safe_transfer_from_selector, IERC1155.safeTransferFrom.selector);
    }

    function test_Success_ERC1155_SafeBatchTransferFrom() public {
        assertEq(
            e1155_safe_batch_transfer_from_selector,
            IERC1155.safeBatchTransferFrom.selector
        );
    }

    function test_Success_GnosisSafe_EnableModule() public {
        assertEq(gnosis_safe_enable_module_selector, ModuleManager.enableModule.selector);
    }

    function test_Success_GnosisSafe_DisableModule() public {
        assertEq(
            gnosis_safe_disable_module_selector,
            ModuleManager.disableModule.selector
        );
    }

    function test_Success_GnosisSafe_SetGuard() public {
        assertEq(gnosis_safe_set_guard_selector, GuardManager.setGuard.selector);
    }

    function test_Success_GnosisSafe_SetFallbackHandler() public {
        assertEq(
            gnosis_safe_set_fallback_handler_selector,
            FallbackManager.setFallbackHandler.selector
        );
    }
}
