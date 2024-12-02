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
import {Quoter} from "../src/quoter/Quoter.sol";

// import {console} from "forge-std/console.sol";

contract TestVolatilityFeesHook is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    VolatilityFeesHook hook;

    IQuoter quoter;
    IVolatilityContract calculator;

    address deployed_volatility_contract_address =
        address(0xA6E41fFD769491a42A6e5Ce453259b93983a22EF);

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        address hook_address = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG)
        );

        quoter = new Quoter(address(manager));
        calculator = IVolatilityContract(deployed_volatility_contract_address);

        deployCodeTo(
            "VolatilityFeesHook",
            abi.encode(manager, calculator, quoter),
            hook_address
        );
        hook = VolatilityFeesHook(hook_address);
        // VolatilityFeesHook impl = new VolatilityFeesHook(manager, address(calculator), address(quoter));
        // vm.etch(address(hooks), address(impl).code);
        console.log("index");
        calculator.init();
        console.log(calculator.index());

        (key, ) = initPoolAndAddLiquidity(
            currency0,
            currency1,
            IHooks(address(hook)),
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            SQRT_PRICE_1_1
        );
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
        console.log("hello");
    }

    function test_100_swaps_produces_volatility() public {
        console.log("beep");

        // do 100 swaps on the pool
        bool zero_for_one = true;
        swap(key, zero_for_one, 1, abi.encode());
        // for (uint i = 0; i < 100; i++) {
        //     // swap 1 currency0 for currency1
        //     swap(key, zero_for_one, 1, "");
        //     zero_for_one = !zero_for_one;
        // }
    }
}
