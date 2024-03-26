// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "@forge-std/Script.sol";
import {LibString} from "@solady/utils/LibString.sol";

struct AssetWhitelist {
    address asset;
    bool enableRent;
    string name;
    bool preventPermit;
}

struct PaymentWhitelist {
    address asset;
    bool enabled;
    string name;
}

// Contract dedicated to loading in a JSON configuration file for the
// chain to deploy to
contract Config is Script {
    // JSON data from the config file
    string internal _json;
    string internal constant _errorString = " was not set in JSON config file.";

    // config values for deployment
    uint256 public majorVersion;
    uint256 public minorVersion;
    address public safeSingleton;
    address public safeProxyFactory;
    address public serverSideSigner;

    // active protocol contracts
    address public create2Deployer;
    address public kernel;
    address public store;
    address public escrw;
    address public storeImpl;
    address public escrwImpl;
    address public create;
    address public stop;
    address public factory;
    address public admin;
    address public guard;
    address public fallbackPolicy;
    address public seaport;
    address public conduitController;
    address public conduit;
    bytes32 public conduitKey;

    // whitelists
    AssetWhitelist[] public _assetWhitelist;
    PaymentWhitelist[] public _paymentWhitelist;

    constructor(string memory _configPath) {
        // try reading from the config file
        try vm.readFile(_configPath) returns (string memory data) {
            _json = data;
        } catch {
            revert("Unable to read config file.");
        }

        // set all JSON config variables
        majorVersion = _parseUint256("$.majorVersion");
        minorVersion = _parseUint256("$.minorVersion");
        safeSingleton = _parseAddress("$.safeSingleton");
        safeProxyFactory = _parseAddress("$.safeProxyFactory");
        serverSideSigner = _parseAddress("$.serverSideSigner");
        create2Deployer = _parseAddress("$.create2Deployer");
        kernel = _parseAddress("$.kernel");
        store = _parseAddress("$.storeModuleProxy");
        escrw = _parseAddress("$.escrwModuleProxy");
        storeImpl = _parseAddress("$.storeModuleImpl");
        escrwImpl = _parseAddress("$.escrwModuleImpl");
        create = _parseAddress("$.createPolicy");
        stop = _parseAddress("$.stopPolicy");
        factory = _parseAddress("$.factoryPolicy");
        admin = _parseAddress("$.adminPolicy");
        guard = _parseAddress("$.guardPolicy");
        fallbackPolicy = _parseAddress("$.fallbackPolicy");
        seaport = _parseAddress("$.seaport");
        conduitController = _parseAddress("$.conduitController");
        conduit = _parseAddress("$.conduit");
        conduitKey = _parseBytes32("$.conduitKey");

        // load the whitelists
        _parseAssetWhitelistArray("$.assetWhitelist");
        _parsePaymentWhitelistArray("$.paymentWhitelist");
    }

    function assetWhitelist() external view returns (AssetWhitelist[] memory) {
        return _assetWhitelist;
    }

    function paymentWhitelist() external view returns (PaymentWhitelist[] memory) {
        return _paymentWhitelist;
    }

    function _createErrorString(string memory key) internal pure returns (string memory) {
        return LibString.concat(LibString.slice(key, 2), _errorString);
    }

    function _parseUint256(string memory key) internal view returns (uint256) {
        try vm.parseJsonUint(_json, key) returns (uint256 value) {
            return value;
        } catch {
            revert(_createErrorString(key));
        }
    }

    function _parseAddress(string memory key) internal view returns (address) {
        try vm.parseJsonAddress(_json, key) returns (address value) {
            return value;
        } catch {
            revert(_createErrorString(key));
        }
    }

    function _parseBytes32(string memory key) internal view returns (bytes32) {
        try vm.parseJsonBytes32(_json, key) returns (bytes32 value) {
            return value;
        } catch {
            revert(_createErrorString(key));
        }
    }

    function _parseAssetWhitelistArray(string memory key) internal {
        // Parse the raw json
        bytes memory value = vm.parseJson(_json, key);

        // Error if no key was found
        if (value.length == 0) {
            revert(_createErrorString(key));
        }

        // Decode the asset whitelist entries from JSON
        AssetWhitelist[] memory jsonAssetWhitelistEntries = abi.decode(
            value,
            (AssetWhitelist[])
        );

        // Add each whitelist entry to storage
        for (uint256 i; i < jsonAssetWhitelistEntries.length; ++i) {
            // Get a pointer to a new asset whitelist entry
            AssetWhitelist storage storageAssetWhitelist = _assetWhitelist.push();

            // Set the JSON entry into storage
            storageAssetWhitelist.name = jsonAssetWhitelistEntries[i].name;
            storageAssetWhitelist.asset = jsonAssetWhitelistEntries[i].asset;
            storageAssetWhitelist.enableRent = jsonAssetWhitelistEntries[i].enableRent;
            storageAssetWhitelist.preventPermit = jsonAssetWhitelistEntries[i]
                .preventPermit;
        }
    }

    function _parsePaymentWhitelistArray(string memory key) internal {
        // Parse the raw json
        bytes memory value = vm.parseJson(_json, key);

        // Error if no key was found
        if (value.length == 0) {
            revert(_createErrorString(key));
        }

        // Decode the payment whitelist entries from JSON
        PaymentWhitelist[] memory jsonPaymentWhitelistEntries = abi.decode(
            value,
            (PaymentWhitelist[])
        );

        // Add each whitelist entry to storage
        for (uint256 i; i < jsonPaymentWhitelistEntries.length; ++i) {
            // Get a pointer to a new payment whitelist entry
            PaymentWhitelist storage storagePaymentWhitelist = _paymentWhitelist.push();

            // Set the JSON entry into storage
            storagePaymentWhitelist.name = jsonPaymentWhitelistEntries[i].name;
            storagePaymentWhitelist.asset = jsonPaymentWhitelistEntries[i].asset;
            storagePaymentWhitelist.enabled = jsonPaymentWhitelistEntries[i].enabled;
        }
    }
}
