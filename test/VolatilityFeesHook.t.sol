// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {VolatilityFeesHook} from "../src/VolatilityFeesHook.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {console} from "forge-std/console.sol";
import {IVolatilityContract} from "../src/interfaces/IVolatilityContract.sol";
import {IQuoter} from "../src/interfaces/IQuoter.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

contract TestVolatilityFeesHook is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    VolatilityFeesHook hooks = VolatilityFeesHook(
        address(
            uint160(
                uint256(type(uint160).max) & clearAllHookPermissionsMask | Hooks.BEFORE_SWAP_FLAG
                    | Hooks.AFTER_SWAP_FLAG
            )
        )
    );
    IQuoter quoter;
    IVolatilityContract calculator;

	function setUp() public {

        deployFreshManagerAndRouters();

        VolatilityFeesHook impl = new VolatilityFeesHook(manager);
        vm.etch(address(hooks), address(impl).code);

        deployMintAndApprove2Currencies();
        (key,) = initPoolAndAddLiquidity(
            currency0, currency1, IHooks(address(hooks)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1
        );

        // do 100 swaps on the pool
        bool zero_for_one = true;
        for (uint i = 0; i < 100; i++) {
            // swap 1 currency0 for currency1
            swap(
                key,
                zero_for_one,
                1,
                ""
            );
            zero_for_one = !zero_for_one;
        }
	}

    function test_100_swaps_produces_volatility() public {

    }
}