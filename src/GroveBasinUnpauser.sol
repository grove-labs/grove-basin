// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IGroveBasin } from "src/interfaces/IGroveBasin.sol";

/**
 * @title  GroveBasinUnpauser
 * @notice Intended to hold the MANAGER_ADMIN_ROLE on a GroveBasin and expose a single pass-through
 *         that lets unpauser role holders unpause it. UNPAUSER_ROLE holders can unpause specific
 *         keys, while GLOBAL_UNPAUSER_ROLE holders can unpause the global pause key. The owner
 *         (OWNER_ROLE) manages both roles' membership.
 * @dev    Unpausing requires this contract to hold MANAGER_ADMIN_ROLE on the target basin; that
 *         grant is performed externally by the basin's owner. UNPAUSER_ROLE and GLOBAL_UNPAUSER_ROLE
 *         are administered by OWNER_ROLE (the AccessControl default admin).
 */
contract GroveBasinUnpauser is AccessControl {

    /// @dev The reserved pause key for the global pause (pauses all pausable functions).
    bytes4 public constant GLOBAL_PAUSE_KEY = bytes4(0);

    bytes32 public constant OWNER_ROLE           = DEFAULT_ADMIN_ROLE;
    bytes32 public constant UNPAUSER_ROLE        = keccak256("UNPAUSER_ROLE");
    bytes32 public constant GLOBAL_UNPAUSER_ROLE = keccak256("GLOBAL_UNPAUSER_ROLE");

    error InvalidOwner();

    /**
     *  @dev   Emitted when an unpauser unpauses a basin.
     *  @param basin  The basin that was unpaused.
     *  @param key    The pause key that was unset (bytes4(0) for the global pause).
     *  @param caller The UNPAUSER_ROLE holder that triggered the unpause.
     */
    event Unpaused(address indexed basin, bytes4 indexed key, address indexed caller);

    /**
     *  @param owner_           Address granted OWNER_ROLE; admin of UNPAUSER_ROLE and GLOBAL_UNPAUSER_ROLE.
     *  @param unpausers_       Addresses granted UNPAUSER_ROLE at deployment.
     *  @param globalUnpausers_ Addresses granted GLOBAL_UNPAUSER_ROLE at deployment.
     */
    constructor(address owner_, address[] memory unpausers_, address[] memory globalUnpausers_) {
        if (owner_ == address(0)) revert InvalidOwner();
        _grantRole(OWNER_ROLE, owner_);

        for (uint256 i = 0; i < unpausers_.length; i++) {
            _grantRole(UNPAUSER_ROLE, unpausers_[i]);
        }

        for (uint256 i = 0; i < globalUnpausers_.length; i++) {
            _grantRole(GLOBAL_UNPAUSER_ROLE, globalUnpausers_[i]);
        }
    }

    /**
     *  @dev   Pass-through to `setUnpaused` on the target basin. Unpausing the global pause key
     *         requires GLOBAL_UNPAUSER_ROLE; unpausing any other key requires UNPAUSER_ROLE.
     *         Reverts if this contract does not hold MANAGER_ADMIN_ROLE on `basin`.
     *  @param basin The GroveBasin to unpause.
     *  @param key   The pause key to unset (function selector, arbitrary key, or bytes4(0) for global pause).
     */
    function unpause(address basin, bytes4 key) external {
        _checkRole(key == GLOBAL_PAUSE_KEY ? GLOBAL_UNPAUSER_ROLE : UNPAUSER_ROLE);
        IGroveBasin(basin).setUnpaused(key);
        emit Unpaused(basin, key, msg.sender);
    }

}
