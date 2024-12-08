// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../../lib/BrevisAppZkOnly.sol";

contract EmberBrevis is BrevisAppZkOnly, Ownable {
    event EmberLowVolatilityAttested(
        uint248 points,
        uint64 minBlockNum,
        uint64 maxBlockNum
    );

    bytes32 public vkHash;

    constructor(
        address _brevisRequest
    ) BrevisAppZkOnly(_brevisRequest) Ownable(msg.sender) {}

    function handleProofResult(
        bytes32 _vkHash,
        bytes calldata _circuitOutput
    ) internal override {
        require(vkHash == _vkHash, "invalid vk");
        (uint248 points, uint64 minBlockNum, uint64 maxBlockNum) = decodeOutput(
            _circuitOutput
        );
        emit EmberLowVolatilityAttested(points, minBlockNum, maxBlockNum);
    }

    function decodeOutput(
        bytes calldata o
    ) internal pure returns (uint248, uint64, uint64) {
        uint248 points = uint248(bytes31(o[0:31]));
        uint64 minBlockNum = uint64(bytes8(o[31:39]));
        uint64 maxBlockNum = uint64(bytes8(o[39:47]));
        return (points, minBlockNum, maxBlockNum);
    }

    function setVkHash(bytes32 _vkHash) external onlyOwner {
        vkHash = _vkHash;
    }
}
