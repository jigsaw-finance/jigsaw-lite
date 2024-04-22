// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//Ion Pool Mock for testing deployment and interface verification
contract IonPool {
    uint256 val;
    address addr;

    function balanceOf(address) external view returns (uint256) {
        return val;
    }

    function debt() external view returns (uint256) {
        return val;
    }

    function getIlkAddress(uint256) external view returns (address) {
        return addr;
    }

    function supply(address user, uint256 amount, bytes32[] calldata proof) external { }
}
