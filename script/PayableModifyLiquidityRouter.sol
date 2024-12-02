// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolModifyLiquidityTest} from "lib/v4-periphery/lib/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract PayableModifyLiquidityRouter is PoolModifyLiquidityTest {
    constructor(IPoolManager _manager) PoolModifyLiquidityTest(_manager) {}

    // Allow the contract to accept Ether via plain transfer
    receive() external payable {
        // Optionally handle the Ether received here
    }

    // Fallback function to accept Ether with data or other unexpected calls
    fallback() external payable {
        // Optionally handle the Ether received here
    }
}
