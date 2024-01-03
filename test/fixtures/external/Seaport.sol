// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {Vm} from "@forge-std/Vm.sol";

import {Seaport} from "@seaport-core/Seaport.sol";
import {ConduitController} from "@seaport-core/conduit/ConduitController.sol";
import {
    ConduitControllerInterface
} from "@seaport-types/interfaces/ConduitControllerInterface.sol";
import {ConduitInterface} from "@seaport-types/interfaces/ConduitInterface.sol";

// Deploys all Seaport protocol contracts
contract External_Seaport is Test {
    // seaport protocol contracts
    Seaport public seaport;
    ConduitController public conduitController;
    ConduitInterface public conduit;

    // conduit owner and key
    Vm.Wallet public conduitOwner;
    bytes32 public conduitKey;

    function setUp() public virtual {
        // generate conduit owner wallet
        conduitOwner = vm.createWallet("conduitOwner");

        // deploy conduit controller
        conduitController = new ConduitController();

        // deploy seaport
        seaport = new Seaport(address(conduitController));

        // create a conduit key (first 20 bytes must be conduit creator)
        conduitKey = bytes32(uint256(uint160(conduitOwner.addr))) << 96;

        // create a new conduit
        vm.prank(conduitOwner.addr);
        address conduitAddress = conduitController.createConduit(
            conduitKey,
            conduitOwner.addr
        );

        // set the conduit address
        conduit = ConduitInterface(conduitAddress);

        // open a channel for seaport on the conduit
        vm.prank(conduitOwner.addr);
        conduitController.updateChannel(address(conduit), address(seaport), true);

        // label the contracts
        vm.label(address(seaport), "Seaport");
        vm.label(address(conduitController), "ConduitController");
        vm.label(address(conduit), "Conduit");
    }
}
