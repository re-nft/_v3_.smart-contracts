// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Seaport} from "@seaport-core/Seaport.sol";
import {ConduitInterface} from "@seaport-types/interfaces/ConduitInterface.sol";
import {ConduitController} from "@seaport-core/conduit/ConduitController.sol";
import {LibString} from "@solady/utils/LibString.sol";

import {Deployer} from "@scripts/base/Deployer.sol";

import {Create2Deployer} from "@src/Create2Deployer.sol";
import {Kernel, Actions} from "@src/Kernel.sol";
import {Storage} from "@src/modules/Storage.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";
import {Create} from "@src/policies/Create.sol";
import {Stop} from "@src/policies/Stop.sol";
import {Factory} from "@src/policies/Factory.sol";
import {Admin} from "@src/policies/Admin.sol";
import {Guard} from "@src/policies/Guard.sol";
import {toRole} from "@src/libraries/KernelUtils.sol";
import {Proxy} from "@src/proxy/Proxy.sol";

// Contains functions to deploy the protocol. This contract should be
// inherited by all deployment scripts
contract BaseDeploy is Deployer {
    // protocol-deployed forked Seaport contracts
    Seaport public seaport;
    ConduitController public conduitController;

    // protocol-deployed seaport conduit
    ConduitInterface public conduit;
    bytes32 public conduitKey;

    // Deployer
    Create2Deployer public create2Deployer;

    // Kernel
    Kernel public kernel;

    // Modules
    Storage public STORE;
    PaymentEscrow public ESCRW;

    // Module implementation addresses
    Storage public STORE_IMPL;
    PaymentEscrow public ESCRW_IMPL;

    // policies
    Create public create;
    Stop public stop;
    Factory public factory;
    Admin public admin;
    Guard public guard;

    function setUp() public override {
        super.setUp();

        // load in config values
        seaport = Seaport(payable(config.seaport()));
        conduitController = ConduitController(config.conduitController());
        conduit = ConduitInterface(config.conduit());
        conduitKey = config.conduitKey();
        create2Deployer = Create2Deployer(config.create2Deployer());
        kernel = Kernel(config.kernel());
        STORE = Storage(config.store());
        ESCRW = PaymentEscrow(config.escrw());
        STORE_IMPL = Storage(config.storeImpl());
        ESCRW_IMPL = PaymentEscrow(config.escrwImpl());
        create = Create(config.create());
        stop = Stop(config.stop());
        factory = Factory(config.factory());
        admin = Admin(config.admin());
        guard = Guard(config.guard());
    }

    function _displayChainInfo() internal view {
        console2.log("##############################################");
        console2.log("###           DEPLOYMENT CONFIG            ###");
        console2.log("##############################################");
        console2.log("");
        console2.log("Chain:        %s", chain);
        console2.log("Deployer:     %s", deployer);
        console2.log("");
    }

    function _displayProtocolAddressesBanner() internal pure {
        console2.log("##############################################");
        console2.log("###          PROTOCOL ADDRESSES            ###");
        console2.log("##############################################");
        console2.log("");
    }

    function _displayUpdatedAddressWarning() internal pure {
        console2.log("");
        console2.log("Make sure to update JSON configs with the lastest addresses!");
    }

    function _bytes32ToString(bytes32 value) internal pure returns (string memory) {
        return LibString.toHexString(uint256(value), 32);
    }

    function _generateSaltWithSender(
        address deployer,
        bytes12 data
    ) internal view returns (bytes32) {
        require(
            address(create2Deployer) != address(0),
            "No create2 deployer address provided in config."
        );

        // generate the salt
        return create2Deployer.generateSaltWithSender(deployer, data);
    }

    function _deployCreate2Deployer() internal broadcast {
        // Deploy the create2 deployer contract
        create2Deployer = new Create2Deployer();
    }

    function _deployKernel(bytes32 salt) internal broadcast {
        // abi encode the kernel bytecode and constructor arguments
        bytes memory kernelInitCode = abi.encodePacked(
            type(Kernel).creationCode,
            abi.encode(deployer, deployer)
        );

        // Deploy kernel contract
        kernel = Kernel(create2Deployer.deploy(salt, kernelInitCode));

        // expected address
        address expectedAddress = create2Deployer.getCreate2Address(salt, kernelInitCode);

        // ensure the kernel was deployed properly
        require(
            address(kernel) == expectedAddress,
            "kernel expected address is incorrect"
        );

        // ensure kernel was initialized properly
        require(kernel.admin() == deployer, "kernel admin is incorrect");
        require(kernel.executor() == deployer, "kernel executor is incorrect");
    }

    function _deployConduitController() internal broadcast {
        // deploy conduit controller
        conduitController = new ConduitController();
    }

    function _deploySeaport() internal broadcast {
        require(
            address(conduitController) != address(0),
            "No conduitController address provided in config."
        );

        // deploy seaport
        seaport = new Seaport(address(conduitController));
    }

    function _deployConduit(bytes32 salt) internal broadcast {
        require(address(seaport) != address(0), "No seaport address provided in config.");

        // use salt that already contains information about the deployer as conduit key
        conduitKey = salt;

        // create a new conduit
        address conduitAddress = conduitController.createConduit(conduitKey, deployer);

        // set the conduit address
        conduit = ConduitInterface(conduitAddress);

        // open a channel for seaport on the conduit
        conduitController.updateChannel(address(conduit), address(seaport), true);
    }

    function _deployStorageModule(bytes32 salt) internal broadcast {
        require(address(kernel) != address(0), "No kernel address provided in config.");

        // abi encode the storage bytecode and constructor arguments
        // for the implementation contract
        bytes memory storageImplementationInitCode = abi.encodePacked(
            type(Storage).creationCode,
            abi.encode(address(0))
        );

        // Deploy storage implementation contract
        STORE_IMPL = Storage(create2Deployer.deploy(salt, storageImplementationInitCode));

        // abi encode the storage bytecode and initialization arguments
        // for the proxy contract
        bytes memory storageProxyInitCode = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(
                address(STORE_IMPL),
                abi.encodeWithSelector(
                    Storage.MODULE_PROXY_INSTANTIATION.selector,
                    address(kernel)
                )
            )
        );

        // Deploy storage proxy contract
        STORE = Storage(create2Deployer.deploy(salt, storageProxyInitCode));

        // expected addresses
        address expectedProxyAddress = create2Deployer.getCreate2Address(
            salt,
            storageProxyInitCode
        );
        address expectedImplementationAddress = create2Deployer.getCreate2Address(
            salt,
            storageImplementationInitCode
        );

        require(
            address(STORE) == expectedProxyAddress,
            "rental storage proxy expected address is incorrect"
        );
        require(
            address(STORE_IMPL) == expectedImplementationAddress,
            "rental storage implementation expected address is incorrect"
        );

        // ensure the module was initialized properly
        require(
            address(STORE.kernel()) == address(kernel),
            "storage module not initialized properly"
        );
    }

    function _deployPaymentEscrowModule(bytes32 salt) internal broadcast {
        require(address(kernel) != address(0), "No kernel address provided in config.");

        // abi encode the paymentEscrow bytecode and constructor arguments
        // for the implementation contract
        bytes memory paymentEscrowImplementationInitCode = abi.encodePacked(
            type(PaymentEscrow).creationCode,
            abi.encode(address(0))
        );

        // Deploy payment escrow implementation contract
        ESCRW_IMPL = PaymentEscrow(
            create2Deployer.deploy(salt, paymentEscrowImplementationInitCode)
        );

        // abi encode the payment escrow bytecode and initialization arguments
        // for the proxy contract
        bytes memory paymentEscrowProxyInitCode = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(
                address(ESCRW_IMPL),
                abi.encodeWithSelector(
                    PaymentEscrow.MODULE_PROXY_INSTANTIATION.selector,
                    address(kernel)
                )
            )
        );

        // Deploy payment escrow proxy contract
        ESCRW = PaymentEscrow(create2Deployer.deploy(salt, paymentEscrowProxyInitCode));

        // expected addresses
        address expectedProxyAddress = create2Deployer.getCreate2Address(
            salt,
            paymentEscrowProxyInitCode
        );
        address expectedImplementationAddress = create2Deployer.getCreate2Address(
            salt,
            paymentEscrowImplementationInitCode
        );

        require(
            address(ESCRW) == expectedProxyAddress,
            "payment escrow proxy expected address is incorrect"
        );
        require(
            address(ESCRW_IMPL) == expectedImplementationAddress,
            "payment escrow implementation expected address is incorrect"
        );

        // ensure the module was initialized properly
        require(
            address(ESCRW.kernel()) == address(kernel),
            "payment escrow module not initialized properly"
        );
    }

    function _deployCreatePolicy(bytes32 salt) internal broadcast {
        require(address(kernel) != address(0), "No kernel address provided in config.");

        // abi encode the create policy bytecode and constructor arguments
        bytes memory createInitCode = abi.encodePacked(
            type(Create).creationCode,
            abi.encode(address(kernel))
        );

        // Deploy create rental policy contract
        create = Create(create2Deployer.deploy(salt, createInitCode));

        // expected address
        address expectedAddress = create2Deployer.getCreate2Address(salt, createInitCode);

        // ensure the create policy was deployed properly
        require(
            address(create) == expectedAddress,
            "create policy expected address is incorrect"
        );
    }

    function _deployStopPolicy(bytes32 salt) internal broadcast {
        require(address(kernel) != address(0), "No kernel address provided in config.");

        // abi encode the stop policy bytecode and constructor arguments
        bytes memory stopInitCode = abi.encodePacked(
            type(Stop).creationCode,
            abi.encode(address(kernel))
        );

        // Deploy stop rental policy contract
        stop = Stop(create2Deployer.deploy(salt, stopInitCode));

        // expected address
        address expectedAddress = create2Deployer.getCreate2Address(salt, stopInitCode);

        // ensure the stop policy was deployed properly
        require(
            address(stop) == expectedAddress,
            "stop policy expected address is incorrect"
        );
    }

    function _deployAdminPolicy(bytes32 salt) internal broadcast {
        require(address(kernel) != address(0), "No kernel address provided in config.");

        // abi encode the admin policy bytecode and constructor arguments
        bytes memory adminInitCode = abi.encodePacked(
            type(Admin).creationCode,
            abi.encode(address(kernel))
        );

        // Deploy admin policy contract
        admin = Admin(create2Deployer.deploy(salt, adminInitCode));

        // expected address
        address expectedAddress = create2Deployer.getCreate2Address(salt, adminInitCode);

        // ensure the admin policy was deployed properly
        require(
            address(admin) == expectedAddress,
            "admin policy expected address is incorrect"
        );
    }

    function _deployGuardPolicy(bytes32 salt) internal broadcast {
        require(address(kernel) != address(0), "No kernel address provided in config.");

        // abi encode the guard policy bytecode and constructor arguments
        bytes memory guardInitCode = abi.encodePacked(
            type(Guard).creationCode,
            abi.encode(address(kernel))
        );

        // Deploy guard policy contract
        guard = Guard(create2Deployer.deploy(salt, guardInitCode));

        // expected address
        address expectedAddress = create2Deployer.getCreate2Address(salt, guardInitCode);

        // ensure the guard policy was deployed properly
        require(
            address(guard) == expectedAddress,
            "guard policy expected address is incorrect"
        );
    }

    function _deployFactoryPolicy(
        bytes32 salt,
        address safeCallbackHandler,
        address safeProxyFactory,
        address safeSingleton
    ) internal broadcast {
        // ensure there are no zero addresses
        require(address(kernel) != address(0), "No kernel address provided in config.");
        require(address(stop) != address(0), "No stop address provided in config.");
        require(address(guard) != address(0), "No guard address provided in config.");
        require(
            safeCallbackHandler != address(0),
            "No safeCallbackHandler address provided in config."
        );
        require(
            safeProxyFactory != address(0),
            "No safeProxyFactory address provided in config."
        );
        require(
            safeSingleton != address(0),
            "No safeSingleton address provided in config."
        );

        // abi encode the factory policy bytecode and constructor arguments
        bytes memory factoryInitCode = abi.encodePacked(
            type(Factory).creationCode,
            abi.encode(
                address(kernel),
                address(stop),
                address(guard),
                safeCallbackHandler,
                safeProxyFactory,
                safeSingleton
            )
        );

        // Deploy factory policy contract
        factory = Factory(create2Deployer.deploy(salt, factoryInitCode));

        // expected address
        address expectedAddress = create2Deployer.getCreate2Address(
            salt,
            factoryInitCode
        );

        // ensure the factory was initialized properly
        require(
            address(factory.fallbackHandler()) == safeCallbackHandler,
            "factory callback handler address is incorrect"
        );
        require(
            address(factory.safeProxyFactory()) == safeProxyFactory,
            "factory safe proxy address is incorrect"
        );
        require(
            address(factory.safeSingleton()) == safeSingleton,
            "factory singleton address is incorrect"
        );
        require(
            address(factory) == expectedAddress,
            "factory expected address is incorrect"
        );
    }

    function _setUpPolicy(address policy) internal broadcast {
        // ensure that the kernel has already been deployed
        require(address(kernel) != address(0), "No kernel address provided in config.");

        // ensure that the policy has already been deployed
        require(policy != address(0), "No admin address provided in config.");

        // ensure that all modules have been deployed
        require(address(STORE) != address(0), "No STORE address provided in config.");
        require(address(ESCRW) != address(0), "no ESCRW address provided in config");

        // Approve the policy
        kernel.executeAction(Actions.ActivatePolicy, policy);
    }

    function _setUpModule(address module) internal broadcast {
        // ensure that the kernel has already been deployed
        require(address(kernel) != address(0), "No kernel address provided in config.");

        // Install module
        kernel.executeAction(Actions.InstallModule, module);
    }

    function _grantRole(bytes32 role, address to) internal broadcast {
        // Grant role for privileged access
        kernel.grantRole(toRole(role), to);
    }

    function _setFee(uint256 numerator) internal broadcast {
        // Set the protocol fee
        admin.setFee(numerator);
    }

    function _setMaxRentDuration(uint256 duration) internal broadcast {
        // Set the max rent duration
        admin.setMaxRentDuration(duration);
    }
}
