// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";

import {External_Create2Deployer} from "@test/fixtures/external/Create2Deployer.sol";
import {MockERC721} from "@test/mocks/tokens/standard/MockERC721.sol";

contract Create2Deployer_Unit_Test is External_Create2Deployer {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_SetUp() public {
        // assert that create2 deployer was deployed properly
        assertTrue(address(create2Deployer) != address(0));
    }

    function test_Deploy(bytes12 data) public {
        // generate salt that begins with msg.sender
        bytes32 salt = create2Deployer.generateSaltWithSender(address(this), data);

        // abi encode the contract bytecode and constructor arguments
        bytes memory mock721InitCode = abi.encodePacked(type(MockERC721).creationCode);
        // takes no constructor args

        // expected deployment address
        address expectedmock721Address = create2Deployer.getCreate2Address(
            salt,
            mock721InitCode
        );

        // Deploy the contract
        address mock721Address = create2Deployer.deploy(salt, mock721InitCode);

        // assert deployment was successful
        assertEq(expectedmock721Address, mock721Address);
        assertEq(create2Deployer.deployed(mock721Address), true);
    }

    function test_DeployWithValue(bytes12 data) public {
        // generate salt that begins with msg.sender
        bytes32 salt = create2Deployer.generateSaltWithSender(address(this), data);

        // abi encode the contract bytecode and constructor arguments
        bytes memory mock721InitCode = abi.encodePacked(type(MockERC721).creationCode);
        // takes no constructor args

        // expected deployment address
        address expectedmock721Address = create2Deployer.getCreate2Address(
            salt,
            mock721InitCode
        );

        // Deploy the contract and send 1 ether to the contract
        address mock721Address = create2Deployer.deploy{value: 1 ether}(
            salt,
            mock721InitCode
        );

        // assert payable deployment was successful
        assertEq(expectedmock721Address, mock721Address);
        assertEq(create2Deployer.deployed(mock721Address), true);
        assertEq(mock721Address.balance, 1 ether);
    }

    function test_DeployMultipleContracts(bytes12 dataOne, bytes12 dataTwo) public {
        // assume the data isnt equal
        vm.assume(dataOne != dataTwo);

        // generate first salt that begins with msg.sender
        bytes32 saltOne = create2Deployer.generateSaltWithSender(address(this), dataOne);

        // generate second salt that begins with msg.sender
        bytes32 saltTwo = create2Deployer.generateSaltWithSender(address(this), dataTwo);

        // abi encode the contract bytecode and constructor arguments
        bytes memory mock721InitCode = abi.encodePacked(type(MockERC721).creationCode);
        // takes no constructor args

        // Deploy the contracts
        address mock721AddressOne = create2Deployer.deploy(saltOne, mock721InitCode);
        address mock721AddressTwo = create2Deployer.deploy(saltTwo, mock721InitCode);

        // assert the deployed addresses are different
        assertTrue(mock721AddressOne != mock721AddressTwo);
    }

    function test_ContractAlreadyDeployed(bytes12 data) public {
        // generate salt that begins with msg.sender
        bytes32 salt = create2Deployer.generateSaltWithSender(address(this), data);

        // abi encode the contract bytecode and constructor arguments
        bytes memory mock721InitCode = abi.encodePacked(type(MockERC721).creationCode);
        // takes no constructor args

        // expected deployment address
        address expectedmock721Address = create2Deployer.getCreate2Address(
            salt,
            mock721InitCode
        );

        // Deploy the contract
        address mock721Address = create2Deployer.deploy(salt, mock721InitCode);

        // assert deployment was successful
        assertEq(expectedmock721Address, mock721Address);
        assertEq(create2Deployer.deployed(mock721Address), true);

        // try to deploy again with the same salt
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Create2Deployer_AlreadyDeployed.selector,
                expectedmock721Address,
                salt
            )
        );
        create2Deployer.deploy(salt, mock721InitCode);
    }

    function test_SaltDoesNotMatchSender(bytes12 data) public {
        // create a frontrunner account
        address frontrunner = vm.addr(uint256(keccak256("junk")));

        // generate salt that doesnt begin with msg.sender
        bytes32 salt = create2Deployer.generateSaltWithSender(address(this), data);

        // abi encode the contract bytecode and constructor arguments
        bytes memory mock721InitCode = abi.encodePacked(type(MockERC721).creationCode);
        // takes no constructor args

        // Expect the deployment to revert because sender is unauthorized
        vm.prank(frontrunner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.Create2Deployer_UnauthorizedSender.selector,
                frontrunner,
                salt
            )
        );
        create2Deployer.deploy(salt, mock721InitCode);
    }
}
