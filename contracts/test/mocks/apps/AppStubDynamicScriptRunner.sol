pragma solidity 0.4.24;

import "../../../apps/AragonApp.sol";
import "../../../common/ADynamicForwarder.sol";
//import "../../../common/IForwarder.sol";


contract AppStubDynamicScriptRunner is AragonApp, ADynamicForwarder {
    event ReturnedBytes(bytes returnedBytes);
    event SupportUpdated(uint256 actionId, uint256 optionId, uint256 support);

    // Initialization is required to access any of the real executors
    function initialize() public {
        initialized();
    }

    function parseNewAction(bytes _evmScript) public {
        parseScript(_evmScript);
    }

    // Populate action without parsing an execution script
    function newSyntheticAction(bytes _executionScript, string _description) public {
        uint256 actionId = actions.length++;
        Action storage action = actions[actionId];
        action.externalId = 54;   //uint256 externalId;
        action.metadata = "testmetadata";      //string metadata;
        action.description = _description;   //string description;
        action.infoStringLength = 0;                  //uint256 infoStringLength;
        action.executionScript = _executionScript;    //bytes executionScript;
        action.scriptOffset = 0;    //uint256 scriptOffset;
        action.scriptRemainder = _executionScript.length;    //uint256 scriptRemainder;
        action.executed = false;    //bool executed;
        //addOption(actionId, "opt1", 0x52ab26196E7144B28C117d61311e546f8D3fB799, bytes32(51), bytes32(71));
        //addOption(actionId, "opt2", 0x50262f164A4FE4AeeA1C88BbAAa5Ce7009ADf722, bytes32(52), bytes32(72));
        //addOption(actionId, "opt3", 0x67671de5CA3bB02aDf4Bc82Ab8753D218C6f5484, bytes32(53), bytes32(73));
    }

    function addExternalOption(uint256 _actionId, string _info, address _optionDescription, bytes32 _id1, bytes32 _id2) public {
        addOption(_actionId, _info, _optionDescription, _id1, _id2);
    }

    function runScript(uint256 _actionId) public returns (bytes) {
        bytes memory script = encodeInput(_actionId);
        emit ReturnedBytes(script);
        bytes memory returnedBytes = script;
        runScript(script, new bytes(0), new address[](0));
        //emit ReturnedBytes(returnedBytes);
        return returnedBytes;
    }

    function updateSupport(uint256 _actionId, uint256 _optionIndex, uint256 _support) public {
        Action storage actionInstance = actions[_actionId];
        OptionState storage option = actionInstance.options[actionInstance.optionKeys[_optionIndex]];
        option.actionSupport = _support;
        emit SupportUpdated(_actionId, _optionIndex, _support);
    }

    //function runScriptWithBan(bytes script, address[] memory blacklist) public returns (bytes) {
    //    bytes memory returnedBytes = runScript(script, new bytes(0), blacklist);
    //    emit ReturnedBytes(returnedBytes);
    //    return returnedBytes;
    //}

    //function runScriptWithIO(bytes script, bytes input, address[] memory blacklist) public returns (bytes) {
    //    bytes memory returnedBytes = runScript(script, input, blacklist);
    //    emit ReturnedBytes(returnedBytes);
    //    return returnedBytes;
    //}

    //function runScriptWithNewBytesAllocation(bytes script) public returns (bytes) {
    //    bytes memory returnedBytes = runScript(script, new bytes(0), new address[](0));
    //    bytes memory newBytes = new bytes(64);
    //    // Fill in new bytes array with some dummy data to let us check it doesn't corrupt the
    //    // script's returned bytes
    //    uint256 first = uint256(keccak256("test"));
    //    uint256 second = uint256(keccak256("mock"));
    //    assembly {
    //        mstore(add(newBytes, 0x20), first)
    //        mstore(add(newBytes, 0x40), second)
    //    }
    //    emit ReturnedBytes(returnedBytes);
    //    return returnedBytes;
    //}

    ///////////////////////
    // IForwarder functions
    ///////////////////////

    /**
    * @notice `isForwarder` is a basic helper function used to determine
    *         if a function implements the IForwarder interface
    * @dev IForwarder interface conformance
    * @return always returns true
    */
    function isForwarder() public pure returns (bool) {
        return true;
    }

    /**
    * @notice Used to ensure that the permissions are being handled properly
    *         for forwarding
    * @dev IForwarder interface conformance
    * @param _sender Address of the entity trying to forward
    * @return True is `_sender` has correct permissions
    */
    function canForward(address _sender, bytes /*_evmCallScript*/) public view returns (bool) {
        return true;
    }

    // * @param _evmCallScript Not used in this implementation

        /**
    * @notice Creates a vote to execute the desired action
    * @dev IForwarder interface conformance
    * @param _evmScript Start vote with script
    */
    function forward(bytes _evmScript) public { // solium-disable-line function-order
        parseNewAction(_evmScript); /*, true);*/
    }

    /*
    function getActionsCount(bytes script) public constant returns (uint256) {
        return getScriptActionsCount(script);
    }

    function getAction(bytes script, uint256 i) public constant returns (address, bytes) {
        return getScriptAction(script, i);
    }
    */
}
