pragma solidity ^0.8.26;

import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolId} from "lib/v4-periphery/lib/v4-core/src/types/PoolId.sol";
import {PoolKey} from "lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "lib/v4-periphery/lib/v4-core/src/types/PoolId.sol";
import {LiquidityAmounts} from "lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import {Constants} from "lib/v4-periphery/lib/v4-core/test/utils/Constants.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";

contract EmberPoolManager {
    using TickMath for int24;
    using StateLibrary for PoolManager;
    using PoolIdLibrary for PoolKey;
    using LiquidityAmounts for PoolManager;

    // Helpful test constants
    bytes constant ZERO_BYTES = Constants.ZERO_BYTES;
    uint160 constant SQRT_PRICE_1_1 = Constants.SQRT_PRICE_1_1;
    uint160 constant SQRT_PRICE_1_2 = Constants.SQRT_PRICE_1_2;
    uint160 constant SQRT_PRICE_2_1 = Constants.SQRT_PRICE_2_1;
    uint160 constant SQRT_PRICE_1_4 = Constants.SQRT_PRICE_1_4;
    uint160 constant SQRT_PRICE_4_1 = Constants.SQRT_PRICE_4_1;

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

    IPoolManager.ModifyLiquidityParams public LIQUIDITY_PARAMS =
        IPoolManager.ModifyLiquidityParams({
            tickLower: -120,
            tickUpper: 120,
            liquidityDelta: 1e18,
            salt: 0
        });
    IPoolManager.ModifyLiquidityParams public REMOVE_LIQUIDITY_PARAMS =
        IPoolManager.ModifyLiquidityParams({
            tickLower: -120,
            tickUpper: 120,
            liquidityDelta: -1e18,
            salt: 0
        });
    IPoolManager.SwapParams public SWAP_PARAMS =
        IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -100,
            sqrtPriceLimitX96: SQRT_PRICE_1_2
        });

    function getSqrtPriceAtTick(int24 tick) public pure returns (uint160) {
        return tick.getSqrtPriceAtTick();
    }

    /// @notice Helper function to increase balance of pool manager.
    /// Uses default LIQUIDITY_PARAMS range.
    function seedMoreLiquidity(
        address poolManager,
        address modifyLiquidityRouter,
        PoolKey memory _key,
        uint256 amount0,
        uint256 amount1
    ) public {
        (uint160 sqrtPriceX96, , , ) = PoolManager(poolManager).getSlot0(
            _key.toId()
        );
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(LIQUIDITY_PARAMS.tickLower),
            TickMath.getSqrtPriceAtTick(LIQUIDITY_PARAMS.tickUpper),
            amount0,
            amount1
        );

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager
            .ModifyLiquidityParams({
                tickLower: LIQUIDITY_PARAMS.tickLower,
                tickUpper: LIQUIDITY_PARAMS.tickUpper,
                liquidityDelta: int128(liquidityDelta),
                salt: 0
            });

        PoolModifyLiquidityTest(modifyLiquidityRouter).modifyLiquidity(
            _key,
            params,
            ZERO_BYTES
        );
    }

    function getLiquidityForAmounts(
        address poolManager,
        PoolKey calldata _key,
        // int24 tickLower,
        // int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) public view returns (uint128 liquidity) {
        (uint160 sqrtPriceX96, , , ) = PoolManager(poolManager).getSlot0(
            _key.toId()
        );
        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtPriceAtTick(LIQUIDITY_PARAMS.tickLower),
                TickMath.getSqrtPriceAtTick(LIQUIDITY_PARAMS.tickUpper),
                amount0,
                amount1
            );
    }

    function getSlot0(
        address poolManager,
        PoolKey calldata key
    )
        public
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint24 protocolFee,
            uint24 lpFee
        )
    {
        return PoolManager(poolManager).getSlot0(key.toId());
    }
}
