// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

// Mock target contract for hook contracts to route execution to
contract MockTarget {
    function execute() external {}
}
