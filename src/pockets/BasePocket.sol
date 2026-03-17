// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { IAccessControl } from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IGroveBasin }       from "src/interfaces/IGroveBasin.sol";
import { IGroveBasinPocket } from "src/interfaces/IGroveBasinPocket.sol";

/**
 * @title  BasePocket
 * @notice Abstract base contract for all Grove Basin pockets, containing shared authorization
 *         logic and the immutable basin reference.
 *
 * @dev    Trust model:
 *         - Basin: Immutable address set at construction. Can call depositLiquidity and
 *           withdrawLiquidity unconditionally.
 *         - MANAGER_ROLE: Determined by the Grove Basin's AccessControl. Any address that holds
 *           MANAGER_ROLE in the basin can call depositLiquidity and withdrawLiquidity.
 */
abstract contract BasePocket is IGroveBasinPocket {

    IGroveBasin internal immutable _basin;

    modifier onlyBasinOrManager() {
        require(
            msg.sender == address(_basin)
                || IAccessControl(address(_basin)).hasRole(_basin.MANAGER_ROLE(), msg.sender),
            "BasePocket/not-authorized"
        );
        _;
    }

    constructor(address basin_) {
        require(basin_ != address(0), "BasePocket/invalid-basin");
        _basin = IGroveBasin(basin_);
    }

    function basin() external view override returns (address) {
        return address(_basin);
    }

}
