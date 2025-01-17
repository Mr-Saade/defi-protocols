// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {IWETH} from "../src/Interfaces/IWETH.sol";
import {IUniswapV2Router02} from "../src/Interfaces/UniswapV2/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/Interfaces/UniswapV2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/Interfaces/UniswapV2/IUniswapV2Pair.sol";
import {
    DAI,
    WETH,
    WBTC,
    MKR,
    UNISWAP_V2_ROUTER_02,
    UNISWAP_V2_FACTORY,
    UNISWAP_V2_PAIR_DAI_WETH,
    SUSHISWAP_V2_ROUTER_02,
    UNISWAP_V2_PAIR_DAI_MKR
} from "../../src/Constants/Constants.sol";
import {UniswapV2FlashSwap} from "../src/UniswapV2/UniswapV2FlashSwap.sol";
import {UniswapV2Twap} from "../src/UniswapV2/UniswapV2Twap.sol";

abstract contract UniswapBaseTest is Test {
    IWETH internal constant weth = IWETH(WETH);
    IERC20 internal constant dai = IERC20(DAI);
    IERC20 internal constant mkr = IERC20(MKR);
    IERC20 internal constant wbtc = IERC20(WBTC);
    IUniswapV2Router02 internal constant router = IUniswapV2Router02(UNISWAP_V2_ROUTER_02);
    IUniswapV2Router02 internal constant sushi_router = IUniswapV2Router02(SUSHISWAP_V2_ROUTER_02);
    IUniswapV2Factory internal constant factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    IUniswapV2Pair internal constant pair = IUniswapV2Pair(UNISWAP_V2_PAIR_DAI_WETH);

    UniswapV2Twap internal twap;
    address internal user = makeAddr("user");
    uint16 internal constant MIN_WAIT = 300;
    address[] public wethDaiMkr_path;

    function setUp() public virtual {
        twap = new UniswapV2Twap(address(pair));

        wethDaiMkr_path = [WETH, DAI, MKR];
    }

    function dealTokens(address token, address recipient, uint256 amount) internal {
        deal(token, recipient, amount);
    }

    function getSpotPrice() internal view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        return (uint256(reserve0) * 1e18) / uint256(reserve1); // DAI / WETH
    }

    function swapTokens(uint256 amountIn, address[] memory path) internal {
        weth.approve(address(router), type(uint256).max);
        router.swapExactTokensForTokens(
            amountIn,
            1, // amountOutMin
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 daiAmount, uint256 wethAmount) internal returns (uint256) {
        dealTokens(DAI, user, daiAmount);
        dealTokens(WETH, user, wethAmount);

        vm.startPrank(user);
        dai.approve(address(router), daiAmount);
        weth.approve(address(router), wethAmount);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity({
            tokenA: DAI,
            tokenB: WETH,
            amountADesired: daiAmount,
            amountBDesired: wethAmount,
            amountAMin: 1,
            amountBMin: 1,
            to: user,
            deadline: block.timestamp
        });
        vm.stopPrank();

        return liquidity;
    }

    function removeLiquidity(uint256 liquidity) internal {
        vm.startPrank(user);
        pair.approve(address(router), liquidity);

        (uint256 amountA, uint256 amountB) = router.removeLiquidity({
            tokenA: DAI,
            tokenB: WETH,
            liquidity: liquidity,
            amountAMin: 1,
            amountBMin: 1,
            to: user,
            deadline: block.timestamp
        });

        vm.stopPrank();

        console2.log("Removed DAI:", amountA);
        console2.log("Removed WETH:", amountB);
    }
}
