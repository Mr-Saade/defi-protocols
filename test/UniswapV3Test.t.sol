// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {IWETH} from "../src/Interfaces/IWETH.sol";
import {ISwapRouter} from "../src/Interfaces/UniswapV3/ISwapRouter.sol";
import {DAI, WETH, WBTC, MKR, UNISWAP_V2_ROUTER_02, UNISWAP_V2_FACTORY, UNISWAP_V2_PAIR_DAI_WETH, UNISWAP_V3_POOL_USDC_WETH_500, UNISWAP_V3_POOL_DAI_WETH_3000, SUSHISWAP_V2_ROUTER_02, UNISWAP_V2_PAIR_DAI_MKR, SUSHISWAP_V2_PAIR_DAI_WETH, UNISWAP_V3_SWAP_ROUTER_02, UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER} from "../../src/Constants/Constants.sol";
import {UniswapBaseTest} from "./UniswapBaseTest.t.sol";
import {UniswapV3Flash} from "../src/UniswapV3/UniswapV3Flash.sol";
import {UniswapV3Twap} from "../src/UniswapV3/UniswapV3Twap.sol";
import {IUniswapV3Pool} from "../src/Interfaces/UniswapV3/IUniswapV3Pool.sol";
import {FullMath} from "../src/UniswapV3/UniswapV3Twap.sol";
import {INonFungiblePositionManager} from "../src/Interfaces/UniswapV3/INonFungiblePositionManager.sol";

struct Position {
    uint96 nonce;
    address operator;
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
    uint128 tokensOwed0;
    uint128 tokensOwed1;
}

contract UniswapV3SwapTest is UniswapBaseTest {
    ISwapRouter private routerV3 = ISwapRouter(UNISWAP_V3_SWAP_ROUTER_02);
    uint24 private constant POOL_FEE = 3000;
    UniswapV3Flash private uniFlash;
    UniswapV3Twap private twapV3;

    // token0 (X)
    uint256 private constant USDC_DECIMALS = 1e6;
    // token1 (Y)
    uint256 private constant WETH_DECIMALS = 1e18;
    // 1 << 96 = 2 ** 96
    uint256 private constant Q96 = 1 << 96;
    IUniswapV3Pool private immutable pool =
        IUniswapV3Pool(UNISWAP_V3_POOL_USDC_WETH_500);
    INonFungiblePositionManager private constant manager =
        INonFungiblePositionManager(UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER);

    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = 887272;
    // DAI/WETH 3000....0.3%
    uint24 private constant POOL__FEE = 3000;
    int24 private constant TICK_SPACING = 60;

    function setUp() public override {
        super.setUp();
        uniFlash = new UniswapV3Flash(UNISWAP_V3_POOL_DAI_WETH_3000);
        twapV3 = new UniswapV3Twap(UNISWAP_V3_POOL_USDC_WETH_500);
        dealTokens(DAI, address(this), 100000 * 1e18);
        dealTokens(WETH, address(this), 100000 * 1e18);
        dai.approve(address(routerV3), type(uint256).max);
        dai.approve(address(uniFlash), type(uint256).max);

        weth.approve(address(manager), type(uint256).max);
        dai.approve(address(manager), type(uint256).max);
    }

    function test_exactInputSingle() public {
        uint256 amountOut = routerV3.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: DAI,
                tokenOut: WETH,
                fee: POOL_FEE,
                recipient: address(this),
                amountIn: 4000 * 1e18,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            })
        );

        console2.log("WETH amount out %e", amountOut);
        assertGe(amountOut, 1);
        assertGe(weth.balanceOf(address(this)), amountOut); //assertGe due to init weth balance
    }

    function test_exactInput() public {
        bytes memory path = abi.encodePacked(
            DAI,
            uint24(3000),
            WETH,
            uint24(3000),
            WBTC
        );

        uint256 amountOut = routerV3.exactInput(
            ISwapRouter.ExactInputParams({
                path: path,
                recipient: address(this),
                amountIn: 4000 * 1e18,
                amountOutMinimum: 1
            })
        );

        console2.log("WBTC amount out %e", amountOut);
        assertGe(amountOut, 1);
        assertEq(wbtc.balanceOf(address(this)), amountOut);
    }

    function test_exactOutputSingle() public {
        uint256 amountIn = routerV3.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: DAI,
                tokenOut: WETH,
                fee: POOL_FEE,
                recipient: address(this),
                amountOut: 1e18,
                amountInMaximum: 4000 * 1e18,
                sqrtPriceLimitX96: 0
            })
        );

        console2.log("DAI amount in %e", amountIn);
        assertLe(amountIn, 4000 * 1e18);
        assertGe(weth.balanceOf(address(this)), 1 * 1e18); //assertGe due to init weth balance
    }

    function test_exactOutput() public {
        bytes memory path = abi.encodePacked(
            WBTC,
            uint24(3000),
            WETH,
            uint24(3000),
            DAI
        );

        uint256 amountIn = routerV3.exactOutput(
            ISwapRouter.ExactOutputParams({
                path: path,
                recipient: address(this),
                amountOut: 1,
                amountInMaximum: 99000 * 1e18
            })
        );

        console2.log("DAI amount in %e", amountIn);
        assertLe(amountIn, 4000 * 1e18);
        assertEq(wbtc.balanceOf(address(this)), 1);
    }

    function test_flashV3() public {
        uint256 daiBefore = dai.balanceOf(address(this));
        uniFlash.flash(1e5 * 1e18, 0);
        uint256 daiAfter = dai.balanceOf(address(this));

        uint256 fee = daiBefore - daiAfter;
        console2.log("DAI fee", fee);
    }

    function test_twapV3() public view {
        uint256 usdcOut = twapV3.getTwapAmountOut({
            tokenIn: WETH,
            amountIn: 1e18,
            dt: 3600
        });

        console2.log("USDC out %e", usdcOut);
    }

    function test_spot_price_from_sqrtPriceX96() public view {
        uint256 price = 0;
        IUniswapV3Pool.Slot0 memory slot0 = pool.slot0();

        // P     = Y / X = WETH / USDC
        //               = price of USDC in terms of WETH
        // 1 / P = X / Y = USDC / WETH
        //               = price of WETH in terms of USDC

        // P has 1e18 / 1e6 = 1e12 decimals
        // 1 / P has 1e6 / 1e18 = 1e-12 decimals

        // sqrtPriceX96 * sqrtPriceX96 might overflow
        // So use FullMath.mulDiv to do uint256 * uint256 / uint256 without overflow

        // sqrtPriceX96 = sqrt(P) * Q96
        // sqrt(P) * Q96 * sqrt(P) * Q96
        //            96 bits         96 bits = 192 bits
        // 256 bits - 192 bits = 64 bits
        // 2**64 / 1e18 approx = 18

        // price = sqrt(P) * Q96 * sqrt(P) * Q96 / Q96
        price = FullMath.mulDiv(slot0.sqrtPriceX96, slot0.sqrtPriceX96, Q96);
        // 1 / price = 1 / (P * Q96)
        price = (1e12 * 1e18 * Q96) / price;

        assertGt(price, 0, "price = 0");
        console2.log("price %e", price);
    }

    /**
     *
     *
     * Liquidity
     */
    function mint() private returns (uint256 tokenId) {
        (tokenId, , , ) = manager.mint(
            INonFungiblePositionManager.MintParams({
                token0: DAI,
                token1: WETH,
                fee: POOL_FEE,
                tickLower: (MIN_TICK / TICK_SPACING) * TICK_SPACING,
                tickUpper: (MAX_TICK / TICK_SPACING) * TICK_SPACING,
                amount0Desired: 3700 * 1e18,
                amount1Desired: 1e18,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
    }

    function getPosition(
        uint256 tokenId
    ) private view returns (Position memory) {
        (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = manager.positions(tokenId);

        Position memory position = Position({
            nonce: nonce,
            operator: operator,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128,
            tokensOwed0: tokensOwed0,
            tokensOwed1: tokensOwed1
        });

        return position;
    }

    function test_mint() public {
        int24 tickLower = (MIN_TICK / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = (MAX_TICK / TICK_SPACING) * TICK_SPACING;

        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = manager.mint(
                INonFungiblePositionManager.MintParams({
                    token0: DAI,
                    token1: WETH,
                    fee: POOL_FEE,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    amount0Desired: 3700 * 1e18,
                    amount1Desired: 1e18,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp
                })
            );

        console2.log("Amount 0 added %e", amount0);
        console2.log("Amount 1 added %e", amount1);

        assertEq(manager.ownerOf(tokenId), address(this));

        Position memory position = getPosition(tokenId);
        assertEq(position.token0, DAI);
        assertEq(position.token1, WETH);
        assertGt(position.liquidity, 0);
    }

    function test_increaseLiquidity() public {
        uint256 tokenId = mint();
        Position memory p0 = getPosition(tokenId);

        (uint256 liquidityDelta, uint256 amount0, uint256 amount1) = manager
            .increaseLiquidity(
                INonFungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: 3700 * 1e18,
                    amount1Desired: 1e18,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );

        console2.log("Amount 0 added %e", amount0);
        console2.log("Amount 1 added %e", amount1);

        Position memory p1 = getPosition(tokenId);
        assertGt(p1.liquidity, p0.liquidity);
        assertGt(liquidityDelta, 0);
    }

    function test_decreaseLiquidity() public {
        uint256 tokenId = mint();
        Position memory p0 = getPosition(tokenId);

        (uint256 amount0, uint256 amount1) = manager.decreaseLiquidity(
            INonFungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: p0.liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        console2.log("Amount 0 decreased %e", amount0);
        console2.log("Amount 1 decreased %e", amount1);

        Position memory p1 = getPosition(tokenId);
        assertEq(p1.liquidity, 0);
        assertGt(p1.tokensOwed0, 0);
        assertGt(p1.tokensOwed1, 0);
    }

    function test_collect() public {
        uint256 tokenId = mint();
        Position memory p0 = getPosition(tokenId);

        manager.decreaseLiquidity(
            INonFungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: p0.liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        (uint256 amount0, uint256 amount1) = manager.collect(
            INonFungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        console2.log("--- collect ---");
        console2.log("Amount 0 collected %e", amount0);
        console2.log("Amount 1 collected %e", amount1);

        Position memory p1 = getPosition(tokenId);

        assertEq(p1.liquidity, 0);
        assertEq(p1.tokensOwed0, 0);
        assertEq(p1.tokensOwed1, 0);
    }
}
