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


contract VolatilityFeesHook is BaseHook {
    using LPFeeLibrary for uint24;

    uint256 public constant HIGH_VOLATILITY_TRIGGER = 1400; // 14%
    uint256 public constant MEDIUM_VOLATILITY_TRIGGER = 1000; // 10%
    uint24 public constant HIGH_VOLATILITY_FEE = 10000; // 1%
    uint24 public constant MEDIUM_VOLATILITY_FEE = 3000; // 0.3%
    uint24 public constant LOW_VOLATILITY_FEE = 500; // 0.05%

    // The default base fees we will charge
    uint24 public constant BASE_FEE = 5000; // 0.5%

    error MustUseDynamicFee();

    // Initialize BaseHook parent contract in the constructor
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

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
        // user needs to provide quoter address, volatility calculator address, bool for payImmediately and bool for refundImmediately
        (address quoter_address, address volatility_contract_address, bool payImmediately, bool refundImmediately) = parseHookData(hookData);

        // get the simulated swap resultant price
        IQuoter quoter = IQuoter(quoter_address);
        uint160 sqrtPriceX96After;
        if (params.amountSpecified < 0) {
            (int128[] memory deltaAmounts, uint160 _sqrtPriceX96After, uint32 initializedTicksLoaded) = quoter.quoteExactInputSingle(IQuoter.QuoteExactSingleParams({
                poolKey: key,
                zeroForOne: params.zeroForOne,
                exactAmount: uint(-params.amountSpecified),
                hookData: "",
                recipient: address(0),
                sqrtPriceLimitX96: params.sqrtPriceLimitX96
            }));
            sqrtPriceX96After = _sqrtPriceX96After;
        } else {
            (int128[] memory deltaAmounts, uint160 _sqrtPriceX96After, uint32 initializedTicksLoaded) = quoter.quoteExactOutputSingle(IQuoter.QuoteExactSingleParams({
                poolKey: key,
                zeroForOne: params.zeroForOne,
                exactAmount: uint(params.amountSpecified),
                hookData: "",
                recipient: address(0),
                sqrtPriceLimitX96: params.sqrtPriceLimitX96
            }));
            sqrtPriceX96After = _sqrtPriceX96After;
        }
        IVolatilityContract volatilityManager = IVolatilityContract(volatility_contract_address);

        // get the current volatility
        uint256 currentVolatility = volatilityManager.lastVolatility();
        // simulate the volatility for doing the swap
        uint256 newVolatility = volatilityManager.simulateSwap(sqrtPriceX96After);

        // check user hook params: if vol is higher, either swap immediately with higher fee (true) or offload to EL (false)
        // check user hook params: if vol is lower, either refund immediately (true) or offload to Brevis (false)
        // if the new volatility is higher, increase the fee
        if (newVolatility > currentVolatility) {
            if (payImmediately) {
                // pay the fee immediately
                return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, (BASE_FEE + HIGH_VOLATILITY_FEE) | LPFeeLibrary.OVERRIDE_FEE_FLAG);
            } else {
                // offload to EL
                return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
            }
        }
        if (newVolatility < currentVolatility) {
            if (refundImmediately) {
                // refund the fee immediately
                return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, (BASE_FEE - LOW_VOLATILITY_FEE) | LPFeeLibrary.OVERRIDE_FEE_FLAG);
            } else {
                // offload to Brevis
                return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
            }
        }
    }

    function parseHookData(
        bytes calldata data
    ) public pure returns (address quoter_address, address volatility_contract_address, bool payImmediately, bool refundImmediately) {
        return abi.decode(data, (address, address, bool, bool));
    }

    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams memory params,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, int128) {
		// TODO
        return (this.afterSwap.selector, 0);
    }
}