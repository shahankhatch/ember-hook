// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IVolatilityContract} from "./interfaces/IVolatilityContract.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Pool} from "v4-core/libraries/Pool.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapMath} from "v4-core/libraries/SwapMath.sol";
import {LiquidityMath} from "v4-core/libraries/LiquidityMath.sol";
import {UnsafeMath} from "v4-core/libraries/UnsafeMath.sol";
import {FixedPoint128} from "v4-core/libraries/FixedPoint128.sol";
import {ProtocolFeeLibrary} from "v4-core/libraries/ProtocolFeeLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Slot0} from "v4-core/types/Slot0.sol";
import {OpenPoolManager} from "./quoter/OpenPoolManager.sol";
import {TickBitmap} from "v4-core/libraries/TickBitmap.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {BitMath} from "v4-core/libraries/BitMath.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {StateView} from "v4-periphery/src/lens/StateView.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";

contract VolatilityFeesHook is BaseHook {
    using SafeCast for *;
    using LPFeeLibrary for uint24;
    using TransientStateLibrary for IPoolManager;
    // using StateLibrary for IPoolManager;
    using BalanceDeltaLibrary for BalanceDelta;
    using ProtocolFeeLibrary for *;
    using CustomRevert for bytes4;

    IPoolManager manager;

    uint24 public constant HIGH_VOLATILITY_FEE = 10000; // 1%
    uint24 public constant MEDIUM_VOLATILITY_FEE = 3000; // 0.3%
    uint24 public constant LOW_VOLATILITY_FEE = 500; // 0.05%

    // The default base fees we will charge
    uint24 public constant BASE_FEE = 5000; // 0.5%

    error MustUseDynamicFee();

    // Initialize BaseHook parent contract in the constructor
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        manager = IPoolManager(_poolManager);
    }

    // Required override function for BaseHook to let the PoolManager know which hooks are implemented
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams memory params,
        bytes calldata hookData
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        Pool.SwapParams memory swap_params = Pool.SwapParams({
            amountSpecified: params.amountSpecified,
            sqrtPriceLimitX96: params.sqrtPriceLimitX96,
            zeroForOne: params.zeroForOne,
            tickSpacing: key.tickSpacing,
            lpFeeOverride: key.fee
        });
        swap(key, swap_params);
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);

    }

    function parseHookData(
        bytes calldata data
    ) public pure returns (address volatility_contract_address, bool payImmediately, bool refundImmediately) {
        return abi.decode(data, (address, bool, bool));
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams memory params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        // user needs to provide volatility calculator address, bool for payImmediately and bool for refundImmediately
        (address volatility_contract_address, bool payImmediately, bool refundImmediately) = parseHookData(hookData);


        // StateView state = new StateView(manager);

        // (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = state.getSlot0(key.toId());


        // IVolatilityContract volatilityManager = IVolatilityContract(volatility_contract_address);

        // // get the current volatility
        // uint256 currentVolatility = volatilityManager.lastVolatility();

        // volatilityManager.addSwap(sqrtPriceX96);

        // int128 amount0 = BalanceDeltaLibrary.amount0(delta);
        // int128 amount1 = BalanceDeltaLibrary.amount1(delta);

        return (this.afterSwap.selector, 0);
    }

    function nextInitializedTickWithinOneWord(
        uint256 currentSlot,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        unchecked {
            int24 compressed = TickBitmap.compress(tick, tickSpacing);

            if (lte) {
                (int16 wordPos, uint8 bitPos) = TickBitmap.position(compressed);
                // all the 1s at or to the right of the current bitPos
                uint256 mask = type(uint256).max >> (uint256(type(uint8).max) - bitPos);
                uint256 masked = currentSlot & mask;
                // uint256 masked = self[wordPos] & mask;

                // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
                initialized = masked != 0;
                // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
                next = initialized
                    ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * tickSpacing
                    : (compressed - int24(uint24(bitPos))) * tickSpacing;
            } else {
                // start from the word of the next tick, since the current tick state doesn't matter
                (int16 wordPos, uint8 bitPos) = TickBitmap.position(++compressed);
                // all the 1s at or to the left of the bitPos
                uint256 mask = ~((1 << bitPos) - 1);
                uint256 masked = currentSlot & mask;
                // uint256 masked = self[wordPos] & mask;

                // if there are no initialized ticks to the left of the current tick, return leftmost in the word
                initialized = masked != 0;
                // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
                next = initialized
                    ? (compressed + int24(uint24(BitMath.leastSignificantBit(masked) - bitPos))) * tickSpacing
                    : (compressed + int24(uint24(type(uint8).max - bitPos))) * tickSpacing;
            }
        }
    }

    function swap(PoolKey calldata key, Pool.SwapParams memory params)
        internal view
        returns (BalanceDelta swapDelta, uint256 amountToProtocol, uint24 swapFee, Pool.SwapResult memory result)
    {
        StateView state = new StateView(manager);
        (uint160 sqrtPriceX961, int24 tick1, uint24 protocolFee1, uint24 lpFee1) = state.getSlot0(key.toId());

        Slot0 slot0Start;
        slot0Start.setSqrtPriceX96(sqrtPriceX961).setTick(tick1).setProtocolFee(protocolFee1).setLpFee(lpFee1);

        (uint256 feeGrowthGlobal0, uint256 feeGrowthGlobal1) = state.getFeeGrowthGlobals(key.toId());

        // OpenPoolManager omanager = OpenPoolManager(manager);
        // Pool.State memory s = omanager.getPoolState(key.toId());

        (int16 wordPos, uint8 bitPos) = TickBitmap.position(tick1 / key.tickSpacing);
        uint256 tickBitmap = state.getTickBitmap(key.toId(), wordPos);

        // Pool.State memory self;
        uint128 self_liquidity = state.getLiquidity(key.toId());
        uint256 self_feeGrowthGlobal0X128 = feeGrowthGlobal0;
        uint256 self_feeGrowthGlobal1X128 = feeGrowthGlobal1;

        bool zeroForOne = params.zeroForOne;

        uint256 protocolFee =
            zeroForOne ? slot0Start.protocolFee().getZeroForOneFee() : slot0Start.protocolFee().getOneForZeroFee();

        // the amount remaining to be swapped in/out of the input/output asset. initially set to the amountSpecified
        int256 amountSpecifiedRemaining = params.amountSpecified;
        // the amount swapped out/in of the output/input asset. initially set to 0
        int256 amountCalculated = 0;
        // initialize to the current sqrt(price)
        result.sqrtPriceX96 = slot0Start.sqrtPriceX96();
        // initialize to the current tick
        result.tick = slot0Start.tick();
        // initialize to the current liquidity
        result.liquidity = self_liquidity;

        // if the beforeSwap hook returned a valid fee override, use that as the LP fee, otherwise load from storage
        // lpFee, swapFee, and protocolFee are all in pips
        {
            uint24 lpFee = params.lpFeeOverride.isOverride()
                ? params.lpFeeOverride.removeOverrideFlagAndValidate()
                : slot0Start.lpFee();

            swapFee = protocolFee == 0 ? lpFee : uint16(protocolFee).calculateSwapFee(lpFee);
        }

        // a swap fee totaling MAX_SWAP_FEE (100%) makes exact output swaps impossible since the input is entirely consumed by the fee
        if (swapFee >= SwapMath.MAX_SWAP_FEE) {
            // if exactOutput
            if (params.amountSpecified > 0) {
                // Pool.InvalidFeeForExactOut.selector.revertWith();
                return (BalanceDeltaLibrary.ZERO_DELTA, 0, swapFee, result);
            }
        }

        // swapFee is the pool's fee in pips (LP fee + protocol fee)
        // when the amount swapped is 0, there is no protocolFee applied and the fee amount paid to the protocol is set to 0
        if (params.amountSpecified == 0) return (BalanceDeltaLibrary.ZERO_DELTA, 0, swapFee, result);

        if (zeroForOne) {
            if (params.sqrtPriceLimitX96 >= slot0Start.sqrtPriceX96()) {
                Pool.PriceLimitAlreadyExceeded.selector.revertWith(slot0Start.sqrtPriceX96(), params.sqrtPriceLimitX96);
            }
            // Swaps can never occur at MIN_TICK, only at MIN_TICK + 1, except at initialization of a pool
            // Under certain circumstances outlined below, the tick will preemptively reach MIN_TICK without swapping there
            if (params.sqrtPriceLimitX96 <= TickMath.MIN_SQRT_PRICE) {
                Pool.PriceLimitOutOfBounds.selector.revertWith(params.sqrtPriceLimitX96);
            }
        } else {
            if (params.sqrtPriceLimitX96 <= slot0Start.sqrtPriceX96()) {
                Pool.PriceLimitAlreadyExceeded.selector.revertWith(slot0Start.sqrtPriceX96(), params.sqrtPriceLimitX96);
            }
            if (params.sqrtPriceLimitX96 >= TickMath.MAX_SQRT_PRICE) {
                Pool.PriceLimitOutOfBounds.selector.revertWith(params.sqrtPriceLimitX96);
            }
        }

        Pool.StepComputations memory step;
        step.feeGrowthGlobalX128 = zeroForOne ? self_feeGrowthGlobal0X128 : self_feeGrowthGlobal1X128;

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (!(amountSpecifiedRemaining == 0 || result.sqrtPriceX96 == params.sqrtPriceLimitX96)) {
            step.sqrtPriceStartX96 = result.sqrtPriceX96;

            (int16 wordPos2, uint8 bitPos2) = TickBitmap.position(result.tick / params.tickSpacing);
            uint256 tickBitmap2 = state.getTickBitmap(key.toId(), wordPos2);

            (step.tickNext, step.initialized) =
                nextInitializedTickWithinOneWord(tickBitmap2, result.tick, params.tickSpacing, zeroForOne);


            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (step.tickNext <= TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            }
            if (step.tickNext >= TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            // get the price for the next tick
            step.sqrtPriceNextX96 = TickMath.getSqrtPriceAtTick(step.tickNext);

            // compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
            (result.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                result.sqrtPriceX96,
                SwapMath.getSqrtPriceTarget(zeroForOne, step.sqrtPriceNextX96, params.sqrtPriceLimitX96),
                result.liquidity,
                amountSpecifiedRemaining,
                swapFee
            );

            // if exactOutput
            if (params.amountSpecified > 0) {
                unchecked {
                    amountSpecifiedRemaining -= step.amountOut.toInt256();
                }
                amountCalculated -= (step.amountIn + step.feeAmount).toInt256();
            } else {
                // safe because we test that amountSpecified > amountIn + feeAmount in SwapMath
                unchecked {
                    amountSpecifiedRemaining += (step.amountIn + step.feeAmount).toInt256();
                }
                amountCalculated += step.amountOut.toInt256();
            }

            // if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
            if (protocolFee > 0) {
                unchecked {
                    // step.amountIn does not include the swap fee, as it's already been taken from it,
                    // so add it back to get the total amountIn and use that to calculate the amount of fees owed to the protocol
                    // cannot overflow due to limits on the size of protocolFee and params.amountSpecified
                    // this rounds down to favor LPs over the protocol
                    uint256 delta = (swapFee == protocolFee)
                        ? step.feeAmount // lp fee is 0, so the entire fee is owed to the protocol instead
                        : (step.amountIn + step.feeAmount) * protocolFee / ProtocolFeeLibrary.PIPS_DENOMINATOR;
                    // subtract it from the total fee and add it to the protocol fee
                    step.feeAmount -= delta;
                    amountToProtocol += delta;
                }
            }

            // update global fee tracker
            if (result.liquidity > 0) {
                unchecked {
                    // FullMath.mulDiv isn't needed as the numerator can't overflow uint256 since tokens have a max supply of type(uint128).max
                    step.feeGrowthGlobalX128 +=
                        UnsafeMath.simpleMulDiv(step.feeAmount, FixedPoint128.Q128, result.liquidity);
                }
            }

            // Shift tick if we reached the next price, and preemptively decrement for zeroForOne swaps to tickNext - 1.
            // If the swap doesn't continue (if amountRemaining == 0 or sqrtPriceLimit is met), slot0.tick will be 1 less
            // than getTickAtSqrtPrice(slot0.sqrtPrice). This doesn't affect swaps, but donation calls should verify both
            // price and tick to reward the correct LPs.
            if (result.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // if the tick is initialized, run the tick transition
                if (step.initialized) {
                    (uint128 liquidityGross, int128 liquidityNet) = state.getTickLiquidity(key.toId(), step.tickNext);
                        // crossTick(key, step.tickNext, feeGrowthGlobal0X128, feeGrowthGlobal1X128);
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    unchecked {
                        if (zeroForOne) liquidityNet = -liquidityNet;
                    }

                    result.liquidity = LiquidityMath.addDelta(result.liquidity, liquidityNet);
                }

                unchecked {
                    result.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
                }
            } else if (result.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
                result.tick = TickMath.getTickAtSqrtPrice(result.sqrtPriceX96);
            }
        }

        unchecked {
            // "if currency1 is specified"
            if (zeroForOne != (params.amountSpecified < 0)) {
                swapDelta = toBalanceDelta(
                    amountCalculated.toInt128(), (params.amountSpecified - amountSpecifiedRemaining).toInt128()
                );
            } else {
                swapDelta = toBalanceDelta(
                    (params.amountSpecified - amountSpecifiedRemaining).toInt128(), amountCalculated.toInt128()
                );
            }
        }
    }
}