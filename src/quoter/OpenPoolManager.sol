// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

//import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Pool} from "@uniswap/v4-core/src/libraries/Pool.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {ProtocolFees} from "@uniswap/v4-core/src/ProtocolFees.sol";
import {ProxyPoolManager} from "@uniswap/v4-core/src/test/ProxyPoolManager.sol";

contract OpenPoolManager is ProxyPoolManager {
    // using Pool for Pool.State;
    // constructor(address Po) PoolManager(initialOwner) {}
    constructor(address delegateManager) ProxyPoolManager(delegateManager) {}

    // function getPoolState(PoolId id) public view returns (Pool.State memory) {
    //     return _pools[id];
    // }

    // function getPoolBitmap(PoolId id) public view returns (mapping(int16 => uint256) memory) {
    //     return _pools[id].tickBitmap;
    // }

    // function inner_swap(PoolId id, Pool.SwapParams memory params) public view returns (BalanceDelta swapDelta, uint256 amountToProtocol, uint24 swapFee, Pool.SwapResult memory result) {
    //     return _pools[id].swap(params);
    // }
}