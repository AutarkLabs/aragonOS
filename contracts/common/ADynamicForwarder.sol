/*
 * SPDX-License-Identitifer:    MIT
 */

pragma solidity ^0.4.24;

import "./IForwarder.sol";
import "../evmscript/ScriptHelpers.sol";
import "../lib/math/SafeMath.sol";
import "../lib/math/SafeMath64.sol";



contract ADynamicForwarder is IForwarder {
    using ScriptHelpers for bytes;
    using SafeMath for uint256;
    using SafeMath64 for uint64;

    uint256 constant public OPTION_ADDR_PARAM_LOC = 1;
    uint256 constant public OPTION_SUPPORT_PARAM_LOC = 2;
    uint256 constant public INDICIES_PARAM_LOC = 3;
    uint256 constant public OPTION_INFO_PARAM_LOC = 4;
    uint256 constant public DESCRIPTION_PARAM_LOC = 5;
    uint256 constant public EX_ID1_PARAM_LOC = 6;
    uint256 constant public EX_ID2_PARAM_LOC = 7;
    uint256 constant public TOTAL_DYNAMIC_PARAMS = 7;

    struct Action {
        uint256 externalId;
        string metadata;
        string description;
        uint256 infoStringLength;
        bytes executionScript;
        uint256 scriptOffset;
        uint256 scriptRemainder;
        bool executed;
        bytes32[] optionKeys;
        mapping (bytes32 => OptionState) options;
    }

    struct OptionState {
        bool added;
        string metadata;
        uint8 keyArrayIndex;
        uint256 actionSupport;
        bytes32 externalId1;
        bytes32 externalId2;
    }

    mapping (bytes32 => address ) optionAddresses;
    Action[] actions;

    event AddOption(uint256 actionId, address optionAddress, uint256 optionQty);
    event OptionQty(uint256 qty);
    event Address(address currentOption);

    /**
    * @notice `getOption` serves as a basic getter using the description
    *         to return the struct data.
    * @param _actionId id for action structure this 'ballot action' is connected to
    * @param _optionIndex The option descrciption of the option.
    */
    function getOption(uint256 _actionId, uint256 _optionIndex) // solium-disable-line function-order
    external view returns(address optionAddress, uint256 actionSupport, string metadata, bytes32 externalId1, bytes32 externalId2)
    {
        Action storage actionInstance = actions[_actionId];
        OptionState storage option = actionInstance.options[actionInstance.optionKeys[_optionIndex]];
        optionAddress = optionAddresses[actionInstance.optionKeys[_optionIndex]];
        actionSupport = option.actionSupport;
        metadata = option.metadata;
        externalId1 = option.externalId1;
        externalId2 = option.externalId2;
    }

    /**
    * @notice `getOptionLength` returns the total number of options for
    *         a given action.
    * @param _actionId The ID of the Action struct in the `actions` array
    */
    function getOptionLength(uint256 _actionId) public view returns
    ( uint totalOptions ) { // solium-disable-line lbrace
        totalOptions = actions[_actionId].optionKeys.length;
    }

    /**
    * @notice `getActionMetadata` simply pulls the action metadata out of a action
    *         struct and returns the individual value.
    * @param _actionId The ID of the Action struct in the `actions` array
    */
    function getActionMetadata(uint256 _actionId) public view returns (string) {
        return actions[_actionId].metadata;
    }

    /**
    * @notice `addOption` allows internal addition of options
    *         (or options) to the current action.
    * @param _actionId id for action structure this 'ballot action' is connected to
    * @param _metadata Any additional information about the option.
    *        Base implementation does not use this parameter.
    * @param _description This is the string that will be displayed along the
    *        option when voting
    */
    function addOption(uint256 _actionId, string _metadata, address _description, bytes32 eId1, bytes32 eId2)
    internal
    {
        // Get action and option into storage
        Action storage actionInstance = actions[_actionId];
        bytes32[] storage keys = actionInstance.optionKeys;
        bytes32 cKey = keccak256(abi.encodePacked(_description));
        OptionState storage option = actionInstance.options[cKey];
        // Make sure that this option has not already been added
        require(option.added == false); // solium-disable-line error-reason
        // Set all data for the option
        option.added = true;
        option.keyArrayIndex = uint8(keys.length);
        option.metadata = _metadata;
        option.externalId1 = eId1;
        option.externalId2 = eId2;
        // double check
        optionAddresses[cKey] = _description;
        keys.push(cKey);
        actionInstance.optionKeys = keys;
        actionInstance.infoStringLength += bytes(_metadata).length;
        emit AddOption(_actionId, optionAddresses[cKey], actionInstance.optionKeys.length);
    }

    function addDynamicElements(
        bytes script,
        uint256 offset,
        uint256 numberOfOptions,
        uint256 strLength,
        uint256 desLength
    ) internal pure returns(bytes)
    {
        uint256 secondDynamicElementLocation = 32 + offset + (numberOfOptions * 32);
        uint256 thirdDynamicElementLocation = secondDynamicElementLocation + 32 + (numberOfOptions * 32);
        uint256 fourthDynamicElementLocation = thirdDynamicElementLocation + 32 + (numberOfOptions * 32);
        uint256 fifthDynamicElementLocation = fourthDynamicElementLocation + (strLength / 32) * 32 + (strLength % 32 == 0 ? 32 : 64);
        uint256 sixthDynamicElementLocation = fifthDynamicElementLocation + (desLength / 32) * 32 + (desLength % 32 == 0 ? 32 : 64);
        uint256 seventhDynamicElementLocation = sixthDynamicElementLocation + 32 + (numberOfOptions * 32);

        assembly {
            mstore(add(script, 96), secondDynamicElementLocation)
            mstore(add(script, 128), thirdDynamicElementLocation)
            mstore(add(script, 160), fourthDynamicElementLocation)
            mstore(add(script, 192), fifthDynamicElementLocation)
            mstore(add(script, 224), sixthDynamicElementLocation)
            mstore(add(script, 256), seventhDynamicElementLocation)
        }

        return script;
    }

    function _goToParamOffset(uint256 _paramNum, bytes _executionScript) internal pure returns(uint256 paramOffset) {
        /*
        param numbers and what they map to:
        1. option addresses
        2. Supports values
        3. Info String indexes
        4. Info String length
        5. Description
        6. Level 1 external references
        7. level 2 external references
        */
        uint256 startOffset = 0x04 + 0x14 + 0x04;
        paramOffset = _executionScript.uint256At(startOffset + 0x04 + (0x20 * (_paramNum - 1) )) + 0x20;
    }

    function substring(
        bytes strBytes,
        uint startIndex,
        uint endIndex
    ) internal pure returns (string)
    {
        // first char is at location 0
        //IPFS addresses span from 0 (startindex) to 46 (endIndex)
        bytes memory result = new bytes(endIndex-startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i-startIndex] = strBytes[i];
        }
        return string(result);
    }

    function _iterateExtraction(uint256 _actionId, bytes _executionScript, uint256 _currentOffset, uint256 _optionLength) internal {
        uint256 currentOffset = _currentOffset;
        address currentOption;
        string memory info;
        uint256 infoEnd;
        bytes32 externalId1;
        bytes32 externalId2;
        uint256 idOffset;
        uint256 infoStart = _goToParamOffset(OPTION_INFO_PARAM_LOC,_executionScript) + 0x20;
        //Location(infoStart);
        emit OptionQty(_optionLength);
        for (uint256 i = 0 ; i < _optionLength; i++) {
            currentOption = _executionScript.addressAt(currentOffset + 0x0C);
            emit Address(currentOption);
            //find the end of the infoString using the relative arg positions
            infoEnd = infoStart + _executionScript.uint256At(currentOffset + (0x20 * 2 * (_optionLength + 1) ));
            info = substring(_executionScript, infoStart, infoEnd);
            //Metadata(info);
            //Location(infoEnd);
            currentOffset = currentOffset + 0x20;
            // update the index for the next iteration
            infoStart = infoEnd;
            // store option external IDs
            idOffset = _goToParamOffset(EX_ID1_PARAM_LOC, _executionScript) + 0x20 * (i + 1);
            externalId1 = bytes32(_executionScript.uint256At(idOffset));
            idOffset = _goToParamOffset(EX_ID2_PARAM_LOC, _executionScript) + 0x20 * (i + 1);
            externalId2 = bytes32(_executionScript.uint256At(idOffset));

            addOption(_actionId, info, currentOption, externalId1, externalId2);
        }
    }

    /**
    * @dev This function needs to work with strings instead of addresses but it doesn't
    *      This fits our current use case better and string manipulation is harder
    *      since there's more like... dynamic-ness.
            //TODO Update the above dev info
    */
    function _extractOptions(bytes _executionScript, uint256 _actionId) internal returns(uint256 currentOffset, uint256 calldataLength) {
        Action storage actionInstance = actions[_actionId];
        // in order to find out the total length of our call data we take the 3rd
        // relevent byte chunk (after the specid and the target address)
        calldataLength = uint256(_executionScript.uint32At(0x4 + 0x14));
        // Since the calldataLength is 4 bytes the start offset is
        uint256 startOffset = 0x04 + 0x14 + 0x04;
        // The first parameter is located at a byte depth indicated by the first
        // word in the calldata (which is located at the startOffset + 0x04 for the function signature)
        // so we have:
        // start offset (spec id + address + calldataLength) + param offset + function signature
        // note:function signature length (0x04) added in both contexts: grabbing the offset value and the outer offset calculation
        uint256 firstParamOffset = _goToParamOffset(OPTION_ADDR_PARAM_LOC, _executionScript);
        uint256 fifthParamOffset = _goToParamOffset(DESCRIPTION_PARAM_LOC, _executionScript);
        currentOffset = firstParamOffset;
        // compute end of script / next location and ensure there's no
        // shenanigans
        require(startOffset + calldataLength == _executionScript.length); // solium-disable-line error-reason
        // The first word in the param slot is the length of the array
        // obtain the beginning index of the infoString
        uint256 optionLength = _executionScript.uint256At(currentOffset);
        currentOffset = currentOffset + 0x20;
        // This has the potential to be too gas expensive to ever happen.
        // Upper limit of options should be checked against this function
        _iterateExtraction(_actionId, _executionScript, currentOffset, optionLength);
        uint256 descriptionStart = fifthParamOffset + 0x20;
        uint256 descriptionEnd = descriptionStart + (_executionScript.uint256At(fifthParamOffset));
        actionInstance.description = substring(_executionScript, descriptionStart, descriptionEnd);
        // Skip the next param since it's also determined by this contract
        // In order to do this we move the offset one word for the length of the param
        // and we move the offset one word for each param.
        //currentOffset = currentOffset.add(_executionScript.uint256At(currentOffset).mul(0x20));
        currentOffset = fifthParamOffset;
        // The offset represents the data we've already accounted for; the rest is what will later
        // need to be copied over.
        calldataLength = calldataLength.sub(currentOffset);
    }

    function addAddressesAndActions(
        uint256 _actionId,
        bytes script,
        uint256 numberOfOptions,
        uint256 dynamicOffset
        ) internal view returns(uint256 offset)
        {
                // Set the initial offest after the static parameters
        offset = 64 + dynamicOffset;

        assembly { // solium-disable-line security/no-inline-assembly
            mstore(add(script, offset), numberOfOptions)
        }

        offset += 32;

        // Copy all option addresses
        for (uint256 i = 0; i < numberOfOptions; i++) {
            bytes32 canKey = actions[_actionId].optionKeys[i];
            uint256 optionData = uint256(optionAddresses[canKey]);
            assembly {
                mstore(add(script, offset), optionData)
            }
            offset += 32;
        }

        assembly { // solium-disable-line security/no-inline-assembly
            mstore(add(script, offset), numberOfOptions)
        }

        offset += 32;

        // Copy all support data
        for (i = 0; i < numberOfOptions; i++) {
            uint256 supportsData = actions[_actionId].options[actions[_actionId].optionKeys[i]].actionSupport;

            assembly { // solium-disable-line security/no-inline-assembly
                mstore(add(script, offset), supportsData)
            }
            offset += 32;
        }
        return offset;
    }

    function addInfoString(
        uint256 _actionId,
        bytes script,
        uint256 numberOfOptions,
        uint256 _offset)
        internal view returns (uint256 newOffset)
    {
        Action storage actionInstance = actions[_actionId];
        uint256 infoStringLength = actionInstance.infoStringLength;
        bytes memory infoString = new bytes(infoStringLength);
        bytes memory optionMetaData;
        uint256 metaDataLength;
        uint256 strOffset = 0;
        newOffset = _offset;
        // Add number of options for array size of "infoIndicies"
        assembly { // solium-disable-line security/no-inline-assembly
            mstore(add(script, newOffset), numberOfOptions)
        }
        // Offset "infoIndicies" size
        newOffset += 32;

        for (uint256 i = 0; i < numberOfOptions; i++) {
            bytes32 canKey = actionInstance.optionKeys[i];
            optionMetaData = bytes(actionInstance.options[canKey].metadata);
            infoString.copy(optionMetaData.getPtr() + 32, strOffset, optionMetaData.length);
            strOffset += optionMetaData.length;
            metaDataLength = optionMetaData.length;

            assembly { // solium-disable-line security/no-inline-assembly
                mstore(add(script, newOffset), metaDataLength)
            }

            newOffset += 32;
        }

        assembly { // solium-disable-line security/no-inline-assembly
                mstore(add(script, newOffset), infoStringLength)
        }


        script.copy(infoString.getPtr() + 32, newOffset, infoStringLength);

        newOffset += (infoStringLength / 32) * 32 + (infoStringLength % 32 == 0 ? 0 : 32);
    }

    function addExternalIds(
        uint256 _actionId,
        bytes script,
        uint256 numberOfOptions,
        uint256 _offset
        ) internal view returns(uint256 offset)
        {
        offset = _offset;
        assembly { // solium-disable-line security/no-inline-assembly
            mstore(add(script, offset), numberOfOptions)
        }

        offset += 32;

        // Copy all option addresses
        for (uint256 i = 0; i < numberOfOptions; i++) {
            //bytes32 canKey = actions[_actionId].optionKeys[i];
            bytes32 externalId1 = actions[_actionId].options[actions[_actionId].optionKeys[i]].externalId1;
            assembly {
                mstore(add(script, offset), externalId1)
            }
            offset += 32;

        }

        assembly { // solium-disable-line security/no-inline-assembly
            mstore(add(script, offset), numberOfOptions)
        }

        offset += 32;

        // Copy all support data
        for (i = 0; i < numberOfOptions; i++) {
            bytes32 externalId2 = actions[_actionId].options[actions[_actionId].optionKeys[i]].externalId2;

            assembly { // solium-disable-line security/no-inline-assembly
                mstore(add(script, offset), externalId2)
            }
            offset += 32;

        }
        return offset;
    }

    function memcpyshort(uint _dest, uint _src, uint _len) internal pure {
        uint256 src = _src;
        uint256 dest = _dest;
        uint256 len = _len;

        // this line is unnecessary since the _len passed in is hard-coded
        //require(_len < 32, "_len should be less than 32");
        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly { // solium-disable-line security/no-inline-assembly
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    function encodeInput(uint256 actionId) internal returns(bytes) {

    }

    function parseScript(uint256 actionId) internal returns(bytes) {

    }

    function getPtr(bytes memory _x) internal pure returns (uint256 ptr) {
        assembly {
            ptr := _x
        }
    }
}
