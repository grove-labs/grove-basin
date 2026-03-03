// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IGroveBasinPocket {

    event LiquidityDrawn(address indexed asset, uint256 amount, uint256 convertedAmount);

    event LiquidityDeposited(address indexed asset, uint256 amount, uint256 convertedAmount);

    function basin() external view returns (address);

    function manager() external view returns (address);

    function drawLiquidity(uint256 amount, address asset) external;

    function depositLiquidity(uint256 amount, address asset) external;

    function availableBalance(address asset) external view returns (uint256);

}
