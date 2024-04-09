// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//Ion Pool Mock for testing deployment and interface verification
contract IonPool {
    function balanceOf(address user) external view returns (uint256) {
        return 1e18;
    }

    function debt() external view returns (uint256) {
        return 0;
    }

    function getIlkAddress(uint256 ilkIndex) external view returns (address) {
        return address(1);
    }
}
