// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IIonPool {
    function withdraw(address receiverOfUnderlying, uint256 amount) external;
    function supply(address user, uint256 amount, bytes32[] calldata proof) external;
    function owner() external returns (address);
    function whitelist() external returns (address);
    function updateSupplyCap(uint256 newSupplyCap) external;
    function updateIlkDebtCeiling(uint8 ilkIndex, uint256 newCeiling) external;
    function balanceOf(address user) external view returns (uint256);
    function normalizedBalanceOf(address user) external returns (uint256);
    function normalizedTotalSupply() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function debt() external view returns (uint256);
    function getIlkAddress(uint256 ilkIndex) external view returns (address);
}
