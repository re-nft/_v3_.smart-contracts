// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Vm} from "@forge-std/Vm.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {SafeL2} from "@safe-contracts/SafeL2.sol";

import {MockERC20} from "@test/mocks/tokens/standard/MockERC20.sol";
import {MockERC721} from "@test/mocks/tokens/standard/MockERC721.sol";
import {MockERC1155} from "@test/mocks/tokens/standard/MockERC1155.sol";
import {ProtocolAccount} from "@test/utils/Types.sol";
import {Protocol} from "@test/fixtures/protocol/Protocol.sol";

// Creates test accounts to interact with the V3 protocol
contract AccountCreator is Protocol {
    // Protocol accounts for testing
    ProtocolAccount public alice;
    ProtocolAccount public bob;
    ProtocolAccount public carol;
    ProtocolAccount public dan;
    ProtocolAccount public eve;

    // Mock tokens for testing
    MockERC20[] public erc20s;
    MockERC721[] public erc721s;
    MockERC1155[] public erc1155s;

    function setUp() public virtual override {
        super.setUp();

        // deploy 3 erc20 tokens, 3 erc721 tokens, and 3 erc1155 tokens
        _deployTokens(3);

        // instantiate all wallets and deploy rental safes for each
        alice = _fundWalletAndDeployRentalSafe("alice");
        bob = _fundWalletAndDeployRentalSafe("bob");
        carol = _fundWalletAndDeployRentalSafe("carol");
        dan = _fundWalletAndDeployRentalSafe("dan");
        eve = _fundWalletAndDeployRentalSafe("eve");
    }

    function _deployTokens(uint256 numTokens) internal {
        for (uint256 i; i < numTokens; i++) {
            _deployErc20Token();
            _deployErc721Token();
            _deployErc1155Token();
        }
    }

    function _deployErc20Token() internal returns (uint256 i) {
        // save the token's index
        i = erc20s.length;

        // deploy the mock token
        MockERC20 token = new MockERC20();

        // push the token to the array of mocks
        erc20s.push(token);

        // set the token label with the index
        vm.label(address(token), string.concat("MERC20_", LibString.toString(i)));
    }

    function _deployErc721Token() internal returns (uint256 i) {
        // save the token's index
        i = erc721s.length;

        // deploy the mock token
        MockERC721 token = new MockERC721();

        // push the token to the array of mocks
        erc721s.push(token);

        // set the token label with the index
        vm.label(address(token), string.concat("MERC721_", LibString.toString(i)));
    }

    function _deployErc1155Token() internal returns (uint256 i) {
        // save the token's index
        i = erc1155s.length;

        // deploy the mock token
        MockERC1155 token = new MockERC1155();

        // push the token to the array of mocks
        erc1155s.push(token);

        // set the token label with the index
        vm.label(address(token), string.concat("MERC1155_", LibString.toString(i)));
    }

    function _deployRentalSafe(
        address owner,
        string memory name
    ) internal returns (address safe) {
        // Deploy a 1/1 rental safe
        address[] memory owners = new address[](1);
        owners[0] = owner;
        safe = factory.deployRentalSafe(owners, 1);

        // label the contract
        vm.label(address(safe), string.concat("RentalSafe_", name));
    }

    function _fundWalletAndDeployRentalSafe(
        string memory name
    ) internal returns (ProtocolAccount memory account) {
        // create a wallet with a address, public key, and private key
        Vm.Wallet memory wallet = vm.createWallet(name);

        // deploy a rental safe for the address
        address rentalSafe = _deployRentalSafe(wallet.addr, name);

        // fund the wallet with ether, all erc20s, and approve the conduit for erc20s, erc721s, erc1155s
        _allocateTokensAndApprovals(wallet.addr, 10000);

        // create an account
        account = ProtocolAccount({
            addr: wallet.addr,
            safe: SafeL2(payable(rentalSafe)),
            publicKeyX: wallet.publicKeyX,
            publicKeyY: wallet.publicKeyY,
            privateKey: wallet.privateKey
        });
    }

    function _allocateTokensAndApprovals(address to, uint128 amount) internal {
        // deal ether to the recipient
        vm.deal(to, amount);

        // mint all erc20 tokens to the recipient
        for (uint256 i = 0; i < erc20s.length; ++i) {
            erc20s[i].mint(to, amount);
        }

        // set token approvals
        _setApprovals(to);
    }

    function _setApprovals(address owner) internal {
        // impersonate the owner address
        vm.startPrank(owner);

        // set all approvals for erc20 tokens
        for (uint256 i = 0; i < erc20s.length; ++i) {
            erc20s[i].approve(address(conduit), type(uint256).max);
        }

        // set all approvals for erc721 tokens
        for (uint256 i = 0; i < erc721s.length; ++i) {
            erc721s[i].setApprovalForAll(address(conduit), true);
        }

        // set all approvals for erc1155 tokens
        for (uint256 i = 0; i < erc1155s.length; ++i) {
            erc1155s[i].setApprovalForAll(address(conduit), true);
        }

        // stop impersonating
        vm.stopPrank();
    }
}
