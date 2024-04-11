// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//Ion Pool Mock for testing deployment and interface verification
contract IonPool {
    // ignore warning 5667
    function balanceOf(address) external view returns (uint256) {
        return 1e18;
    }

    // ignore warning 5667
    function debt() external view returns (uint256) {
        return 0;
    }

    // ignore warning 5667
    function getIlkAddress(uint256) external view returns (address) {
        return address(1);
    }

    function supply(address user, uint256 amount, bytes32[] calldata proof) external { }
}
