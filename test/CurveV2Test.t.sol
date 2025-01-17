//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CurveBaseTest} from "./CurveBaseTest.t.sol";
import {USDC, WETH} from "../../src/Constants/Constants.sol";
import {console2} from "forge-std/console2.sol";

contract CurveV2Test is CurveBaseTest {
    function setUp() public override {
        deal(USDC, address(this), 1e3 * 1e6);
        usdc.approve(address(poolTri), type(uint256).max);
        deal(WETH, address(this), 1e18);
        weth.approve(address(poolTri), type(uint256).max);
    }

    function test__add_liquidity() public {
        addLiquidityV2();
        uint256 lpBal = poolTri.balanceOf(address(this));
        assertGt(lpBal, 0, "lp = 0");
    }

    function test__exchange() public {
        poolTri.exchange({
            i: 2,
            j: 0,
            dx: 1e18,
            min_dy: 1,
            use_eth: false,
            receiver: address(this)
        });

        uint256 bal = usdc.balanceOf(address(this));
        console2.log("USDC balance %e", bal);
        assertGt(bal, 0, "USDC balance = 0");
    }

    function test__remove_liquidity() public {
        // Foundry bug? initial balance > 0
        addLiquidityV2();
        uint256 wethBalBefore = weth.balanceOf(address(this));

        uint256 lpBal = poolTri.balanceOf(address(this));

        uint256[3] memory minAmounts = [uint256(1), uint256(1), uint256(1)];
        poolTri.remove_liquidity({
            lp: lpBal,
            min_amounts: minAmounts,
            use_eth: false,
            receiver: address(this),
            claim_admin_fees: false
        });

        assertEq(poolTri.balanceOf(address(this)), 0, "3CRV balance > 0");

        uint256 bal = 0;

        bal = usdc.balanceOf(address(this));
        assertGt(bal, 0, "USDC balance = 0");
        console2.log("USDC balance %e", bal);

        bal = wbtc.balanceOf(address(this));
        assertGt(bal, 0, "WBTC balance = 0");
        console2.log("WBTC balance %e", bal);

        bal = weth.balanceOf(address(this));
        assertGt(bal, wethBalBefore, "WETH balance = 0");
        console2.log("WETH balance %e", bal - wethBalBefore);
    }

    function test__remove_liquidity_one_coin() public {
        // Foundry bug? initial balance > 0
        addLiquidityV2();
        uint256 wethBalBefore = weth.balanceOf(address(this));
        uint256 lpBal = poolTri.balanceOf(address(this));
        poolTri.remove_liquidity_one_coin({
            lp: lpBal,
            i: 0,
            min_amount: 1,
            use_eth: false,
            receiver: address(this)
        });

        assertEq(poolTri.balanceOf(address(this)), 0, "3CRV balance > 0");

        uint256 bal = 0;

        bal = usdc.balanceOf(address(this));
        assertGt(bal, 0, "USDC balance = 0");
        console2.log("USDC balance %e", bal);

        bal = wbtc.balanceOf(address(this));
        assertEq(bal, 0, "WBTC balance > 0");
        console2.log("WBTC balance %e", bal);

        bal = weth.balanceOf(address(this));
        assertEq(bal, wethBalBefore, "WETH balance > 0");
        console2.log("WETH balance %e", bal - wethBalBefore);
    }
}
