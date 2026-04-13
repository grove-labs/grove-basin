// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title  IPSMLike
 * @notice Minimal interface for the USDS PSM Wrapper on Ethereum mainnet that supports
 *         gem (USDC) buy/sell operations against USDS.
 */
interface IPSMLike {

    /// @notice Sells `gemAmt` of gem (USDC) for USDS. Caller must approve gem to the PSM.
    function sellGem(address usr, uint256 gemAmt) external returns (uint256 usdsOutWad);

    /// @notice Buys `gemAmt` of gem (USDC) with USDS. Caller must approve USDS to the PSM.
    function buyGem(address usr, uint256 gemAmt) external returns (uint256 usdsInWad);

    /// @notice Returns the fee (in WAD) charged when buying gems (USDC) from the PSM.
    function tout() external view returns (uint256);

}
