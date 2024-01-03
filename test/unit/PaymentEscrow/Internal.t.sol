// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {SettleTo} from "@src/libraries/RentalStructs.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";
import {PaymentEscrowHarness} from "@test/mocks/harnesses/PaymentEscrowHarness.sol";
import {
    MockWithoutReturnsERC20
} from "@test/mocks/tokens/weird/MockWithoutReturnsERC20.sol";
import {MockAlwaysRevertERC20} from "@test/mocks/tokens/weird/MockAlwaysRevertERC20.sol";
import {MockNeverRevertERC20} from "@test/mocks/tokens/weird/MockNeverRevertERC20.sol";

contract PaymentEscrow_Internal_Unit_Test is BaseTestWithoutEngine {
    // Payment Escrow Harness contract
    PaymentEscrowHarness public ESCRW_Harness;

    // mock ERC20 tokens with a twist to them
    MockWithoutReturnsERC20 public withoutReturnsERC20;
    MockAlwaysRevertERC20 public alwaysRevertERC20;
    MockNeverRevertERC20 public neverRevertERC20;

    // A helper struct for defining pro-rata tests
    struct PaymentProRataHelper {
        uint256 amount;
        uint256 elapsedTime;
        uint256 totalTime;
        uint256 expectedRenterAmount;
        uint256 expectedLenderAmount;
    }

    function setUp() public override {
        super.setUp();

        // set up a payment escrow contract that exposes the internal functions
        ESCRW_Harness = new PaymentEscrowHarness(kernel);

        // set up an ERC20 token that doesnt return booleans
        withoutReturnsERC20 = new MockWithoutReturnsERC20();

        // set up an ERC20 token that always reverts
        alwaysRevertERC20 = new MockAlwaysRevertERC20();

        // set up an ERC20 token that never reverts
        neverRevertERC20 = new MockNeverRevertERC20();
    }

    function test_Success_SafeTransfer_StandardERC20() public {
        // impersonate an account with funds
        vm.prank(alice.addr);

        // send funds to the escrow
        erc20s[0].transfer(address(ESCRW_Harness), 10);

        // assert funds are in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW_Harness)), 10);
        assertEq(erc20s[0].balanceOf(alice.addr), 9990);

        // transfer the funds back
        ESCRW_Harness.safeTransfer(address(erc20s[0]), alice.addr, 10);

        // assert funds have been received
        assertEq(erc20s[0].balanceOf(address(ESCRW_Harness)), 0);
        assertEq(erc20s[0].balanceOf(alice.addr), 10000);
    }

    function test_Success_SafeTransfer_withoutReturnsERC20() public {
        // mint some tokens to the escrow
        withoutReturnsERC20.mint(address(ESCRW_Harness), 10);

        // assert funds are in the escrow
        assertEq(withoutReturnsERC20.balanceOf(address(ESCRW_Harness)), 10);

        // transfer the funds back
        ESCRW_Harness.safeTransfer(address(withoutReturnsERC20), alice.addr, 10);

        // assert funds have been received
        assertEq(withoutReturnsERC20.balanceOf(address(ESCRW_Harness)), 0);
        assertEq(withoutReturnsERC20.balanceOf(alice.addr), 10);
    }

    function test_Reverts_SafeTransfer_AlwaysRevertsERC20() public {
        // mint some tokens to the escrow
        alwaysRevertERC20.mint(address(ESCRW_Harness), 10);

        // assert funds are in the escrow
        assertEq(alwaysRevertERC20.balanceOf(address(ESCRW_Harness)), 10);

        // Expect revert because the ERC20 token reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.PaymentEscrowModule_PaymentTransferFailed.selector,
                address(alwaysRevertERC20),
                alice.addr,
                10
            )
        );
        ESCRW_Harness.safeTransfer(address(alwaysRevertERC20), alice.addr, 10);
    }

    function test_Reverts_SafeTransfer_NeverRevertsERC20() public {
        // mint some tokens to the escrow
        neverRevertERC20.mint(address(ESCRW_Harness), 10);

        // assert funds are in the escrow
        assertEq(neverRevertERC20.balanceOf(address(ESCRW_Harness)), 10);

        // Expect revert because the ERC20 token reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.PaymentEscrowModule_PaymentTransferFailed.selector,
                address(neverRevertERC20),
                alice.addr,
                10
            )
        );
        ESCRW_Harness.safeTransfer(address(neverRevertERC20), alice.addr, 10);
    }

    function test_Success_CalculatePaymentProRata() public {
        // set configurations for the test
        PaymentProRataHelper[] memory configurations = new PaymentProRataHelper[](6);
        configurations[0] = PaymentProRataHelper(3, 2, 3, 2, 1);
        configurations[1] = PaymentProRataHelper(3, 1, 3, 1, 2);
        configurations[2] = PaymentProRataHelper(2, 1, 3, 1, 1);
        configurations[3] = PaymentProRataHelper(2, 2, 3, 1, 1);
        configurations[4] = PaymentProRataHelper(2, 0, 3, 0, 2);
        configurations[5] = PaymentProRataHelper(10, 10, 12, 8, 2);

        for (uint256 i = 0; i < configurations.length; i++) {
            // calculate the payments
            (uint256 renterAmount, uint256 lenderAmount) = ESCRW_Harness
                .calculatePaymentProRata(
                    configurations[i].amount,
                    configurations[i].elapsedTime,
                    configurations[i].totalTime
                );

            // assert the renter amount is correct
            assertEq(configurations[i].expectedRenterAmount, renterAmount);

            // assert the lender amount is correct
            assertEq(configurations[i].expectedLenderAmount, lenderAmount);
        }
    }

    /// forge-config: default.fuzz.runs = 1000
    function test_Fuzz_SettlePaymentProRata(
        uint256 amount,
        uint256 elapsedTime,
        uint256 totalTime
    ) public {
        // assume the amount 10000 tokens or less, and greater than 0
        vm.assume(amount > 0);
        vm.assume(amount <= 10000);

        // place a time limit of about 10 years
        vm.assume(totalTime < 3e8);
        vm.assume(elapsedTime < 3e8);

        // elapsed time has to be strictly less than total time
        vm.assume(elapsedTime < totalTime);

        // the contracts enforce the rent duration must be greater than 0
        vm.assume(totalTime > 0);

        // create mock lender and renter addresses
        address lender = address(uint160(uint256(keccak256(abi.encode("lender")))));
        address renter = address(uint160(uint256(keccak256(abi.encode("renter")))));

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW_Harness), amount);

        // assert funds are in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW_Harness)), amount);

        // increase the balance
        ESCRW_Harness.increaseDeposit_internal(address(erc20s[0]), amount);

        // set the payment pro-rata
        ESCRW_Harness.settlePaymentProRata(
            address(erc20s[0]),
            amount,
            lender,
            renter,
            elapsedTime,
            totalTime
        );

        // fetch balances after payment settlement
        uint256 lenderBalance = erc20s[0].balanceOf(lender);
        uint256 renterBalance = erc20s[0].balanceOf(renter);

        // calculate remaining time
        uint256 remainingTime = totalTime - elapsedTime;

        // assert that no dust was left over
        assertEq(lenderBalance + renterBalance, amount);

        // If more time has elapsed than not, we can guarantee that the renter's payout
        // will be at least as large as the lender's.
        if (elapsedTime >= remainingTime) assertGe(renterBalance, lenderBalance);

        // If less time has elapsed than not, we can guarantee that the lender's payout
        // will be at least as large as the renter's.
        if (elapsedTime < remainingTime) assertGe(lenderBalance, renterBalance);
    }

    /// forge-config: default.fuzz.runs = 1000
    function test_Fuzz_SettlePaymentInFull(uint256 amount, bool settleToBool) public {
        // assume the amount 10000 tokens or less, and greater than 0
        vm.assume(amount > 0);
        vm.assume(amount <= 10000);

        // create mock lender and renter addresses
        address lender = address(uint160(uint256(keccak256(abi.encode("lender")))));
        address renter = address(uint160(uint256(keccak256(abi.encode("renter")))));

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW_Harness), amount);

        // assert funds are in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW_Harness)), amount);

        // increase the balance
        ESCRW_Harness.increaseDeposit_internal(address(erc20s[0]), amount);

        // use fuzzing to choose a binary SettleTo option
        SettleTo settleTo = settleToBool ? SettleTo.LENDER : SettleTo.RENTER;

        // set the payment in full
        ESCRW_Harness.settlePaymentInFull(
            address(erc20s[0]),
            amount,
            settleTo,
            lender,
            renter
        );

        // fetch balances after payment settlement
        uint256 lenderBalance = erc20s[0].balanceOf(lender);
        uint256 renterBalance = erc20s[0].balanceOf(renter);

        // assert lender was paid if it settled to them
        if (settleTo == SettleTo.LENDER) {
            assertEq(lenderBalance, amount);
            assertEq(renterBalance, 0);
        }

        // assert renter was paid if it settled to them
        if (settleTo == SettleTo.RENTER) {
            assertEq(lenderBalance, 0);
            assertEq(renterBalance, amount);
        }
    }

    /// forge-config: default.fuzz.runs = 1000
    function test_Fuzz_IncreaseDeposit(uint256 amount) public {
        // assume the amount is less than 10000 tokens and greater than 0
        vm.assume(amount > 0);
        vm.assume(amount <= 10000);

        // set up variables
        address token = address(erc20s[0]);

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW_Harness), amount);

        // assert funds are in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW_Harness)), amount);

        // assert that the balance has not been synced
        assertEq(ESCRW_Harness.balanceOf(token), 0);

        // increase the balance
        ESCRW_Harness.increaseDeposit_internal(token, amount);

        // assert that the balance was correctly synced
        assertEq(ESCRW_Harness.balanceOf(token), amount);
    }

    /// forge-config: default.fuzz.runs = 1000
    function test_Fuzz_IncreaseDeposit_ExtraFundsInEscrow(uint256 amount) public {
        // assume the amount is less than 10000 tokens and greater than 0
        vm.assume(amount > 0);
        vm.assume(amount < 10000);

        // set up variables
        address token = address(erc20s[0]);
        uint256 extraAmount = amount + 1;

        // mint extra funds to the escrow
        erc20s[0].mint(address(ESCRW_Harness), extraAmount);

        // assert extra funds are in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW_Harness)), extraAmount);

        // assert that the balance has not been synced
        assertEq(ESCRW_Harness.balanceOf(token), 0);

        // increase the balance
        ESCRW_Harness.increaseDeposit_internal(token, amount);

        // assert that the balance was correctly synced
        assertEq(ESCRW_Harness.balanceOf(token), amount);
    }

    function test_Fuzz_DecreaseDeposit(uint256 amount) public {
        // assume the amount is less than 10000 tokens and greater than 0
        vm.assume(amount > 0);
        vm.assume(amount <= 10000);

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW_Harness), amount);

        // set up variables
        address token = address(erc20s[0]);

        // increase the balance
        ESCRW_Harness.increaseDeposit_internal(token, amount);

        // assert that the balance was correctly synced
        assertEq(ESCRW_Harness.balanceOf(token), amount);

        // send funds out the payment escrow
        ESCRW_Harness.safeTransfer(token, alice.addr, amount);

        // assert funds are not in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW_Harness)), 0);

        // assert that the balance has not been synced
        assertEq(ESCRW_Harness.balanceOf(token), amount);

        // sync the balance
        ESCRW_Harness.decreaseDeposit_internal(token, amount);

        // assert that the balance was correctly synced
        assertEq(ESCRW_Harness.balanceOf(token), 0);
    }

    function test_Fuzz_DecreaseDeposit_ExtraFundsInEscrow(uint256 amount) public {
        // assume the amount is less than 10000 tokens and greater than 0
        vm.assume(amount > 0);
        vm.assume(amount <= 10000);

        // set up variables
        address token = address(erc20s[0]);
        uint256 extraFunds = amount + 1;

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW_Harness), extraFunds);

        // increase the balance
        ESCRW_Harness.increaseDeposit_internal(token, amount);

        // assert that the balance was correctly synced
        assertEq(ESCRW_Harness.balanceOf(token), amount);

        // send funds out the payment escrow
        ESCRW_Harness.safeTransfer(token, alice.addr, amount);

        // assert almost all the funds are not in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW_Harness)), 1);

        // assert that the balance has not been synced
        assertEq(ESCRW_Harness.balanceOf(token), amount);

        // decrease the balance
        ESCRW_Harness.decreaseDeposit_internal(token, amount);

        // assert that the balance was correctly synced
        assertEq(ESCRW_Harness.balanceOf(token), 0);
    }
}
