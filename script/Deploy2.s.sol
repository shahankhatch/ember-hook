// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Quoter} from "../src/quoter/Quoter.sol";
import {VolatilityFeesHook} from "../src/VolatilityFeesHook.sol";
import {EmberERC20} from "../src/mocks/EmberERC20.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {CurrencyLibrary} from "v4-core/types/Currency.sol";
// import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {console} from "forge-std/console.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
// import {Create2} from "lib/v4-periphery/lib/permit2/lib/openzeppelin-contracts/contracts/utils/Create2.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import "./Create2Deployer.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {SortTokens} from "lib/v4-periphery/lib/v4-core/test/utils/SortTokens.sol";
import {IQuoter} from "src/interfaces/IQuoter.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IVolatilityContract} from "../src/interfaces/IVolatilityContract.sol";
import {TickMath} from "lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import {Constants} from "lib/v4-periphery/lib/v4-core/test/utils/Constants.sol";
import {LiquidityAmounts} from "lib/v4-periphery/lib/v4-core/test/utils/LiquidityAmounts.sol";
import {HM} from "../src/mocks/HM.sol";
import {EmberPoolManager} from "../src/mocks/EmberPoolManager.sol";

// forge script script/Deploy.s.sol --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 --rpc-url http://127.0.0.1:8547 --force --broadcast --skip-simulation -vvvvv

import {HookMiner} from "./HookMiner.sol";

contract DeployersBase {
    using CurrencyLibrary for address;
    using LPFeeLibrary for uint24;
    using StateLibrary for IPoolManager;

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

    Currency internal currency0;
    Currency internal currency1;

    IPoolManager manager;
    PoolSwapTest swapRouter;
    PoolModifyLiquidityTest modifyLiquidityRouter;

    function getCurrency0() public view returns (Currency) {
        return currency0;
    }

    function getCurrency1() public view returns (Currency) {
        return currency1;
    }

    function getManager() public view returns (IPoolManager) {
        return manager;
    }

    function getSwapRouter() public view returns (PoolSwapTest) {
        return swapRouter;
    }

    function getModifyLiquidityRouter()
        public
        view
        returns (PoolModifyLiquidityTest)
    {
        return modifyLiquidityRouter;
    }

    /// @notice Helper function to increase balance of pool manager.
    /// Uses default LIQUIDITY_PARAMS range.
    function seedMoreLiquidity(
        PoolKey memory _key,
        uint256 amount0,
        uint256 amount1
    ) internal {
        (uint160 sqrtPriceX96, , , ) = manager.getSlot0(_key.toId());
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

        modifyLiquidityRouter.modifyLiquidity(_key, params, ZERO_BYTES);
    }
}

contract Deploy is DeployersBase {
    using CurrencyLibrary for address;
    using LPFeeLibrary for uint24;
    using StateLibrary for IPoolManager;

    PoolId public id;

    function getSlot0()
        public
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint24 protocolFee,
            uint24 lpFee
        )
    {
        (sqrtPriceX96, tick, protocolFee, lpFee) = manager.getSlot0(id);
        console.log("sqrtPriceX96: ", sqrtPriceX96);
        console.log("tick: ", tick);
        console.log("protocolFee: ", protocolFee);
        console.log("lpFee: ", lpFee);
    }

    constructor() {
        console.log("Deploying...");
        console.log("Deployer address: ", address(this));
    }

    function sort(
        EmberERC20 tokenA,
        EmberERC20 tokenB
    ) internal pure returns (Currency _currency0, Currency _currency1) {
        if (address(tokenA) < address(tokenB)) {
            (_currency0, _currency1) = (
                Currency.wrap(address(tokenA)),
                Currency.wrap(address(tokenB))
            );
        } else {
            (_currency0, _currency1) = (
                Currency.wrap(address(tokenB)),
                Currency.wrap(address(tokenA))
            );
        }
    }

    function run() public {
        // vm.setEnv(
        //     "PRIVATE_KEY",
        //     "0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659"
        // );
        // uint256 deployerPrivateKey1 = vm.envUint("PRIVATE_KEY");
        // vm.startBroadcast(deployerPrivateKey1);

        // (bool success1, ) = payable(address(this)).call{value: 20 ether}("");
        // require(success1, "Transfer1 to this failed.");

        // // transfer eth to 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 using non-vm ethereum transaction
        address payable account0 = payable(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        );
        // (bool success2, ) = account0.call{value: 20 ether}("");
        // require(success2, "Transfer2 to account0 failed.");

        // vm.stopBroadcast();

        // vm.setEnv(
        //     "PRIVATE_KEY",
        //     "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 "
        // );
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // vm.startBroadcast(deployerPrivateKey);

        manager = new PoolManager(account0);
        swapRouter = new PoolSwapTest(manager);

        EmberERC20 token0 = new EmberERC20("Token0", "TK0", 18);
        EmberERC20 token1 = new EmberERC20("Token1", "TK1", 18);
        token0.mint(account0, 1e50 ether);
        token1.mint(account0, 1e50 ether);
        (currency0, currency1) = sort(token0, token1);

        Quoter quoter = new Quoter(address(manager));
        address volatilityCalculator = 0xA6E41fFD769491a42A6e5Ce453259b93983a22EF;

        Create2Deployer create2Deployer = new Create2Deployer();

        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(create2Deployer),
            Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG,
            type(VolatilityFeesHook).creationCode,
            abi.encode(manager, volatilityCalculator)
        );
        console.log("Hook address: ", hookAddress);
        console.logBytes32(salt);

        bytes memory codeHashWithConstructorArgs = abi.encodePacked(
            type(VolatilityFeesHook).creationCode,
            abi.encode(manager, volatilityCalculator)
        );

        create2Deployer.deploy(0, salt, codeHashWithConstructorArgs);

        // address hookAddress = address(
        //     uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG)
        // );
        VolatilityFeesHook hook = VolatilityFeesHook(hookAddress);
        // VolatilityFeesHook vhook = new VolatilityFeesHook(
        //     manager,
        //     volatilityCalculator,
        //     address(quoter)
        // );
        // vm.etch(hookAddress, address(hook).code); // Use the hook address for compatibility

        uint160 sqrtPriceX96 = 79228162514264337593543950336; // Example price (1:1)
        uint24 fee = 500;
        PoolKey memory _key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: fee.isDynamicFee()
                ? int24(60)
                : int24((fee / 100) * 2),
            hooks: hook
        });
        // console.log("PoolKey:", _key);
        id = _key.toId();
        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(id));
        manager.initialize(_key, sqrtPriceX96);

        modifyLiquidityRouter = new PoolModifyLiquidityTest(manager);

        token0.approve(address(modifyLiquidityRouter), 1000 ether);
        token1.approve(address(modifyLiquidityRouter), 1000 ether);
        token0.approve(address(swapRouter), 1000 ether);
        token1.approve(address(swapRouter), 1000 ether);
        token0.approve(address(quoter), 1000 ether);
        token1.approve(address(quoter), 1000 ether);

        seedMoreLiquidity(_key, 10 ether, 10 ether);
        // modifyLiquidityRouter.modifyLiquidity(
        //     _key,
        //     LIQUIDITY_PARAMS,
        //     ZERO_BYTES
        // );
        // StateLibrary stateLibrary = new StateLibrary();

        // console.log("StateLibrary deployed at:", address(stateLibrary));

        console.log("Currency0: ", Currency.unwrap(currency0));
        console.log("Currency1: ", Currency.unwrap(currency1));

        console.log("PoolManager deployed at:", address(manager));
        // console.log(
        //     "StateLibrary deployed at:",
        //     address(manager.stateLibrary())
        // );
        console.log("Deployed fresh manager and routers");
        console.log("Quoter deployed at:", address(quoter));
        console.log("Volatility Calculator at:", volatilityCalculator);
        console.log("VolatilityFeesHook deployed at:", hookAddress);
        console.log("Pool initialized");

        bool zeroForOne = true;

        IQuoter.QuoteExactSingleParams memory p = IQuoter
            .QuoteExactSingleParams({
                poolKey: _key,
                zeroForOne: zeroForOne,
                recipient: address(this),
                exactAmount: 1,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT,
                hookData: ZERO_BYTES
            });
        try quoter.quoteExactInputSingle(p) returns (
            int128[] memory deltaAmounts,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksLoaded
        ) {
            console.log("quote Success");
            console.log(deltaAmounts[0]);
            console.log(deltaAmounts[1]);
            console.log(sqrtPriceX96After);
            console.log(initializedTicksLoaded);
        } catch {
            console.log("quote Failed");
        }
        // // do 100 swaps on the pool
        // for (uint256 i = 0; i < 120; i++) {
        //     swap(_key, zeroForOne, 1, ZERO_BYTES);
        //     (
        //         uint160 sqrtPriceX96last,
        //         int24 tick,
        //         uint24 protocolFee,
        //         uint24 lpFee
        //     ) = manager.getSlot0(id);
        //     console.log("sqrtPriceX96: ", i, ":", sqrtPriceX96last);
        //     u.index();
        //     // uint256 volatility = u.calculateVolatility();
        //     // console.log("Volatility: ", i, ":", volatility);
        // }

        // swap(_key, zeroForOne, 1, ZERO_BYTES);

        // vm.stopBroadcast();
    }
}
