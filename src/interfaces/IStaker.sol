// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Interface for Staker contract
interface IStaker {
    // --- Errors ---
    /**
     * @dev The operation failed because provided address is invalid.
     */
    error InvalidAddress();

    /**
     * @dev The operation failed because provided amount is invalid.
     */
    error InvalidAmount();

    /**
     * @dev The operation failed because previous rewards period must end first.
     */
    error PreviousPeriodNotFinished(uint256 timestamp, uint256 periodFinish);

    /**
     * @dev The operation failed because rewards duration is zero.
     */
    error ZeroRewardsDuration();

    /**
     * @dev The operation failed because reward rate was zero.
     * Caused by an insufficient amount of rewards provided.
     */
    error RewardAmountTooSmall();

    /**
     * @dev The operation failed because reward rate is too big.
     */
    error RewardRateTooBig();

    /**
     * @dev The operation failed because there were no rewards to distribute.
     */
    error NoRewardsToDistribute();

    /**
     * @dev The operation failed because deposit surpasses the supply limit.
     * @param _amount of tokens attempting to be deposited.
     * @param supplyLimit allowed for deposits.
     */
    error DepositSurpassesSupplyLimit(uint256 _amount, uint256 supplyLimit);

    /**
     * @dev The operation failed because user doesn't have rewards to claim.
     */
    error NothingToClaim();

    /**
     * @dev The operation failed because renouncing ownership is prohibited.
     */
    error RenouncingOwnershipProhibited();

    /// @notice event emitted when tokens, other than the staking one, are saved from the contract
    event SavedFunds(address indexed token, uint256 amount);
    /// @notice event emitted when rewards duration was updated
    event RewardsDurationUpdated(uint256 newDuration);
    /// @notice event emitted when rewards were added
    event RewardAdded(uint256 reward);
    /// @notice event emitted when participant deposited
    event Staked(address indexed user, uint256 amount);
    /// @notice event emitted when participant claimed the investment
    event Withdrawn(address indexed user, uint256 amount);
    /// @notice event emitted when participant claimed rewards
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice returns staking token
    function tokenIn() external view returns (address);

    /// @notice returns reward token
    function rewardToken() external view returns (address);

    /// @notice when current contract distribution ends (block timestamp + rewards duration)
    function periodFinish() external view returns (uint256);

    /// @notice rewards per second
    function rewardRate() external view returns (uint256);

    /// @notice reward period
    function rewardsDuration() external view returns (uint256);

    /// @notice last reward update timestamp
    function lastUpdateTime() external view returns (uint256);

    /// @notice reward-token share
    function rewardPerTokenStored() external view returns (uint256);

    /// @notice rewards paid to participants so far
    function userRewardPerTokenPaid(address participant) external view returns (uint256);

    /// @notice accrued rewards per participant
    function rewards(address participant) external view returns (uint256);

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

    /// @notice sets the new rewards duration
    /// @param _rewardsDuration amount
    function setRewardsDuration(uint256 _rewardsDuration) external;

    /// @notice adds more rewards to the contract
    /// @param _amount new rewards amount
    function addRewards(uint256 _amount) external;

    /// @notice returns the total tokenIn supply
    function totalSupply() external view returns (uint256);

    /// @notice returns total invested amount for an account
    /// @param _account participant address
    function balanceOf(address _account) external view returns (uint256);

    /// @notice returns the last time rewards were applicable
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice returns rewards per tokenIn
    function rewardPerToken() external view returns (uint256);

    /// @notice rewards accrued rewards for account
    /// @param _account participant's address
    function earned(address _account) external view returns (uint256);

    /// @notice returns reward amount for a specific time range
    function getRewardForDuration() external view returns (uint256);

    /// @notice performs a deposit operation for msg.sender
    /// @dev updates participants rewards
    /// @param _amount deposited amount
    function deposit(uint256 _amount) external;

    /// @notice claims investment from strategy
    /// @dev updates participants rewards
    /// @param _amount amount to withdraw
    function withdraw(uint256 _amount) external;

    /// @notice claims the rewards for msg.sender
    function claimRewards() external;

    /// @notice withdraws the entire investment and claims rewards for msg.sender
    function exit() external;
}
