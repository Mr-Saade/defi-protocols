//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CurveBaseTest} from "./CurveBaseTest.t.sol";
import {console2} from "forge-std/console2.sol";

contract CurveV1Test is CurveBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_get_dy_underlying() public view {
        uint256 dy = pool.get_dy_underlying(0, 1, 1e6 * 1e18);

        console2.log("dy %e", dy);
        assertGt(dy, 0, "dy = 0");
    }

    function test_exchange() public {
        pool.exchange(0, 1, 1e6 * 1e18, 0.999 * 1e6 * 1e6);

        uint256 bal = usdc.balanceOf(address(this));
        console2.log("USDC balance %e", bal);
        assertGt(bal, 0, "USDC balance = 0");
    }

    function test_add_liquidity() public {
        addLiquidity();
        uint256 lpBal = lp.balanceOf(address(this));
        assertGt(lpBal, 0);
    }

    function test_remove_liquidity() public {
        addLiquidity();
        uint256 lpBal = lp.balanceOf(address(this));

        uint256[3] memory minCoins = [uint256(1), uint256(1), uint256(1)];
        pool.remove_liquidity(lpBal, minCoins);

        assertEq(lp.balanceOf(address(this)), 0, "3CRV balance > 0");

        uint256 bal = 0;

        bal = dai.balanceOf(address(this));
        assertGt(bal, 0, "DAI balance = 0");
        console2.log("DAI balance %e", bal);

        bal = usdc.balanceOf(address(this));
        assertGt(bal, 0, "USDC balance = 0");
        console2.log("USDC balance %e", bal);

        bal = usdt.balanceOf(address(this));
        assertGt(bal, 0, "USDT balance = 0");
        console2.log("USDT balance %e", bal);
    }

    function test_remove_liquidity_one_coin() public {
        uint256 initUsdtBlance = usdt.balanceOf(address(this));
        addLiquidity();
        uint256 lpBal = lp.balanceOf(address(this));
        pool.remove_liquidity_one_coin(lpBal, 0, 1);

        assertEq(lp.balanceOf(address(this)), 0, "3CRV balance > 0");

        uint256 bal = 0;

        bal = dai.balanceOf(address(this));
        assertGt(bal, 0, "DAI balance = 0");
        console2.log("DAI balance %e", bal);

        bal = usdc.balanceOf(address(this));
        assertEq(bal, 0e0, "USDC balance > 0");
        console2.log("USDC balance %e", bal);

        bal = usdt.balanceOf(address(this));
        assertEq(bal, initUsdtBlance, "USDT balance > 0");
        console2.log("USDT balance %e", bal);
    }
}
