// SPDX-License-Identifier: MIT
pragma solidity >=0.4 <0.9;

import {IUniswapV2Pair} from "../Interfaces/UniswapV2/IUniswapV2Pair.sol";
import {FixedPoint} from "./FixedPoint.sol";

// Modified from https://github.com/Uniswap/v2-periphery/blob/master/contracts/examples/ExampleOracleSimple.sol
// Do not use this contract in production

error InsufficientTimeElapsed();
error InvalidToken();

contract UniswapV2Twap {
    using FixedPoint for *;

    // Minimum wait time in seconds before the function update can be called again
    // TWAP of time > MIN_WAIT
    uint256 private constant MIN_WAIT = 300;

    IUniswapV2Pair public immutable pair;
    address public immutable token0;
    address public immutable token1;

    // Cumulative prices are uq112x112 price * seconds
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    // Last timestamp the cumulative prices were updated
    uint32 public updatedAt;

    // TWAP of token0 and token1
    // range: [0, 2**112 - 1]
    // resolution: 1 / 2**112
    // TWAP of token0 in terms of token1
    FixedPoint.uq112x112 public price0Avg;
    // TWAP of token1 in terms of token0
    FixedPoint.uq112x112 public price1Avg;

    constructor(address _pair) {
        pair = IUniswapV2Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
        price0CumulativeLast = pair.price0CumulativeLast();
        price1CumulativeLast = pair.price1CumulativeLast();
        (, , updatedAt) = pair.getReserves();
    }

    function _getCurrentCumulativePrices()
        internal
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative)
    {
        price0Cumulative = pair.price0CumulativeLast();
        price1Cumulative = pair.price1CumulativeLast();

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair
            .getReserves();
        uint32 blockTimestamp = uint32(block.timestamp);
        if (blockTimestampLast != blockTimestamp) {
            uint32 dt = blockTimestamp - blockTimestampLast;
            // Addition overflow is desired
            unchecked {
                price0Cumulative +=
                    uint256(FixedPoint.fraction(reserve1, reserve0)._x) *
                    dt;
                price1Cumulative +=
                    uint256(FixedPoint.fraction(reserve0, reserve1)._x) *
                    dt;
            }
        }
    }

    function update() external {
        uint32 blockTimestamp = uint32(block.timestamp);

        uint32 dt = blockTimestamp - updatedAt;

        if (dt < MIN_WAIT) {
            revert InsufficientTimeElapsed();
        }

        (
            uint256 price0Cumulative,
            uint256 price1Cumulative
        ) = _getCurrentCumulativePrices();

        // Overflow is desired, casting never truncates
        // https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/building-an-oracle
        // Subtracting between two cumulative price values will result in
        // a number that fits within the range of uint256 as long as the
        // observations are made for periods of max 2^32 seconds, or ~136 years
        unchecked {
            price0Avg = FixedPoint.uq112x112(
                uint224((price0Cumulative - price0CumulativeLast) / dt)
            );
            price1Avg = FixedPoint.uq112x112(
                uint224((price1Cumulative - price1CumulativeLast) / dt)
            );
        }

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        updatedAt = blockTimestamp;
    }

    function consult(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        if (tokenIn != token0 && tokenIn != token1) {
            revert InvalidToken();
        }

        if (tokenIn == token0) {
            amountOut = FixedPoint.mul(price0Avg, amountIn).decode144();
        } else {
            amountOut = FixedPoint.mul(price1Avg, amountIn).decode144();
        }
    }
}
