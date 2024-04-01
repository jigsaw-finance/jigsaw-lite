// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IIonPool {
    /**
     * @dev Allows lenders to redeem their interest-bearing position for the
     * underlying asset. It is possible that dust amounts more of the position
     * are burned than the underlying received due to rounding.
     * @param receiverOfUnderlying the address to which the redeemed underlying
     * asset should be sent to.
     * @param amount of underlying to redeem.
     */
    function withdraw(address receiverOfUnderlying, uint256 amount) external;

    /**
     * @dev Allows lenders to deposit their underlying asset into the pool and
     * earn interest on it.
     * @param user the address to receive credit for the position.
     * @param amount of underlying asset to use to create the position.
     * @param proof merkle proof that the user is whitelisted.
     */
    function supply(address user, uint256 amount, bytes32[] calldata proof) external;

    function owner() external returns (address);
    function whitelist() external returns (address);
    function updateSupplyCap(uint256 newSupplyCap) external;
    function updateIlkDebtCeiling(uint8 ilkIndex, uint256 newCeiling) external;

    function balanceOf(address user) external view returns (uint256);

    /**
     * @dev Accounting is done in normalized balances
     * @param user to get normalized balance of
     */
    function normalizedBalanceOf(address user) external returns (uint256);
}
