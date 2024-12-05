pragma solidity ^0.8.26;

import {HookMiner} from "../../script/HookMiner.sol";

contract HM {
    using HookMiner for HM;

    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) public view returns (address, bytes32) {
        return HookMiner.find(deployer, flags, creationCode, constructorArgs);
    }

    function computeAddress(
        address deployer,
        uint256 salt,
        bytes memory creationCode
    ) public pure returns (address hookAddress) {
        return HookMiner.computeAddress(deployer, salt, creationCode);
    }
}
