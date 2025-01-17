// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IUniswapV2Pair} from "../Interfaces/UniswapV2/IUniswapV2Pair.sol";
import {IERC20} from "../../lib/forge-std/src/interfaces/IERC20.sol";

error InvalidToken();

contract UniswapV2FlashSwap {
    IUniswapV2Pair private immutable pair;
    address private immutable token0;
    address private immutable token1;

    constructor(address _pair) {
        pair = IUniswapV2Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
    }

    function flashSwap(address token, uint256 amount) external {
        if (token != token0 && token != token1) {
            revert InvalidToken();
        }

        (uint256 amount0Out, uint256 amount1Out) = token == token0
            ? (amount, uint256(0))
            : (uint256(0), amount);

        bytes memory data = abi.encode(token, msg.sender);

        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    // Uniswap V2 callback
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(sender == address(this));
        require(msg.sender == address(pair));

        (address token, address caller) = abi.decode(data, (address, address));

        uint256 amount = amount0 > 0 ? amount0 : amount1;

        uint256 fee = (amount * 3) / 997 + 1;
        uint256 amountToRepay = amount + fee;

        IERC20(token).transferFrom(caller, address(this), fee);
        IERC20(token).transfer(address(pair), amountToRepay);
    }
}
