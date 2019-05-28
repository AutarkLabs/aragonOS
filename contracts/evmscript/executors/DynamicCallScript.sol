pragma solidity 0.4.24;

// Inspired by https://github.com/reverendus/tx-manager

import "../ScriptHelpers.sol";
import "./BaseEVMScriptExecutor.sol";


contract DynamicCallsScript is BaseEVMScriptExecutor {
    using ScriptHelpers for bytes;

    bytes32 internal constant EXECUTOR_TYPE = keccak256("DYNAMIC_CALLS_SCRIPT");

    string private constant ERROR_BLACKLISTED_CALL = "EVMCALLS_BLACKLISTED_CALL";
    string private constant ERROR_INVALID_LENGTH = "EVMCALLS_INVALID_LENGTH";

    event LogScriptCall(address indexed sender, address indexed src, address indexed dst);

    /**
    * @notice Executes a number of call scripts
    * @param _script [ specId (uint32) ] many calls with this structure ->
    *    [ to (address: 20 bytes) ] [ calldataLength (uint32: 4 bytes) ] [ calldata (calldataLength bytes) ]
    * @param _input bytes input used to modify the _script based on forwarder action state
    * @param _blacklist Addresses the script cannot call to, or will revert.
    * @return Always returns empty byte array
    */
    function execScript(bytes _script, bytes _input, address[] _blacklist) external isInitialized returns (bytes) {
        // Implement input<->script merge
        //Implement script execution
    }

    function executorType() external pure returns (bytes32) {
        return EXECUTOR_TYPE;
    }
}
