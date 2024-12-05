// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {BitMath} from "v4-core/libraries/BitMath.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {StateView} from "v4-periphery/src/lens/StateView.sol";
import {console} from "forge-std/console.sol";

contract VolatilityFeesHook is BaseHook {
    using SafeCast for *;
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using BalanceDeltaLibrary for BalanceDelta;
    // using ProtocolFeeLibrary for *;

    uint24 public constant HIGH_VOLATILITY_FEE = 10000; // 1%
    uint24 public constant MEDIUM_VOLATILITY_FEE = 3000; // 0.3%
    uint24 public constant LOW_VOLATILITY_FEE = 500; // 0.05%

    // The default base fees we will charge
    uint24 public constant BASE_FEE = 5000; // 0.5%

    error MustUseDynamicFee();

    IVolatilityContract volatilityContract;

    // Initialize BaseHook parent contract in the constructor
    constructor(
        IPoolManager _poolManager,
        address volatility_contract_address
    ) BaseHook(_poolManager) {
        volatilityContract = IVolatilityContract(volatility_contract_address);
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
        // bool immediate = parseHookData(hookData);
        // console.log("booo");
        // revert("Here we are");
        // poolManager.getSlot0(key.toId());
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function parseHookData(
        bytes calldata data
    ) public pure returns (bool immediate) {
        return abi.decode(data, (bool));
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams memory params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        // user needs to provide volatility calculator address, bool for payImmediately and bool for refundImmediately
        // (address volatility_contract_address, bool payImmediately, bool refundImmediately) = parseHookData(hookData);

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
}
