// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/////////////////////////////////////////////////////////////////////////////////
//                           Shared Function Selectors                         //
/////////////////////////////////////////////////////////////////////////////////

// bytes4(keccak256("setApprovalForAll(address,bool)"))
bytes4 constant shared_set_approval_for_all_selector = 0xa22cb465;

/////////////////////////////////////////////////////////////////////////////////
//                    ERC-721 Function Selectors And Offsets                   //
/////////////////////////////////////////////////////////////////////////////////

// bytes4(keccak256("approve(address,uint256)"))
bytes4 constant e721_approve_selector = 0x095ea7b3;

// bytes4(keccak256("safeTransferFrom(address,address,uint256)"))
bytes4 constant e721_safe_transfer_from_1_selector = 0x42842e0e;

// bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))
bytes4 constant e721_safe_transfer_from_2_selector = 0xb88d4fde;

// bytes4(keccak256("transferFrom(address,address,uint256)"))
bytes4 constant e721_transfer_from_selector = 0x23b872dd;

// bytes4(keccak256("burn(uint256)"))
bytes4 constant e721_burn_selector = 0x42966c68;

// Token ID offsets for ERC-721
uint256 constant e721_approve_token_id_offset = 0x44;
uint256 constant e721_safe_transfer_from_1_token_id_offset = 0x64;
uint256 constant e721_safe_transfer_from_2_token_id_offset = 0x64;
uint256 constant e721_transfer_from_token_id_offset = 0x64;
uint256 constant e721_burn_offset = 0x24;

/////////////////////////////////////////////////////////////////////////////////
//                    ERC-1155 Function Selectors And Offsets                  //
/////////////////////////////////////////////////////////////////////////////////

// bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)"))
bytes4 constant e1155_safe_transfer_from_selector = 0xf242432a;

// bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)"))
bytes4 constant e1155_safe_batch_transfer_from_selector = 0x2eb2c2d6;

// bytes4(keccak256("burn(address,uint256,uint256)"))
bytes4 constant e1155_burn_selector = 0xf5298aca;

// bytes4(keccak256("burnBatch(address,uint256[],uint256[])"))
bytes4 constant e1155_burn_batch_selector = 0x6b20c454;

// Token ID offsets for ERC-1155
uint256 constant e1155_safe_transfer_from_token_id_offset = 0x64;
uint256 constant e1155_safe_transfer_from_amount_offset = 0x84;
uint256 constant e1155_burn_offset = 0x44;
uint256 constant e1155_burn_amount_offset = 0x64;

/////////////////////////////////////////////////////////////////////////////////
//                  Gnosis Safe Function Selectors And Offsets                 //
/////////////////////////////////////////////////////////////////////////////////

// bytes4(keccak256("setGuard(address)"))
bytes4 constant gnosis_safe_set_guard_selector = 0xe19a9dd9;

// bytes4(keccak256("enableModule(address)"))
bytes4 constant gnosis_safe_enable_module_selector = 0x610b5925;

// bytes4(keccak256("disableModule(address,address)"))
bytes4 constant gnosis_safe_disable_module_selector = 0xe009cfde;

// bytes4(keccak256("setFallbackHandler(address)"))
bytes4 constant gnosis_safe_set_fallback_handler_selector = 0xf08a0323;

// Module offsets for gnosis safe
uint256 constant gnosis_safe_enable_module_offset = 0x24;
uint256 constant gnosis_safe_disable_module_offset = 0x44;
