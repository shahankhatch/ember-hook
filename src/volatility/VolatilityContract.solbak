pragma solidity ^0.8.26;

import {IVolatilityContract} from "../interfaces/IVolatilityContract.sol";

contract VolatilityContract is IVolatilityContract {
    uint256[] public swaps;
    uint256 public index;
    uint256 public lastVolatility;

    function init() external override {
        index = 0;
        lastVolatility = 0;
    }

    function setVolatility(uint256 new_volatility) external override {
        lastVolatility = new_volatility;
    }

    function addSwap(uint256 swap) external override {
        lastVolatility += swap;
    }

    function simulateSwap(uint256 swap) external override returns (uint256) {
        return index + swap;
    }

    function sqrt(uint256 value) external view override returns (uint256) {
        uint256 z = (value + 1) / 2;
        uint256 y = value;
        while (z < y) {
            y = z;
            z = (value / z + z) / 2;
        }
        return y;
    }

    function calculateVolatility() external view override returns (uint256) {
        uint256 sum = 0;
        // for (uint256 i = 0; i < swaps.length; i++) {
        //     sum += swaps[i];
        // }
        // return sqrt(sum);
        return sum;
    }
}
