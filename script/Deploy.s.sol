// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Quoter} from "../src/quoter/Quoter.sol";
import {VolatilityFeesHook} from "../src/VolatilityFeesHook.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
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
import {PayableModifyLiquidityRouter} from "./PayableModifyLiquidityRouter.sol";

// forge script script/Deploy.s.sol --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 --rpc-url http://127.0.0.1:8547 --force --broadcast --skip-simulation -vvvvv

import {HookMiner} from "./HookMiner.sol";

contract Deploy is Script, Deployers {
    using CurrencyLibrary for address;
    using LPFeeLibrary for uint24;

    function run() public {
        vm.setEnv(
            "PRIVATE_KEY",
            "0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659"
        );
        uint256 deployerPrivateKey1 = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey1);

        (bool success1, ) = payable(address(this)).call{value: 20 ether}("");
        require(success1, "Transfer1 to this failed.");

        // transfer eth to 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 using non-vm ethereum transaction
        address payable account0 = payable(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        );
        (bool success2, ) = account0.call{value: 20 ether}("");
        require(success2, "Transfer2 to account0 failed.");

        vm.stopBroadcast();

        vm.setEnv(
            "PRIVATE_KEY",
            "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        );
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        manager = new PoolManager(account0);
        swapRouter = new PoolSwapTest(manager);

        MockERC20 token0 = new MockERC20("Token0", "TK0", 18);
        MockERC20 token1 = new MockERC20("Token1", "TK1", 18);
        token0.mint(account0, 1e50 ether);
        token1.mint(account0, 1e50 ether);
        (currency0, currency1) = SortTokens.sort(token0, token1);

        Quoter quoter = new Quoter(address(manager));
        address volatilityCalculator = 0xA6E41fFD769491a42A6e5Ce453259b93983a22EF; // Replace with real or deploy a mock

        Create2Deployer create2Deployer = new Create2Deployer();

        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(create2Deployer),
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG,
            type(VolatilityFeesHook).creationCode,
            abi.encode(manager, volatilityCalculator, address(quoter))
        );
        console.log("Hook address: ", hookAddress);
        console.logBytes32(salt);

        bytes memory codeHashWithConstructorArgs = abi.encodePacked(
            type(VolatilityFeesHook).creationCode,
            abi.encode(manager, volatilityCalculator, address(quoter))
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
        PoolKey memory _key = PoolKey(
            currency0,
            currency1,
            fee,
            fee.isDynamicFee() ? int24(60) : int24((fee / 100) * 2),
            hook
        );
        PoolId id = _key.toId();
        manager.initialize(_key, sqrtPriceX96);

        modifyLiquidityRouter = new PoolModifyLiquidityTest(manager);

        token0.approve(address(modifyLiquidityRouter), 1000 ether);
        token1.approve(address(modifyLiquidityRouter), 1000 ether);
        token0.approve(address(swapRouter), 1000 ether);
        token1.approve(address(swapRouter), 1000 ether);

        seedMoreLiquidity(_key, 10 ether, 10 ether);
        // modifyLiquidityRouter.modifyLiquidity(
        //     _key,
        //     LIQUIDITY_PARAMS,
        //     ZERO_BYTES
        // );

        console.log("Currency0: ", Currency.unwrap(currency0));
        console.log("Currency1: ", Currency.unwrap(currency1));

        console.log("PoolManager deployed at:", address(manager));
        console.log("Deployed fresh manager and routers");
        console.log("Quoter deployed at:", address(quoter));
        console.log("Volatility Calculator at:", volatilityCalculator);
        console.log("VolatilityFeesHook deployed at:", hookAddress);
        console.log("Pool initialized");

        bool zeroForOne = true;
        swap(_key, zeroForOne, 1, ZERO_BYTES);

        vm.stopBroadcast();
    }
}
