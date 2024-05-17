// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Interface for Staker contract
interface IStaker {
    // --- Errors ---
    /**
     * @notice The operation failed because provided address is invalid.
     */
    error InvalidAddress();

    /**
     * @notice The operation failed because provided amount is invalid.
     */
    error InvalidAmount();

    /**
     * @notice The operation failed because caller was unauthorized for the action.
     */
    error UnauthorizedCaller();

    /**
     * @notice The operation failed because the previous rewards period must end first.
     * @param timestamp The current timestamp when the error occurred.
     * @param periodFinish The timestamp when the current rewards period is expected to end.
     */
    error PreviousPeriodNotFinished(uint256 timestamp, uint256 periodFinish);

    /**
     * @notice The operation failed because rewards duration is zero.
     */
    error ZeroRewardsDuration();

    /**
     * @notice The operation failed because reward rate was zero.
     * Caused by an insufficient amount of rewards provided.
     */
    error RewardAmountTooSmall();

    /**
     * @notice The operation failed because reward rate is too big.
     */
    error RewardRateTooBig();

    /**
     * @notice The operation failed because there were no rewards to distribute.
     */
    error NoRewardsToDistribute();

    /**
     * @notice The operation failed because deposit surpasses the supply limit.
     * @param _amount of tokens attempting to be deposited.
     * @param supplyLimit allowed for deposits.
     */
    error DepositSurpassesSupplyLimit(uint256 _amount, uint256 supplyLimit);

    /**
     * @notice The operation failed because user doesn't have rewards to claim.
     */
    error NothingToClaim();

    /**
     * @notice The operation failed because renouncing ownership is prohibited.
     */
    error RenouncingOwnershipProhibited();

    // --- Events ---

    /**
     * @notice Event emitted when the rewards duration is updated.
     * @param oldDuration The previous rewards duration.
     * @param newDuration The new rewards duration.
     */
    event RewardsDurationUpdated(uint256 indexed oldDuration, uint256 indexed newDuration);

    /**
     * @notice Event emitted when new rewards are added.
     * @param reward The amount of rewards added.
     */
    event RewardAdded(uint256 indexed reward);

    /**
     * @notice Event emitted when a participant deposits an amount.
     * @param user The address of the participant who made the deposit.
     * @param amount The amount that was deposited.
     */
    event Staked(address indexed user, uint256 indexed amount);

    /**
     * @notice Event emitted when a participant withdraws their stake.
     * @param user The address of the participant who withdrew their stake.
     * @param amount The amount that was withdrawn.
     */
    event Withdrawn(address indexed user, uint256 indexed amount);

    /**
     * @notice Event emitted when a participant claims their rewards.
     * @param user The address of the participant who claimed the rewards.
     * @param reward The amount of rewards that were claimed.
     */
    event RewardPaid(address indexed user, uint256 indexed reward);

    /**
     * @notice returns staking token address.
     */
    function tokenIn() external view returns (address);

    /**
     * @notice returns reward token address.
     */
    function rewardToken() external view returns (address);

    /**
     * @notice returns stakingManager address.
     */
    function stakingManager() external view returns (address);

    /**
     * @notice when current contract distribution ends (block timestamp + rewards duration).
     */
    function periodFinish() external view returns (uint256);

    /**
     * @notice rewards per second.
     */
    function rewardRate() external view returns (uint256);

    /**
     * @notice reward period.
     */
    function rewardsDuration() external view returns (uint256);

    /**
     * @notice last reward update timestamp.
     */
    function lastUpdateTime() external view returns (uint256);

    /**
     * @notice reward-token share.
     */
    function rewardPerTokenStored() external view returns (uint256);

    /**
     * @notice rewards paid to participants so far.
     */
    function userRewardPerTokenPaid(address participant) external view returns (uint256);

    /**
     * @notice accrued rewards per participant.
     */
    function rewards(address participant) external view returns (uint256);

    /**
     * @notice sets the new rewards duration.
     */
    function setRewardsDuration(uint256 _rewardsDuration) external;

    /**
     * @notice Adds more rewards to the contract.
     *
     * @dev Prior approval is required for this contract to transfer rewards from `_from` address.
     *
     * @param _from address to transfer rewards from.
     * @param _amount The amount of new rewards.
     */
    function addRewards(address _from, uint256 _amount) external;

    /**
     * @notice Triggers stopped state.
     */
    function pause() external;

    /**
     * @notice Returns to normal state.
     */
    function unpause() external;

    /**
     * @notice returns the total tokenIn supply.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice returns total invested amount for an account.
     * @param _account participant address
     */
    function balanceOf(address _account) external view returns (uint256);

    /**
     * @notice returns the last time rewards were applicable.
     */
    function lastTimeRewardApplicable() external view returns (uint256);

    /**
     * @notice returns rewards per tokenIn.
     */
    function rewardPerToken() external view returns (uint256);

    /**
     * @notice rewards accrued rewards for account.
     *  @param _account participant's address
     */
    function earned(address _account) external view returns (uint256);

    /**
     * @notice returns reward amount for a specific time range.
     */
    function getRewardForDuration() external view returns (uint256);

    /**
     * @notice Performs a deposit operation for `_user`.
     * @dev Updates participants' rewards.
     *
     * @param _user to deposit for.
     * @param _amount to deposit.
     */
    function deposit(address _user, uint256 _amount) external;

    /**
     * @notice Withdraws specified `_amount` and claims rewards for the `_user`.
     * @dev This function enables the caller to exit the investment and claim their rewards.
     *
     * @param _user to withdraw and claim for.
     * @param _to address to which funds will be sent.
     */
    function exit(address _user, address _to) external;
}
