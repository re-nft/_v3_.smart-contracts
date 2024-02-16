// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Vm} from "@forge-std/Vm.sol";

import {TokenCreator} from "@test/fixtures/protocol/TokenCreator.sol";

import {Create2Deployer} from "@src/Create2Deployer.sol";
import {Kernel, Actions} from "@src/Kernel.sol";
import {Storage} from "@src/modules/Storage.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";
import {Create} from "@src/policies/Create.sol";
import {Stop} from "@src/policies/Stop.sol";
import {Factory} from "@src/policies/Factory.sol";
import {Admin} from "@src/policies/Admin.sol";
import {Guard} from "@src/policies/Guard.sol";
import {Fallback} from "@src/policies/Fallback.sol";
import {toRole} from "@src/libraries/KernelUtils.sol";
import {Proxy} from "@src/proxy/Proxy.sol";

// Deploys all V3 protocol contracts
contract Protocol is TokenCreator {
    // Kernel
    Kernel public kernel;

    // Modules
    Storage public STORE;
    PaymentEscrow public ESCRW;

    // Module implementation addresses
    Storage public storageImplementation;
    PaymentEscrow public paymentEscrowImplementation;

    // Policies
    Create public create;
    Stop public stop;
    Factory public factory;
    Admin public admin;
    Guard public guard;
    Fallback public fallbackPolicy;

    // Protocol accounts
    Vm.Wallet public rentalSigner;
    Vm.Wallet public deployer;

    // protocol constants
    bytes12 public protocolVersion;
    bytes32 public salt;

    function _deployKernel() internal {
        // abi encode the kernel bytecode and constructor arguments
        bytes memory kernelInitCode = abi.encodePacked(
            type(Kernel).creationCode,
            abi.encode(deployer.addr, deployer.addr)
        );

        // Deploy kernel contract
        vm.prank(deployer.addr);
        kernel = Kernel(create2Deployer.deploy(salt, kernelInitCode));

        // label the contract
        vm.label(address(kernel), "kernel");
    }

    function _deployStorageModule() internal {
        // abi encode the storage bytecode and constructor arguments
        // for the implementation contract
        bytes memory storageImplementationInitCode = abi.encodePacked(
            type(Storage).creationCode,
            abi.encode(address(0))
        );

        // Deploy storage implementation contract
        vm.prank(deployer.addr);
        storageImplementation = Storage(
            create2Deployer.deploy(salt, storageImplementationInitCode)
        );

        // abi encode the storage bytecode and initialization arguments
        // for the proxy contract
        bytes memory storageProxyInitCode = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(
                address(storageImplementation),
                abi.encodeWithSelector(
                    Storage.MODULE_PROXY_INSTANTIATION.selector,
                    address(kernel)
                )
            )
        );

        // Deploy storage proxy contract
        vm.prank(deployer.addr);
        STORE = Storage(create2Deployer.deploy(salt, storageProxyInitCode));

        // label the contracts
        vm.label(address(STORE), "STORE");
        vm.label(address(storageImplementation), "STORE_IMPLEMENTATION");
    }

    function _deployPaymentEscrowModule() internal {
        // abi encode the payment escrow bytecode and constructor arguments
        // for the implementation contract
        bytes memory paymentEscrowImplementationInitCode = abi.encodePacked(
            type(PaymentEscrow).creationCode,
            abi.encode(address(0))
        );

        // Deploy payment escrow implementation contract
        vm.prank(deployer.addr);
        paymentEscrowImplementation = PaymentEscrow(
            create2Deployer.deploy(salt, paymentEscrowImplementationInitCode)
        );

        // abi encode the payment escrow bytecode and initialization arguments
        // for the proxy contract
        bytes memory paymentEscrowProxyInitCode = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(
                address(paymentEscrowImplementation),
                abi.encodeWithSelector(
                    PaymentEscrow.MODULE_PROXY_INSTANTIATION.selector,
                    address(kernel)
                )
            )
        );

        // Deploy payment escrow contract
        vm.prank(deployer.addr);
        ESCRW = PaymentEscrow(create2Deployer.deploy(salt, paymentEscrowProxyInitCode));

        // label the contracts
        vm.label(address(ESCRW), "ESCRW");
        vm.label(address(paymentEscrowImplementation), "ESCRW_IMPLEMENTATION");
    }

    function _deployCreatePolicy() internal {
        // abi encode the create policy bytecode and constructor arguments
        bytes memory createInitCode = abi.encodePacked(
            type(Create).creationCode,
            abi.encode(address(kernel))
        );

        // Deploy create rental policy contract
        vm.prank(deployer.addr);
        create = Create(create2Deployer.deploy(salt, createInitCode));

        // label the contract
        vm.label(address(create), "CreatePolicy");
    }

    function _deployStopPolicy() internal {
        // abi encode the stop policy bytecode and constructor arguments
        bytes memory stopInitCode = abi.encodePacked(
            type(Stop).creationCode,
            abi.encode(address(kernel))
        );

        // Deploy stop rental policy contract
        vm.prank(deployer.addr);
        stop = Stop(create2Deployer.deploy(salt, stopInitCode));

        // label the contract
        vm.label(address(stop), "StopPolicy");
    }

    function _deployAdminPolicy() internal {
        // abi encode the admin policy bytecode and constructor arguments
        bytes memory adminInitCode = abi.encodePacked(
            type(Admin).creationCode,
            abi.encode(address(kernel))
        );

        // Deploy admin policy contract
        vm.prank(deployer.addr);
        admin = Admin(create2Deployer.deploy(salt, adminInitCode));

        // label the contract
        vm.label(address(admin), "AdminPolicy");
    }

    function _deployGuardPolicy() internal {
        // abi encode the guard policy bytecode and constructor arguments
        bytes memory guardInitCode = abi.encodePacked(
            type(Guard).creationCode,
            abi.encode(address(kernel))
        );

        // Deploy guard policy contract
        vm.prank(deployer.addr);
        guard = Guard(create2Deployer.deploy(salt, guardInitCode));

        // label the contract
        vm.label(address(guard), "GuardPolicy");
    }

    function _deployFallbackPolicy() internal {
        // abi encode the fallback policy bytecode and constructor arguments
        bytes memory fallbackInitCode = abi.encodePacked(
            type(Fallback).creationCode,
            abi.encode(address(kernel))
        );

        // Deploy falback policy contract
        vm.prank(deployer.addr);
        fallbackPolicy = Fallback(create2Deployer.deploy(salt, fallbackInitCode));

        // label the contract
        vm.label(address(fallbackPolicy), "fallbackPolicy");
    }

    function _deployFactoryPolicy() internal {
        // abi encode the factory policy bytecode and constructor arguments
        bytes memory factoryInitCode = abi.encodePacked(
            type(Factory).creationCode,
            abi.encode(
                address(kernel),
                address(stop),
                address(guard),
                address(fallbackPolicy),
                address(safeProxyFactory),
                address(safeSingleton)
            )
        );

        // Deploy factory policy contract
        vm.prank(deployer.addr);
        factory = Factory(create2Deployer.deploy(salt, factoryInitCode));

        // label the contract
        vm.label(address(factory), "FactoryPolicy");
    }

    function _setupKernel() internal {
        // Start impersonating the deployer
        vm.startPrank(deployer.addr);

        // Install modules
        kernel.executeAction(Actions.InstallModule, address(STORE));
        kernel.executeAction(Actions.InstallModule, address(ESCRW));

        // Approve policies
        kernel.executeAction(Actions.ActivatePolicy, address(create));
        kernel.executeAction(Actions.ActivatePolicy, address(stop));
        kernel.executeAction(Actions.ActivatePolicy, address(factory));
        kernel.executeAction(Actions.ActivatePolicy, address(guard));
        kernel.executeAction(Actions.ActivatePolicy, address(admin));
        kernel.executeAction(Actions.ActivatePolicy, address(fallbackPolicy));

        // Grant `seaport` role to seaport protocol
        kernel.grantRole(toRole("SEAPORT"), address(seaport));

        // Grant `signer` role to the protocol signer to sign off on create payloads
        kernel.grantRole(toRole("CREATE_SIGNER"), rentalSigner.addr);

        // Grant `create_admin` role to the address which can open or close token approvals
        // for the payment escrow to pull funds from the create policy
        kernel.grantRole(toRole("CREATE_ADMIN"), deployer.addr);

        // Grant 'admin_admin` role to the address which can conduct admin operations on the protocol
        kernel.grantRole(toRole("ADMIN_ADMIN"), deployer.addr);

        // Grant 'guard_admin` role to the address which can toggle hooks
        kernel.grantRole(toRole("GUARD_ADMIN"), deployer.addr);

        // Grant `stop_admin` role to the address which can skim funds from the payment escrow
        kernel.grantRole(toRole("STOP_ADMIN"), deployer.addr);

        // Stop impersonating the deployer
        vm.stopPrank();
    }

    function _performAdminDuties() public {
        // Start impersonating the deployer
        vm.startPrank(deployer.addr);

        // Set the maximum rent duration to 21 days
        admin.setMaxRentDuration(21 days);

        // Enable all mock ERC20 tokens for payment
        for (uint256 i = 0; i < erc20s.length; ++i) {
            admin.toggleWhitelistPayment(address(erc20s[i]), true);

            // approve the payment escrow to pull payments from the create policy
            create.approveEscrowPayment(address(erc20s[i]), type(uint256).max);
        }

        // Enable all mock ERC721 tokens for rental
        for (uint256 i = 0; i < erc721s.length; ++i) {
            admin.toggleWhitelistAsset(address(erc721s[i]), true);
        }

        // Enable all mock ERC1155 tokens for rental
        for (uint256 i = 0; i < erc1155s.length; ++i) {
            admin.toggleWhitelistAsset(address(erc1155s[i]), true);
        }

        // Stop impersonating the deployer
        vm.stopPrank();
    }

    function setUp() public virtual override {
        // setup dependencies
        super.setUp();

        // create the rental signer address and private key
        rentalSigner = vm.createWallet("rentalSigner");

        // create the deployer address and private key
        deployer = vm.createWallet("deployer");

        // contract salts (using 0x000000000000000000000100 to represent a version 1.0.0 of each contract)
        protocolVersion = 0x000000000000000000000100;
        salt = create2Deployer.generateSaltWithSender(deployer.addr, protocolVersion);

        // deploy kernel
        _deployKernel();

        // Deploy payment escrow
        _deployPaymentEscrowModule();

        // Deploy rental storage
        _deployStorageModule();

        // Deploy fallback policy
        _deployFallbackPolicy();

        // deploy create policy
        _deployCreatePolicy();

        // deploy stop policy
        _deployStopPolicy();

        // deploy admin policy
        _deployAdminPolicy();

        // Deploy guard policy
        _deployGuardPolicy();

        // deploy rental factory
        _deployFactoryPolicy();

        // intialize the kernel
        _setupKernel();

        // perform admin duties
        _performAdminDuties();
    }
}
