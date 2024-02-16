// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Kernel} from "@src/Kernel.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";
import {SettleTo} from "@src/libraries/RentalStructs.sol";
import {Transferer} from "@src/libraries/Transferer.sol";

contract PaymentEscrowHarness is PaymentEscrow {
    using Transferer for address;

    constructor(Kernel kernel_) PaymentEscrow(kernel_) {}

    function transferERC20(address token, address to, uint256 value) external {
        token.transferERC20(to, value);
    }

    function calculatePaymentProRata(
        uint256 amount,
        uint256 elapsedTime,
        uint256 totalTime
    ) external pure returns (uint256 renterAmount, uint256 lenderAmount) {
        (renterAmount, lenderAmount) = _calculatePaymentProRata(
            amount,
            elapsedTime,
            totalTime
        );
    }

    function settlePaymentProRata(
        address token,
        uint256 amount,
        address lender,
        address renter,
        uint256 elapsedTime,
        uint256 totalTime
    ) external {
        _settlePaymentProRata(token, amount, lender, renter, elapsedTime, totalTime);
    }

    function settlePaymentInFull(
        address token,
        uint256 amount,
        SettleTo settleTo,
        address lender,
        address renter
    ) external {
        _settlePaymentInFull(token, amount, settleTo, lender, renter);
    }

    function increaseDeposit_internal(address token, uint256 amount) external {
        _increaseDeposit(token, amount);
    }

    function decreaseDeposit_internal(address token, uint256 amount) external {
        _decreaseDeposit(token, amount);
    }
}
