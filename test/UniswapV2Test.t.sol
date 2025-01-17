// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {UniswapBaseTest} from "./UniswapBaseTest.t.sol";
import {
    DAI,
    WETH,
    MKR,
    UNISWAP_V2_ROUTER_02,
    UNISWAP_V2_FACTORY,
    UNISWAP_V2_PAIR_DAI_WETH,
    SUSHISWAP_V2_ROUTER_02,
    UNISWAP_V2_PAIR_DAI_MKR,
    SUSHISWAP_V2_PAIR_DAI_WETH
} from "../../src/Constants/Constants.sol";
import {UniswapV2FlashSwap} from "../src/UniswapV2/UniswapV2FlashSwap.sol";
import {MockERC20} from "../lib/forge-std/src/mocks/MockERC20.sol";
import {IUniswapV2Pair} from "../src/Interfaces/UniswapV2/IUniswapV2Pair.sol";
import {console2} from "forge-std/Test.sol";
import {UniswapV2Arb1} from "../src/UniswapV2/UniswapV2Arb.sol";
import {UniswapV2Arb2} from "../src/UniswapV2/UniswapV2Arb2.sol";

contract UniswapV2Test is UniswapBaseTest {
    UniswapV2Arb1 arb;
    UniswapV2Arb2 arb2;

    function setUp() public override {
        super.setUp();
        arb = new UniswapV2Arb1();
        arb2 = new UniswapV2Arb2();
        deal(address(this), 100 * 1e18);

        weth.deposit{value: 100 * 1e18}();
        weth.approve(address(router), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;

        router.swapExactTokensForTokens({
            amountIn: 100 * 1e18,
            amountOutMin: 1,
            path: path,
            to: user,
            deadline: block.timestamp
        });

        vm.prank(user);
        dai.approve(address(arb), type(uint256).max);
    }

    function test_getAmountsOut() public view {
        uint256 amountIn = 1;
        uint256[] memory amounts = router.getAmountsOut(amountIn, wethDaiMkr_path);

        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
        /*
        Logs:
        WETH 1
        DAI 3,470
        MKR 2
        */
    }

    function test_getAmountsIn() public view {
        uint256 amountOut = 2;
        uint256[] memory amounts = router.getAmountsIn(amountOut, wethDaiMkr_path);

        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);

        /*  WETH; 1
            DAI; 3,248
            MKR; 2
        */
    }

    function test_swapTokensForExactTokens() public {
        uint256 amountOut = 2;
        uint256 amountInMax = 2;
        dealTokens(WETH, user, 2 ether);

        vm.startPrank(user);
        weth.approve(address(router), amountInMax);

        uint256[] memory amounts =
            router.swapTokensForExactTokens(amountOut, amountInMax, wethDaiMkr_path, user, block.timestamp);

        vm.stopPrank();

        assert(amounts[2] <= amountInMax);
    }

    function test_swapExactTokensForTokens() public {
        dealTokens(WETH, user, 5 ether);
        vm.startPrank(user);
        weth.approve(address(router), 5 ether);

        uint256[] memory amounts = router.swapExactTokensForTokens({
            amountIn: 2 ether,
            amountOutMin: 2,
            path: wethDaiMkr_path,
            to: user,
            deadline: block.timestamp
        });

        vm.stopPrank();

        assert(amounts[2] >= 2);
    }

    function test_createPair() public {
        MockERC20 token = new MockERC20();
        token.initialize("MSTOKEN", "MST", 18);

        address pairAddress = factory.createPair(address(token), WETH);

        assert(IUniswapV2Pair(pairAddress).token0() == (address(token) < WETH ? address(token) : WETH));
        assert(IUniswapV2Pair(pairAddress).token1() == (address(token) > WETH ? address(token) : WETH));
    }

    function test_removeLiquidity() public {
        uint256 liquidity = addLiquidity(40000e18, 10e18);
        assertGt(pair.balanceOf(user), 0);

        removeLiquidity(liquidity);
        assertEq(pair.balanceOf(user), 0);
    }

    function test_flashSwap() public {
        UniswapV2FlashSwap flashSwap = new UniswapV2FlashSwap(address(pair));
        dealTokens(DAI, user, 10000 * 1e18);
        uint256 preFlashSwapBalance = dai.balanceOf(address(pair));

        vm.startPrank(user);
        dai.approve(address(flashSwap), type(uint256).max);
        flashSwap.flashSwap(DAI, 1e6 * 1e18);

        uint256 postFlashSwapBalance = dai.balanceOf(address(pair));
        assertGt(postFlashSwapBalance, preFlashSwapBalance);
        vm.stopPrank();
    }

    function test_twap_same_price() public {
        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap0 = twap.consult(WETH, 1e18);

        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap1 = twap.consult(WETH, 1e18);
        assertApproxEqAbs(twap0, twap1, 1);
    }

    function test_twap_close_to_last_spot() public {
        dealTokens(WETH, user, 5 ether);
        vm.prank(user);
        weth.approve(address(router), 5 ether);
        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap0 = twap.consult(WETH, 1e18);

        swapTokens(2, wethDaiMkr_path);
        uint256 spot = getSpotPrice();

        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap1 = twap.consult(WETH, 1e18);

        assertLt(twap1, twap0);
        assertGe(twap1, spot);
    }

    function test_addLiquidity() public {
        uint256 liquidity = addLiquidity(40000e18, 10e18);
        assertGt(pair.balanceOf(user), 0);
        assertEq(pair.balanceOf(user), liquidity);
    }

    /**
     *
     *  Arbitrage testing
     */
    function test_arbSwap() public {
        uint256 bal0 = dai.balanceOf(user);
        vm.prank(user);

        arb.swap(
            UniswapV2Arb1.SwapParams({
                router0: UNISWAP_V2_ROUTER_02,
                router1: SUSHISWAP_V2_ROUTER_02,
                tokenIn: DAI,
                tokenOut: WETH,
                amountIn: 100 * 1e18,
                minProfit: 1
            })
        );
        uint256 bal1 = dai.balanceOf(user);

        assertGe(bal1, bal0, "No Profit!");
        assertEq(dai.balanceOf(address(arb)), 0, "DAI balance of arb != 0");
        console2.log("profit", bal1 - bal0);
    }

    function test_arb1FlashSwap() public {
        uint256 bal0 = dai.balanceOf(user);
        vm.prank(user);
        arb.flashSwap(
            UNISWAP_V2_PAIR_DAI_MKR,
            true,
            UniswapV2Arb1.SwapParams({
                router0: UNISWAP_V2_ROUTER_02,
                router1: SUSHISWAP_V2_ROUTER_02,
                tokenIn: DAI,
                tokenOut: WETH,
                amountIn: 10 * 1e18,
                minProfit: 1
            })
        );
        uint256 bal1 = dai.balanceOf(user);

        assertGe(bal1, bal0, "No Profit!");
        assertEq(dai.balanceOf(address(arb)), 0, "DAI balance of arb != 0");
        console2.log("profit", bal1 - bal0);
    }

    function test_arb2FlashSwap() public {
        uint256 bal0 = dai.balanceOf(user);
        vm.prank(user);
        arb2.flashSwap(UNISWAP_V2_PAIR_DAI_WETH, SUSHISWAP_V2_PAIR_DAI_WETH, true, 10000 * 1e18, 1);
        uint256 bal1 = dai.balanceOf(user);

        assertGe(bal1, bal0, "no profit");
        assertEq(dai.balanceOf(address(arb)), 0, "DAI balance of arb != 0");
        console2.log("profit", bal1 - bal0);
    }
}
