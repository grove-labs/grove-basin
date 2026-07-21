// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

/**
 * @title  GroveBasinUnpauser
 * @notice Intended to hold the MANAGER_ADMIN_ROLE on a GroveBasin and expose a single pass-through
 *         that lets UNPAUSER_ROLE holders unpause it. The owner (OWNER_ROLE) manages UNPAUSER_ROLE
 *         membership.
 * @dev    Unpausing requires this contract to hold MANAGER_ADMIN_ROLE on the target basin; that
 *         grant is performed externally by the basin's owner. UNPAUSER_ROLE is administered by
 *         OWNER_ROLE (the AccessControl default admin).
 */
contract GroveBasinUnpauser is AccessControl {

    bytes32 public constant OWNER_ROLE    = DEFAULT_ADMIN_ROLE;
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    error InvalidOwner();

    /**
     *  @dev   Emitted when an unpauser unpauses a basin.
     *  @param basin  The basin that was unpaused.
     *  @param key    The pause key that was unset (bytes4(0) for the global pause).
     *  @param caller The UNPAUSER_ROLE holder that triggered the unpause.
     */
    event Unpaused(address indexed basin, bytes4 indexed key, address indexed caller);

    /**
     *  @param owner_     Address granted OWNER_ROLE; admin of UNPAUSER_ROLE.
     *  @param unpausers_ Addresses granted UNPAUSER_ROLE at deployment.
     */
    constructor(address owner_, address[] memory unpausers_) {
        if (owner_ == address(0)) revert InvalidOwner();
        _grantRole(OWNER_ROLE, owner_);

        for (uint256 i = 0; i < unpausers_.length; i++) {
            _grantRole(UNPAUSER_ROLE, unpausers_[i]);
        }
    }

    /**
     *  @dev   Pass-through to `setUnpaused` on the target basin. Callable only by UNPAUSER_ROLE.
     *         Reverts if this contract does not hold MANAGER_ADMIN_ROLE on `basin`.
     *  @param basin The GroveBasin to unpause.
     *  @param key   The pause key to unset (function selector, arbitrary key, or bytes4(0) for global pause).
     */
    function unpause(address basin, bytes4 key) external onlyRole(UNPAUSER_ROLE) {
        IGroveBasin(basin).setUnpaused(key);
        emit Unpaused(basin, key, msg.sender);
    }

}
