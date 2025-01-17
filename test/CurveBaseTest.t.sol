// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IStableSwap3Pool} from "../src/Interfaces/Curve/IStableSwap3Pool.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {DAI, USDC, WETH, USDT, WBTC, CURVE_3POOL, CURVE_3CRV, CURVE_TRI_CRYPTO} from "../../src/Constants/Constants.sol";
import {ITriCrypto} from "../src/Interfaces/Curve/ITriCrypto.sol";
import {IWETH} from "../src/Interfaces/IWETH.sol";

contract CurveBaseTest is Test {
    IStableSwap3Pool internal constant pool = IStableSwap3Pool(CURVE_3POOL);
    ITriCrypto internal constant poolTri = ITriCrypto(CURVE_TRI_CRYPTO);
    IERC20 internal constant dai = IERC20(DAI);
    IERC20 internal constant usdc = IERC20(USDC);
    IERC20 internal constant usdt = IERC20(USDT);
    IERC20 internal constant wbtc = IERC20(WBTC);
    IWETH internal constant weth = IWETH(WETH);
    IERC20 internal constant lp = IERC20(CURVE_3CRV);

    function setUp() public virtual {
        deal(DAI, address(this), 1e6 * 1e18);
        dai.approve(address(pool), type(uint256).max);
    }

    function addLiquidity() internal {
        uint256[3] memory coins = [uint256(1e6 * 1e18), uint256(0), uint256(0)];

        pool.add_liquidity(coins, 1);
    }

    function addLiquidityV2() internal {
        uint256[3] memory amounts = [
            uint256(1e3 * 1e6),
            uint256(0),
            uint256(0)
        ];
        poolTri.add_liquidity({
            amounts: amounts,
            min_lp: 1,
            use_eth: false,
            receiver: address(this)
        });
    }
}
