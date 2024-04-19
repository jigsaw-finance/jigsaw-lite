// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IHoldingManager } from "./IHoldingManager.sol";

/**
 * @title IStakingManager interface
 * @notice Interface for the Staking Manager contract of the Jigsaw Protocol
 *
 */
interface IStakingManager {
    // --- Errors ---
    /**
     * @dev The operation failed because renouncing ownership is prohibited.
     */
    error RenouncingOwnershipProhibited();

    /**
     * @dev The operation failed because amount is zero.
     */
    error InvalidAmount();

    /**
     * @dev The operation failed because provided address is invalid.
     */
    error InvalidAddress();

    /**
     * @dev The operation failed because unstaking is not possible before lockup period ends.
     */
    error PreLockupPeriodUnstaking();

    /**
     * @dev The operation failed because caller's holding's balance in Ion Pool is zero.
     */
    error NothingToWithdrawFromIon(address caller);

    // --- Events ---
    /**
     * @dev emitted when participant staked.
     */
    event Staked(address indexed user, uint256 indexed amount);

    /**
     * @dev emitted when participant unstaked.
     */
    event Unstaked(address indexed to, uint256 indexed amount);

    /**
     * @dev emitted when the expiration date of a lockup is updated.
     * @param oldDate The previous expiration date of the lockup.
     * @param newDate The new expiration date of the lockup.
     */
    event LockupExpirationDateUpdated(uint256 indexed oldDate, uint256 indexed newDate);

    /**
     * @notice Returns the HoldingManager.
     */
    function holdingManager() external view returns (IHoldingManager);

    /**
     * @dev Address of the underlying asset used for staking.
     */
    function underlyingAsset() external view returns (address);

    /**
     * @dev Address of the reward token distributed for staking.
     */
    function rewardToken() external view returns (address);

    /**
     * @dev Address of the Ion Pool contract.
     */
    function ionPool() external view returns (address);

    /**
     * @dev Address of the Staker contract used for jPoints distribution.
     */
    function staker() external view returns (address);

    /**
     * @dev Represents the expiration date for the staking lockup period.
     * After this date, staked funds can be withdrawn. If not withdrawn will continue to
     * generate wstETH rewards and, if applicable, additional jPoints as long as staked.
     * @return The expiration date for the staking lockup period, in Unix timestamp format.
     */
    function lockupExpirationDate() external view returns (uint256);

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
     */
    function unstake(address _to) external;

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external;

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external;

    /**
     * @dev Get the address of the holding associated with the user.
     * @param _user The address of the user.
     * @return the holding address.
     */
    function getUserHolding(address _user) external view returns (address);
}
