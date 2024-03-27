// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IStakerManager interface
 * @notice Interface for the Staker Manager contract of the Jigsaw Protocol
 *
 */
interface IStakerManager {
    // --- Errors ---
    /**
     * @dev The operation failed because renouncing ownership is prohibited.
     */
    error RenouncingOwnershipIsProhibited();
    /**
     * @dev The operation failed because amount is zero;
     */
    error InvalidAmount();

    // --- Events ---
    /**
     * @dev emitted when participant deposited
     */
    event Staked(address indexed user, uint256 indexed amount);

    /**
     * @dev emitted when a new holding is created
     */
    event HoldingCreated(address indexed user, address indexed holdingAddress);

    /**
     * @notice Stakes a specified amount of assets for the msg.sender.
     * @dev Initiates the staking operation by depositing the specified `_amount`
     * into the Ion Pool contract, while simultaneously recording this deposit within the Jigsaw Staking Contract.
     *
     * Requirements:
     * - The caller must have sufficient assets to stake.
     * - The Ion Pool Contract's supply cap should not exceed its limit after the user's stake operation.
     *
     * @param _amount The amount of assets to stake.
     */
    function stake(uint256 _amount) external;

    /**
     * @notice Withdraws a specified amount of staked assets.
     * @dev Initiates the withdrawal of staked assets by transferring the specified `_amount`
     * from the Ion Pool contract to the designated recipient `_to`.
     *
     * Requirements:
     * - The caller must have sufficient staked assets to fulfill the withdrawal.
     * - The `_to` address must be a valid Ethereum address.
     *
     * @param _to The address to receive the unstaked assets.
     * @param _amount The amount of staked assets to withdraw.
     */
    function unstake(address _to, uint256 _amount) external;
}
