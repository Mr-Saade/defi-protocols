// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// This is Modified version from https://github.com/Uniswap/solidity-lib. As a result, DO NOT USE IN PRODUCTION

library FullMath {
    function fullMul(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256 l, uint256 h) {
        unchecked {
            uint256 mm = mulmod(x, y, type(uint256).max);
            l = x * y;
            h = mm - l;
            if (mm < l) h -= 1;
        }
    }

    function fullDiv(
        uint256 l,
        uint256 h,
        uint256 d
    ) private pure returns (uint256) {
        unchecked {
            uint256 pow2 = d & (0 - d);
            d /= pow2;
            l /= pow2;
            l += h * ((0 - pow2) / pow2 + 1);
            uint256 r = 1;
            r *= 2 - d * r;
            r *= 2 - d * r;
            r *= 2 - d * r;
            r *= 2 - d * r;
            r *= 2 - d * r;
            r *= 2 - d * r;
            r *= 2 - d * r;
            r *= 2 - d * r;
            return l * r;
        }
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        unchecked {
            (uint256 l, uint256 h) = fullMul(x, y);

            uint256 mm = mulmod(x, y, d);
            if (mm > l) h -= 1;
            l -= mm;

            if (h == 0) return l / d;

            require(h < d, "FullMath: FULLDIV_OVERFLOW");
            return fullDiv(l, h, d);
        }
    }
}
