// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

contract MockChronicleOracle {

    uint256 public val;
    uint256 public age;
    bool    public hasPoked;
    uint8   public decimals = 18;

    function __setVal(uint256 val_) external {
        val = val_;
        age = block.timestamp;
        hasPoked = true;
    }

    function __setAge(uint256 age_) external {
        age = age_;
    }

    function __setDecimals(uint8 decimals_) external {
        decimals = decimals_;
    }

    function read() external view returns (uint256) {
        require(hasPoked, "MockChronicleOracle/not-poked");
        return val;
    }

    function tryRead() external view returns (bool, uint256) {
        return (hasPoked, val);
    }

    function readWithAge() external view returns (uint256, uint256) {
        require(hasPoked, "MockChronicleOracle/not-poked");
        return (val, age);
    }

    function tryReadWithAge() external view returns (bool, uint256, uint256) {
        return (hasPoked, val, age);
    }

}
