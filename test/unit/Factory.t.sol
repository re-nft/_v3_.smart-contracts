// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";

contract Factory_Unit_Test is BaseTestWithoutEngine {
    function test_DeployRentalSafe() public {
        // Define owners
        address[] memory owners = new address[](1);
        owners[0] = alice.addr;

        // Define threshold
        uint256 threshold = 1;

        // Deploy the safe with a threshold of 1
        address safe = factory.deployRentalSafe(owners, threshold);

        // Assert that the safe address is non-zero
        assertTrue(safe != ZERO_ADDRESS);
    }

    function test_Reverts_DeployRentalSafe_WithZeroThreshold() public {
        // Define owners
        address[] memory owners = new address[](1);
        owners[0] = alice.addr;

        // Define threshold
        uint256 threshold = 0;

        // Expect revert because the threshold is set to 0
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.FactoryPolicy_InvalidSafeThreshold.selector,
                threshold,
                owners.length
            )
        );
        factory.deployRentalSafe(owners, threshold);
    }

    function test_Reverts_DeployRentalSafe_WithInvalidOwners() public {
        // Define owners
        address[] memory owners = new address[](1);
        owners[0] = alice.addr;

        // Define threshold
        uint256 threshold = 2;

        // Expect revert because the threshold is higher than the owners length
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.FactoryPolicy_InvalidSafeThreshold.selector,
                threshold,
                owners.length
            )
        );
        factory.deployRentalSafe(owners, threshold);
    }
}
