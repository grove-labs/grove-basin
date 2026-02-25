// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IAaveV3PoolLike {

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

}
