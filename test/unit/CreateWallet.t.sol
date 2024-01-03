// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

contract TestCreateWallet {

}

// import {BaseProtocol} from "@test/fixtures/protocol/BaseProtocol.sol";

// contract TestCreateWallet is BaseRentalSafe {
//     uint256 immutable ETHEREUM_CHAIN_ID = 1;
//     uint256 immutable POLYGON_CHAIN_ID = 137;
//     uint256 immutable AVALANCHE_CHAIN_ID = 43114;

//     function setUp() public override {
//         super.setUp();
//     }

//     function testCreatesUniqueWalletsAcrossChains() public {
//         // define an owner address for the safe
//         address[] memory owners = new address[](1);
//         owners[0] = address(this);

//         // we will reset the Storage's internal nonce to zero after each deploy
//         // to deploy same nonce wallets across chains
//         bytes32 ZERO_NONCE = bytes32(uint256(0));
//         // nonce is in the 4th slot in the storage contract
//         // `forge inspect Storage storage-layout --pretty`
//         bytes32 NONCE_SLOT = bytes32(uint256(4));

//         // Deploy a rental safe on Ethereum
//         vm.chainId(ETHEREUM_CHAIN_ID);
//         address safeAddressEthereum = factory.deployRentalSafe(owners, 1);
//         // reset the nonce to zero
//         vm.store(address(STORE), NONCE_SLOT, ZERO_NONCE);
//         // sanity check to ensure we have set the nonce slot to zero correctly
//         assertEq(0, STORE.totalSafes());

//         // Deploy a rental safe on Polygon
//         vm.chainId(POLYGON_CHAIN_ID);
//         address safeAddressPolygon = factory.deployRentalSafe(owners, 1);
//         // reset the nonce to zero
//         vm.store(address(STORE), NONCE_SLOT, ZERO_NONCE);
//         // sanity check to ensure we have set the nonce slot to zero correctly
//         assertEq(0, STORE.totalSafes());

//         // Deploy a rental safe on Avalanche
//         vm.chainId(AVALANCHE_CHAIN_ID);
//         address safeAddressAvalanche = factory.deployRentalSafe(owners, 1);
//         // reset the nonce to zero
//         vm.store(address(STORE), NONCE_SLOT, ZERO_NONCE);
//         // sanity check to ensure we have set the nonce slot to zero correctly
//         assertEq(0, STORE.totalSafes());

//         assert(safeAddressEthereum != safeAddressPolygon);
//         assert(safeAddressPolygon != safeAddressAvalanche);

//         assertTrue(true);
//     }
// }
