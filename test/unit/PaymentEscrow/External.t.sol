// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    Item,
    ItemType,
    SettleTo,
    RentalOrder,
    Hook,
    OrderType
} from "@src/libraries/RentalStructs.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {BaseTestWithoutEngine} from "@test/BaseTest.sol";

contract PaymentEscrow_External_Unit_Test is BaseTestWithoutEngine {
    function test_Success_SettlePayment_PayOrder_NotEnded() public {
        // determine an amount of tokens to mint
        uint256 amount = 100;

        // determine a rent duration
        uint rentDuration = 100;

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), amount);

        // impersonate an address with permissions
        vm.prank(address(create));

        // increase the deposit
        ESCRW.increaseDeposit(address(erc20s[0]), amount);

        // create rental items
        Item[] memory items = new Item[](1);
        items[0] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.RENTER,
            token: address(erc20s[0]),
            amount: amount,
            identifier: 0
        });

        // create a rental order
        RentalOrder memory rentalOrder = RentalOrder({
            seaportOrderHash: keccak256(abi.encode("someSeaportOrderHash")),
            items: items,
            hooks: new Hook[](0),
            orderType: OrderType.PAY,
            lender: alice.addr,
            renter: bob.addr,
            rentalWallet: address(bob.safe),
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + rentDuration
        });

        // warp ahead but before the rental is over
        vm.warp(block.timestamp + 60);

        // impersonate an address with permissions
        vm.prank(address(stop));

        // settle the payment
        ESCRW.settlePayment(rentalOrder);

        // assert funds are no longer the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW)), 0);

        // assert the payment was synced
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 0);

        // assert the renter address received the pro-rata payment
        assertEq(erc20s[0].balanceOf(bob.addr), 10060);

        // assert the lender address received the pro-rata payment
        assertEq(erc20s[0].balanceOf(alice.addr), 10040);
    }

    function test_Success_SettlePayment_PayOrder_Ended() public {
        // determine an amount of tokens to mint
        uint256 amount = 100;

        // determine a rent duration
        uint rentDuration = 100;

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), amount);

        // impersonate an address with permissions
        vm.prank(address(create));

        // increase the deposit
        ESCRW.increaseDeposit(address(erc20s[0]), amount);

        // create rental items
        Item[] memory items = new Item[](1);
        items[0] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.RENTER,
            token: address(erc20s[0]),
            amount: amount,
            identifier: 0
        });

        // create a rental order
        RentalOrder memory rentalOrder = RentalOrder({
            seaportOrderHash: keccak256(abi.encode("someSeaportOrderHash")),
            items: items,
            hooks: new Hook[](0),
            orderType: OrderType.PAY,
            lender: alice.addr,
            renter: bob.addr,
            rentalWallet: address(bob.safe),
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + rentDuration
        });

        // warp ahead until the rent duration is over
        vm.warp(block.timestamp + rentDuration);

        // impersonate an address with permissions
        vm.prank(address(stop));

        // settle the payment
        ESCRW.settlePayment(rentalOrder);

        // assert funds are no longer the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW)), 0);

        // assert the payment was synced
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 0);

        // assert the renter address received the pro-rata payment
        assertEq(erc20s[0].balanceOf(bob.addr), 10100);
    }

    function test_Success_SettlePayment_BaseOrder() public {
        // determine an amount of tokens to mint
        uint256 amount = 100;

        // determine a rent duration
        uint rentDuration = 100;

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), amount);

        // impersonate an address with permissions
        vm.prank(address(create));

        // increase the deposit
        ESCRW.increaseDeposit(address(erc20s[0]), amount);

        // create rental items
        Item[] memory items = new Item[](1);
        items[0] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.LENDER,
            token: address(erc20s[0]),
            amount: amount,
            identifier: 0
        });

        // create a rental order
        RentalOrder memory rentalOrder = RentalOrder({
            seaportOrderHash: keccak256(abi.encode("someSeaportOrderHash")),
            items: items,
            hooks: new Hook[](0),
            orderType: OrderType.BASE,
            lender: alice.addr,
            renter: bob.addr,
            rentalWallet: address(bob.safe),
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + rentDuration
        });

        // warp ahead until the rent duration is over
        vm.warp(block.timestamp + rentDuration);

        // impersonate an address with permissions
        vm.prank(address(stop));

        // settle the payment
        ESCRW.settlePayment(rentalOrder);

        // assert funds are no longer the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW)), 0);

        // assert the payment was synced
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 0);

        // assert the lender address received the payment in full
        assertEq(erc20s[0].balanceOf(alice.addr), 10100);
    }

    function test_Success_SettlePayment_BaseOrder_WithFee() public {
        // determine an amount of tokens to mint
        uint256 amount = 100;

        // determine a rent duration
        uint rentDuration = 100;

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), amount);

        // impersonate an address with permissions
        vm.prank(address(create));

        // increase the deposit
        ESCRW.increaseDeposit(address(erc20s[0]), amount);

        // impersonate an address with permissions
        vm.prank(address(admin));

        // set the fee to 7% of the payment
        ESCRW.setFee(700);

        // create rental items
        Item[] memory items = new Item[](1);
        items[0] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.LENDER,
            token: address(erc20s[0]),
            amount: amount,
            identifier: 0
        });

        // create a rental order
        RentalOrder memory rentalOrder = RentalOrder({
            seaportOrderHash: keccak256(abi.encode("someSeaportOrderHash")),
            items: items,
            hooks: new Hook[](0),
            orderType: OrderType.BASE,
            lender: alice.addr,
            renter: bob.addr,
            rentalWallet: address(bob.safe),
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + rentDuration
        });

        // warp ahead until the rent duration is over
        vm.warp(block.timestamp + rentDuration);

        // impersonate an address with permissions
        vm.prank(address(stop));

        // settle the payment
        ESCRW.settlePayment(rentalOrder);

        // assert only the fee is left in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW)), 7);

        // assert the payment was synced
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 0);

        // assert the lender address received the payment in full (minus the fee)
        assertEq(erc20s[0].balanceOf(alice.addr), 10093);
    }

    function test_Success_SettlePayment_BaseOrder_WithFeeTooSmall() public {
        // determine an amount of tokens to mint
        uint256 amount = 100;

        // determine a rent duration
        uint rentDuration = 100;

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), amount);

        // impersonate an address with permissions
        vm.prank(address(create));

        // increase the deposit
        ESCRW.increaseDeposit(address(erc20s[0]), amount);

        // impersonate an address with permissions
        vm.prank(address(admin));

        // set the fee to 0.25% of the payment
        ESCRW.setFee(25);

        // create rental items
        Item[] memory items = new Item[](1);
        items[0] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.LENDER,
            token: address(erc20s[0]),
            amount: amount,
            identifier: 0
        });

        // create a rental order
        RentalOrder memory rentalOrder = RentalOrder({
            seaportOrderHash: keccak256(abi.encode("someSeaportOrderHash")),
            items: items,
            hooks: new Hook[](0),
            orderType: OrderType.BASE,
            lender: alice.addr,
            renter: bob.addr,
            rentalWallet: address(bob.safe),
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + rentDuration
        });

        // warp ahead until the rent duration is over
        vm.warp(block.timestamp + rentDuration);

        // impersonate an address with permissions
        vm.prank(address(stop));

        // settle the payment
        ESCRW.settlePayment(rentalOrder);

        // assert there is nothing left in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW)), 0);

        // assert the payment was synced
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 0);

        // assert the lender address received the payment in full, since the
        // fee percentage was too small to take
        assertEq(erc20s[0].balanceOf(alice.addr), 10100);
    }

    function test_Reverts_SettlePayment_NoPermissions() public {
        // determine an amount of tokens to mint
        uint256 amount = 100;

        // determine a rent duration
        uint rentDuration = 100;

        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), amount);

        // impersonate an address with permissions
        vm.prank(address(create));

        // increase the deposit
        ESCRW.increaseDeposit(address(erc20s[0]), amount);

        // create rental items
        Item[] memory items = new Item[](1);
        items[0] = Item({
            itemType: ItemType.ERC20,
            settleTo: SettleTo.LENDER,
            token: address(erc20s[0]),
            amount: amount,
            identifier: 0
        });

        // create a rental order
        RentalOrder memory rentalOrder = RentalOrder({
            seaportOrderHash: keccak256(abi.encode("someSeaportOrderHash")),
            items: items,
            hooks: new Hook[](0),
            orderType: OrderType.BASE,
            lender: alice.addr,
            renter: bob.addr,
            rentalWallet: address(bob.safe),
            startTimestamp: block.timestamp,
            endTimestamp: block.timestamp + rentDuration
        });

        // warp ahead until the rent duration is over
        vm.warp(block.timestamp + rentDuration);

        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        ESCRW.settlePayment(rentalOrder);
    }

    function test_Success_SettlePaymentBatch() public {
        // determine an amount of tokens to mint
        uint256 amount = 100;

        // determine a rent duration
        uint rentDuration = 100;

        // create a batch rental order instantiation
        RentalOrder[] memory orders = new RentalOrder[](3);

        // create the rental order batch
        for (uint256 i = 0; i < orders.length; i++) {
            // mint tokens to the payment escrow
            erc20s[0].mint(address(ESCRW), amount);

            // impersonate an address with permissions
            vm.prank(address(create));

            // increase the deposit
            ESCRW.increaseDeposit(address(erc20s[0]), amount);

            // create rental items
            Item[] memory items = new Item[](1);
            items[0] = Item({
                itemType: ItemType.ERC20,
                settleTo: SettleTo.LENDER,
                token: address(erc20s[0]),
                amount: amount,
                identifier: 0
            });

            // create a rental order
            orders[i] = RentalOrder({
                seaportOrderHash: keccak256(abi.encode("someSeaportOrderHash")),
                items: items,
                hooks: new Hook[](0),
                orderType: OrderType.BASE,
                lender: alice.addr,
                renter: bob.addr,
                rentalWallet: address(bob.safe),
                startTimestamp: block.timestamp,
                endTimestamp: block.timestamp + rentDuration
            });
        }

        // warp ahead until the rent duration is over
        vm.warp(block.timestamp + rentDuration);

        // impersonate an address with permissions
        vm.prank(address(stop));

        // settle the payment
        ESCRW.settlePaymentBatch(orders);

        // assert funds are no longer the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW)), 0);

        // assert the payment was synced
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 0);

        // assert the lender address received each of the payments
        assertEq(erc20s[0].balanceOf(alice.addr), 10300);
    }

    function test_Reverts_SettlePaymentBatch_NoPermissions() public {
        // determine an amount of tokens to mint
        uint256 amount = 100;

        // determine a rent duration
        uint rentDuration = 100;

        // create a batch rental order instantiation
        RentalOrder[] memory orders = new RentalOrder[](3);

        // create the rental order batch
        for (uint256 i = 0; i < orders.length; i++) {
            // mint tokens to the payment escrow
            erc20s[0].mint(address(ESCRW), amount);

            // impersonate an address with permissions
            vm.prank(address(create));

            // increase the deposit
            ESCRW.increaseDeposit(address(erc20s[0]), amount);

            // create rental items
            Item[] memory items = new Item[](1);
            items[0] = Item({
                itemType: ItemType.ERC20,
                settleTo: SettleTo.LENDER,
                token: address(erc20s[0]),
                amount: amount,
                identifier: 0
            });

            // create a rental order
            orders[i] = RentalOrder({
                seaportOrderHash: keccak256(abi.encode("someSeaportOrderHash")),
                items: items,
                hooks: new Hook[](0),
                orderType: OrderType.BASE,
                lender: alice.addr,
                renter: bob.addr,
                rentalWallet: address(bob.safe),
                startTimestamp: block.timestamp,
                endTimestamp: block.timestamp + rentDuration
            });
        }

        // warp ahead until the rent duration is over
        vm.warp(block.timestamp + rentDuration);

        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        ESCRW.settlePaymentBatch(orders);
    }

    function test_Success_IncreaseDeposit() public {
        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), 100);

        // impersonate an address with permissions
        vm.prank(address(create));

        // increase deposit
        ESCRW.increaseDeposit(address(erc20s[0]), 100);

        // assert the payment was synced
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 100);
    }

    function test_Reverts_IncreaseDeposit_NoPermissions() public {
        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), 100);

        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        ESCRW.increaseDeposit(address(erc20s[0]), 100);
    }

    function test_Reverts_IncreaseDeposit_ZeroPayment() public {
        // impersonate an address without permissions
        vm.prank(address(create));

        // Expect revert because no amount was provided
        vm.expectRevert(
            abi.encodeWithSelector(Errors.PaymentEscrow_ZeroPayment.selector)
        );
        ESCRW.increaseDeposit(address(erc20s[0]), 0);
    }

    function test_Success_Skim() public {
        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), 150);

        // impersonate an address with permissions
        vm.prank(address(create));

        // increase deposit
        ESCRW.increaseDeposit(address(erc20s[0]), 100);

        // assert all funds are in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW)), 150);

        // assert the payment was synced
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 100);

        // impersonate an address with permissions
        vm.prank(address(admin));

        // skim the unsynced funds to alice
        ESCRW.skim(address(erc20s[0]), alice.addr);

        // assert non-synced funds are no longer the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW)), 100);

        // assert non-synced funds were sent to alice
        assertEq(erc20s[0].balanceOf(alice.addr), 10050);
    }

    function test_Reverts_Skim_NoPermissions() public {
        // mint tokens to the payment escrow
        erc20s[0].mint(address(ESCRW), 150);

        // impersonate an address with permissions
        vm.prank(address(create));

        // increase deposit
        ESCRW.increaseDeposit(address(erc20s[0]), 100);

        // assert all funds are in the escrow
        assertEq(erc20s[0].balanceOf(address(ESCRW)), 150);

        // assert the payment was synced
        assertEq(ESCRW.balanceOf(address(erc20s[0])), 100);

        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        ESCRW.skim(address(erc20s[0]), alice.addr);
    }

    function test_Fuzz_SetFee(uint256 fee) public {
        // fee must be less than or equal to the denominator
        vm.assume(fee <= 10000);

        // impersonate an address with permissions
        vm.prank(address(admin));

        // set the fee
        ESCRW.setFee(fee);

        // assert the fee was set
        assertEq(ESCRW.fee(), fee);
    }

    function test_Reverts_SetFee_FeeNumeratorTooHigh() public {
        // impersonate an address with permissions
        vm.prank(address(admin));

        // Expect revert because the fee numerator was too high
        vm.expectRevert(
            abi.encodeWithSelector(Errors.PaymentEscrow_InvalidFeeNumerator.selector)
        );
        ESCRW.setFee(10001);
    }

    function test_Reverts_SetFee_NoPermissions() public {
        // impersonate an address without permissions
        vm.prank(alice.addr);

        // Expect revert because the caller does not have permissions
        vm.expectRevert(
            abi.encodeWithSelector(Errors.Module_PolicyNotAuthorized.selector, alice.addr)
        );
        ESCRW.setFee(10);
    }
}
