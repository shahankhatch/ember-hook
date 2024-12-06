// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IVolatilityContract} from "./interfaces/IVolatilityContract.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Pool} from "v4-core/libraries/Pool.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapMath} from "v4-core/libraries/SwapMath.sol";
import {LiquidityMath} from "v4-core/libraries/LiquidityMath.sol";
import {UnsafeMath} from "v4-core/libraries/UnsafeMath.sol";
import {FixedPoint128} from "v4-core/libraries/FixedPoint128.sol";
import {ProtocolFeeLibrary} from "v4-core/libraries/ProtocolFeeLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Slot0} from "v4-core/types/Slot0.sol";
import {TickBitmap} from "v4-core/libraries/TickBitmap.sol";
import {BitMath} from "v4-core/libraries/BitMath.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {StateView} from "v4-periphery/src/lens/StateView.sol";
// import {console} from "forge-std/console.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {IHooks} from "lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

contract VolatilityFeesHook is BaseHook {
    // using SafeCast for *;
    using SafeCast for uint256;
    // using SafeCast for int128;
    // using LPFeeLibrary for uint24;
    // using PoolIdLibrary for PoolKey;
    // using StateLibrary for IPoolManager;
    // using BalanceDeltaLibrary for BalanceDelta;
    // using ProtocolFeeLibrary for *;

    uint24 public constant HIGH_VOLATILITY_FEE = 1000; // 1%
    uint24 public constant MEDIUM_VOLATILITY_FEE = 300; // 0.3%
    uint24 public constant LOW_VOLATILITY_FEE = 50; // 0.05%

    uint128 public constant TOTAL_BIPS = 10000;

    error MustUseDynamicFee();

    // address public immutable volatilityContractAddress;
    IVolatilityContract public volatilityContract;

    // Initialize BaseHook parent contract in the constructor
    constructor(
        IPoolManager _poolManager,
        address volatility_contract_address
    ) BaseHook(_poolManager) {
        // volatilityContractAddress = volatility_contract_address;
        volatilityContract = IVolatilityContract(volatility_contract_address);
        volatilityContract.setVolatility(1);
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
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: true,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    event Mark(uint256 id);

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata /* hookData */
    ) external override onlyPoolManager returns (bytes4, int128) {
        // get current volatility
        volatilityContract.setVolatility(
            volatilityContract.getVolatility() + 1
        );

        uint256 feeChoice = LOW_VOLATILITY_FEE;
        uint256 currentVolatility = volatilityContract.getVolatility();

        if (currentVolatility > 6) {
            feeChoice = HIGH_VOLATILITY_FEE;
        } else if (currentVolatility >= 3 && currentVolatility <= 6) {
            feeChoice = MEDIUM_VOLATILITY_FEE;
        }

        // // fee will be in the unspecified token of the swap
        bool specifiedTokenIs0 = (params.amountSpecified < 0 ==
            params.zeroForOne);
        (Currency feeCurrency, int128 swapAmount) = (specifiedTokenIs0)
            ? (key.currency1, delta.amount1())
            : (key.currency0, delta.amount0());
        // if fee is on output, get the absolute output amount
        if (swapAmount < 0) swapAmount = -swapAmount;

        uint256 feeAmount = (uint128(swapAmount) * feeChoice) / TOTAL_BIPS;

        bool enableFee = false;
        if (enableFee) {
            poolManager.take(feeCurrency, address(this), feeAmount);
            return (IHooks.afterSwap.selector, feeAmount.toInt128());
        } else {
            return (IHooks.afterSwap.selector, 0);
        }
    }
}
