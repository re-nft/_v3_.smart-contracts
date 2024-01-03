// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IHook} from "@src/interfaces/IHook.sol";

/////////////////////////////////////////////////////////////////////////////////
//                            Template Mock Hook                               //
/////////////////////////////////////////////////////////////////////////////////

// Error library for the mocks
library MockHookErrors {
    error CheckTransactionRevert();
    error OnStartRevert();
    error OnStopRevert();
}

// Mock hook template
contract MockHook_Template is IHook {
    bool public transactionChecked;
    bool public entryAdded;
    bool public entryRemoved;

    function onTransaction(
        address recipient,
        address to,
        uint256 value,
        bytes memory data
    ) external virtual override {}

    function onStart(
        address recipient,
        address token,
        uint256 identifier,
        uint256 amount,
        bytes memory extraData
    ) external virtual override {}

    function onStop(
        address recipient,
        address token,
        uint256 identifier,
        uint256 amount,
        bytes memory extraData
    ) external virtual override {}
}

/////////////////////////////////////////////////////////////////////////////////
//                             Successful Mocks                                //
/////////////////////////////////////////////////////////////////////////////////

// Mock hook contract where the calls always succeed
contract MockHook_Success is MockHook_Template {
    function onTransaction(address, address, uint256, bytes memory) external override {
        transactionChecked = true;
    }

    function onStart(address, address, uint256, uint256, bytes memory) external override {
        entryAdded = true;
    }

    function onStop(address, address, uint256, uint256, bytes memory) external override {
        entryRemoved = true;
    }
}

/////////////////////////////////////////////////////////////////////////////////
//                      `CheckTransaction` Error Mocks                         //
/////////////////////////////////////////////////////////////////////////////////

// Mock hook contract that always reverts on `checkTransaction`
contract MockHook_CheckTransactionRevert is MockHook_Template {
    function onTransaction(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override {
        revert MockHookErrors.CheckTransactionRevert();
    }
}

// Mock hook contract with a failed `require` in `checkTransaction`
contract MockHook_CheckTransactionRequire is MockHook_Template {
    function onTransaction(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override {
        require(false, "CheckTransactionRequire");
    }
}

// Mock hook contract which causes a solidity panic code in `checkTransaction`
contract MockHook_CheckTransactionPanic is MockHook_Template {
    function onTransaction(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override {
        // causes underflow with panic code 0x11 (or, 17 in decimal)
        uint256 zero;
        zero - 1;
    }
}

/////////////////////////////////////////////////////////////////////////////////
//                          `OnStart` Error Mocks                             //
/////////////////////////////////////////////////////////////////////////////////

// Mock hook contract that always reverts on `onStart`
contract MockHook_OnStartRevert is MockHook_Template {
    function onStart(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external pure override {
        revert MockHookErrors.OnStartRevert();
    }
}

// Mock hook contract with a failed `require` in `onStart`
contract MockHook_OnStartRequire is MockHook_Template {
    function onStart(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external pure override {
        require(false, "OnStartRequire");
    }
}

// Mock hook contract which causes a solidity panic code in `onStart`
contract MockHook_OnStartPanic is MockHook_Template {
    function onStart(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external pure override {
        // causes underflow with panic code 0x11 (or, 17 in decimal)
        uint256 zero;
        zero - 1;
    }
}

/////////////////////////////////////////////////////////////////////////////////
//                        `OnStop` Error Mocks                            //
/////////////////////////////////////////////////////////////////////////////////

// Mock hook contract that always reverts on `onStop`
contract MockHook_OnStopRevert is MockHook_Template {
    function onStop(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external pure override {
        revert MockHookErrors.OnStopRevert();
    }
}

// Mock hook contract with a failed `require` in `onStop`
contract MockHook_OnStopRequire is MockHook_Template {
    function onStop(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external pure override {
        require(false, "OnStopRequire");
    }
}

// Mock hook contract which causes a solidity panic code in `onStop`
contract MockHook_OnStopPanic is MockHook_Template {
    function onStop(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external pure override {
        // causes underflow with panic code 0x11 (or, 17 in decimal)
        uint256 zero;
        zero - 1;
    }
}
