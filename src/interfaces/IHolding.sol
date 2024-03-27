// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IHolding {
    /**
     * @notice Returns the StakingManager address.
     */
    function stakingManager() external view returns (address);

    /**
     * @notice Initializes the contract.
     * @param _stakingManager Address of the contract handling staking.
     */
    function init(address _stakingManager) external;
}
