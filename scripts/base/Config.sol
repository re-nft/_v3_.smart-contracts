// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "@forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {LibString} from "@solady/utils/LibString.sol";

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
    address public safeTokenCallbackHandler;
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
    address public seaport;
    address public conduitController;
    address public conduit;
    bytes32 public conduitKey;

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
        safeTokenCallbackHandler = _parseAddress("$.safeTokenCallbackHandler");
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
        seaport = _parseAddress("$.seaport");
        conduitController = _parseAddress("$.conduitController");
        conduit = _parseAddress("$.conduit");
        conduitKey = _parseBytes32("$.conduitKey");
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
}
