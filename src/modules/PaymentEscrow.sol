// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {Kernel, Module, Keycode} from "@src/Kernel.sol";
import {Proxiable} from "@src/proxy/Proxiable.sol";
import {
    RentalOrder,
    Item,
    ItemType,
    SettleTo,
    OrderType
} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {RentalUtils} from "@src/libraries/RentalUtils.sol";
import {Transferer} from "@src/libraries/Transferer.sol";

/**
 * @title PaymentEscrowBase
 * @notice Storage exists in its own base contract to avoid storage slot mismatch during upgrades.
 */
contract PaymentEscrowBase {
    // Keeps a record of the current token balances in the escrow.
    mapping(address token => uint256 amount) public balanceOf;

    // Fee percentage taken from payments.
    uint256 public fee;
}

/**
 * @title PaymentEscrow
 * @notice Module dedicated to escrowing rental payments while rentals are active. When
 *         rentals are stopped, this module will determine payouts to all parties and a
 *         fee will be reserved to be withdrawn later by a protocol admin.
 */
contract PaymentEscrow is Proxiable, Module, PaymentEscrowBase {
    using Transferer for address;
    using RentalUtils for Item;
    using RentalUtils for OrderType;

    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Module Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Instantiate this contract as a module. When using a proxy, the kernel address
     *      should be set to address(0).
     *
     * @param kernel_ Address of the kernel contract.
     */
    constructor(Kernel kernel_) Module(kernel_) {}

    /**
     * @notice Instantiates this contract as a module via a proxy.
     *
     * @param kernel_ Address of the kernel contract.
     */
    function MODULE_PROXY_INSTANTIATION(
        Kernel kernel_
    ) external onlyByProxy onlyUninitialized {
        kernel = kernel_;
        initialized = true;
    }

    /**
     * @notice Specifies which version of a module is being implemented.
     */
    function VERSION() external pure override returns (uint8 major, uint8 minor) {
        return (1, 0);
    }

    /**
     * @notice Defines the keycode for this module.
     */
    function KEYCODE() public pure override returns (Keycode) {
        return Keycode.wrap("ESCRW");
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            Internal Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev Calculates the fee based on the fee numerator set by an admin.
     *
     * @param amount Amount for which to calculate the fee.
     */
    function _calculateFee(uint256 amount) internal view returns (uint256) {
        // Uses 10,000 as a denominator for the fee.
        return (amount * fee) / 10000;
    }

    /**
     * @dev Calculates the pro-rata split based on the amount of time that has elapsed in
     *      a rental order. If there are not enough funds to split perfectly, rounding is
     *      done to make the split as fair as possible.
     *
     * @param amount      Amount of tokens for which to calculate the split.
     * @param elapsedTime Elapsed time since the rental started.
     * @param totalTime   Total time window of the rental from start to end.
     *
     * @return renterAmount Payment amount to send to the renter.
     * @return lenderAmount Payment amoutn to send to the lender.
     */
    function _calculatePaymentProRata(
        uint256 amount,
        uint256 elapsedTime,
        uint256 totalTime
    ) internal pure returns (uint256 renterAmount, uint256 lenderAmount) {
        // Calculate the numerator and adjust by a multiple of 1000.
        uint256 numerator = (amount * elapsedTime) * 1000;

        // Calculate the result, but bump by 500 to add a rounding adjustment. Then,
        // reduce by a multiple of 1000.
        renterAmount = ((numerator / totalTime) + 500) / 1000;

        // Calculate lender amount from renter amount so no tokens are left behind.
        lenderAmount = amount - renterAmount;
    }

    /**
     * @dev Settles a payment via a pro-rata split. After payments are calculated, they
     *      are transferred to their respective recipients.
     *
     * @param token       Token address for which to settle a payment.
     * @param amount      Amount of the token to settle.
     * @param lender      Lender account.
     * @param renter      Renter accoutn.
     * @param elapsedTime Elapsed time since the rental started.
     * @param totalTime   Total time window of the rental from start to end.
     */
    function _settlePaymentProRata(
        address token,
        uint256 amount,
        address lender,
        address renter,
        uint256 elapsedTime,
        uint256 totalTime
    ) internal {
        // Calculate the pro-rata payment for renter and lender.
        (uint256 renterAmount, uint256 lenderAmount) = _calculatePaymentProRata(
            amount,
            elapsedTime,
            totalTime
        );

        // Send the lender portion of the payment.
        token.transferERC20(lender, lenderAmount);

        // Send the renter portion of the payment.
        token.transferERC20(renter, renterAmount);
    }

    /**
     * @dev Settles a payment by sending the full amount to one address.
     *
     * @param token    Token address for which to settle a payment.
     * @param amount   Amount of the token to settle.
     * @param settleTo Specifies whether to settle to the lender or the renter.
     * @param lender   Lender account.
     * @param renter   Renter account.
     */
    function _settlePaymentInFull(
        address token,
        uint256 amount,
        SettleTo settleTo,
        address lender,
        address renter
    ) internal {
        // Determine the address that this payment will settle to.
        address settleToAddress = settleTo == SettleTo.LENDER ? lender : renter;

        // Send the payment.
        token.transferERC20(settleToAddress, amount);
    }

    /**
     * @dev Settles alls payments contained in the given item. Uses a pro-rata or in full
     *      scheme depending on the order type and when the order was stopped.
     *
     * @param items     Items present in the order.
     * @param orderType Type of the order.
     * @param lender    Lender account.
     * @param renter    Renter account.
     * @param start     Timestamp that the rental began.
     * @param end       Timestamp that the rental expires at.
     */
    function _settlePayment(
        Item[] calldata items,
        OrderType orderType,
        address lender,
        address renter,
        uint256 start,
        uint256 end
    ) internal {
        // Calculate the time values.
        uint256 elapsedTime = block.timestamp - start;
        uint256 totalTime = end - start;

        // Determine whether the rental order has ended.
        bool isRentalOver = elapsedTime >= totalTime;

        // Loop through each item in the order.
        for (uint256 i = 0; i < items.length; ++i) {
            // Get the item.
            Item memory item = items[i];

            // Check that the item is a payment.
            if (item.isERC20()) {
                // Set a placeholder payment amount which can be reduced in the
                // presence of a fee.
                uint256 paymentAmount = item.amount;

                // Take a fee on the payment amount if the fee is on.
                if (fee != 0) {
                    // Calculate the new fee.
                    uint256 paymentFee = _calculateFee(paymentAmount);

                    // Adjust the payment amount by the fee.
                    paymentAmount -= paymentFee;
                }

                // Effect: Decrease the token balance. Use the payment amount pre-fee
                // so that fees can be taken.
                _decreaseDeposit(item.token, item.amount);

                // If its a PAY order but the rental hasn't ended yet.
                if (orderType.isPayOrder() && !isRentalOver) {
                    // Interaction: a PAY order which hasnt ended yet. Payout is pro-rata.
                    _settlePaymentProRata(
                        item.token,
                        paymentAmount,
                        lender,
                        renter,
                        elapsedTime,
                        totalTime
                    );
                }
                // If its a PAY order and the rental is over, or, if its a BASE order.
                else if (
                    (orderType.isPayOrder() && isRentalOver) || orderType.isBaseOrder()
                ) {
                    // Interaction: a pay order or base order which has ended. Payout is in full.
                    _settlePaymentInFull(
                        item.token,
                        paymentAmount,
                        item.settleTo,
                        lender,
                        renter
                    );
                } else {
                    revert Errors.Shared_OrderTypeNotSupported(uint8(orderType));
                }
            }
        }
    }

    /**
     * @dev Decreases the tracked token balance of a particular token on the payment
     *      escrow contract.
     *
     * @param token  Token address.
     * @param amount Amount to decrease the balance by.
     */
    function _decreaseDeposit(address token, uint256 amount) internal {
        // Directly decrease the synced balance.
        balanceOf[token] -= amount;
    }

    /**
     * @dev Increases the tracked token balance of a particular token on the payment
     *      escrow contract.
     *
     * @param token  Token address.
     * @param amount Amount to increase the balance by.
     */
    function _increaseDeposit(address token, uint256 amount) internal {
        // Directly increase the synced balance.
        balanceOf[token] += amount;
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Settles the payment for a rental order by transferring all items marked as
     *         payments to their destination accounts. During the settlement process, if
     *         active, a fee is taken on the payment.
     *
     * @param order Rental order for which to settle a payment.
     */
    function settlePayment(RentalOrder calldata order) external onlyByProxy permissioned {
        // Settle all payments for the order.
        _settlePayment(
            order.items,
            order.orderType,
            order.lender,
            order.renter,
            order.startTimestamp,
            order.endTimestamp
        );
    }

    /**
     * @notice Settles the payments for multiple orders by looping through each one.
     *
     * @param orders Rental ordesr for which to settle payments.
     */
    function settlePaymentBatch(
        RentalOrder[] calldata orders
    ) external onlyByProxy permissioned {
        // Loop through each order.
        for (uint256 i = 0; i < orders.length; ++i) {
            // Settle all payments for the order.
            _settlePayment(
                orders[i].items,
                orders[i].orderType,
                orders[i].lender,
                orders[i].renter,
                orders[i].startTimestamp,
                orders[i].endTimestamp
            );
        }
    }

    /**
     * @notice When fungible tokens are transferred to the payment escrow contract,
     *         their balances should be increased.
     *
     * @param token  Token address for the asset.
     * @param amount Amount of the token transferred to the escrow
     */
    function increaseDeposit(
        address token,
        uint256 amount
    ) external onlyByProxy permissioned {
        // Check: Cannot accept a payment of zero.
        if (amount == 0) {
            revert Errors.PaymentEscrow_ZeroPayment();
        }

        // Effect: Increase the deposit
        _increaseDeposit(token, amount);
    }

    /**
     * @notice Sets the numerator for the fee. The denominator will always be set at
     *         10,000.
     *
     * @param feeNumerator Numerator of the fee.
     */
    function setFee(uint256 feeNumerator) external onlyByProxy permissioned {
        // Cannot accept a fee numerator greater than 10000.
        if (feeNumerator > 10000) {
            revert Errors.PaymentEscrow_InvalidFeeNumerator();
        }

        // Set the fee.
        fee = feeNumerator;
    }

    /**
     * @notice Used to collect protocol fees. In addition, if funds are accidentally sent
     *         to the payment escrow contract, this function can be used to skim them off.
     *
     * @param token Address of the token to skim.
     * @param to    Address to send the collected tokens.
     */
    function skim(address token, address to) external onlyByProxy permissioned {
        // Fetch the currently synced balance of the escrow.
        uint256 syncedBalance = balanceOf[token];

        // Fetch the true token balance of the escrow.
        uint256 trueBalance = IERC20(token).balanceOf(address(this));

        // Calculate the amount to skim.
        uint256 skimmedBalance = trueBalance - syncedBalance;

        // Send the difference to the specified address.
        token.transferERC20(to, skimmedBalance);

        // Emit event with fees taken.
        emit Events.FeeTaken(token, skimmedBalance);
    }

    /**
     * @notice Upgrades the contract to a different implementation. This implementation
     *         contract must be compatible with ERC-1822 or else the upgrade will fail.
     *
     * @param newImplementation Address of the implementation contract to upgrade to.
     */
    function upgrade(address newImplementation) external onlyByProxy permissioned {
        // _upgrade is implemented in the Proxiable contract.
        _upgrade(newImplementation);
    }

    /**
     * @notice Freezes the contract which prevents upgrading the implementation contract.
     *         There is no way to unfreeze once a contract has been frozen.
     */
    function freeze() external onlyByProxy permissioned {
        // _freeze is implemented in the Proxiable contract.
        _freeze();
    }
}
