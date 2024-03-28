// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IStaker } from "./interfaces/IStaker.sol";

/**
 * @title Staker
 * @notice Staker is a contract responsible for distributing rewards
 *  in the form of jPoints to early users of the Jigsaw protocol.
 * @notice This contract accepts wstETH tokens as `tokenIn` and distributes rewards accordingly.
 * @notice It is not intended for direct use; interaction should be done through the `stakingManager` contract.
 *
 * @dev This contract inherits functionalities from `Ownable2Step`, `Pausable`, and `ReentrancyGuard`.
 *
 * @author Hovooo (@hovooo)
 */
contract Staker is IStaker, Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @notice Address of the staking token.
     */
    address public immutable override tokenIn;

    /**
     * @notice Address of the reward token.
     */
    address public immutable rewardToken;

    /**
     * @notice Address of the staking manager.
     */
    address public immutable override stakingManager;

    /**
     * @notice Timestamp indicating when the current reward distribution ends.
     */
    uint256 public override periodFinish = 0;

    /**
     * @notice Rate of rewards per second.
     */
    uint256 public override rewardRate = 0;

    /**
     * @notice Duration of current reward period.
     */
    uint256 public override rewardsDuration;

    /**
     * @notice Timestamp of the last update time.
     */
    uint256 public override lastUpdateTime;

    /**
     * @notice Stored rewards per token.
     */
    uint256 public override rewardPerTokenStored;

    /**
     * @notice Mapping of user addresses to the amount of rewards already paid to them.
     */
    mapping(address => uint256) public override userRewardPerTokenPaid;

    /**
     * @notice Mapping of user addresses to their accrued rewards.
     */
    mapping(address => uint256) public override rewards;

    /**
     * @notice Total supply limit of the staking token.
     */
    uint256 public totalSupplyLimit = 1e34;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    // --- Modifiers ---

    /**
     * @dev Modifier to update the reward for a specified account.
     * @param account The account for which the reward needs to be updated.
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /**
     * @dev Modifier to check if the provided address is valid.
     * @param _address The address to be checked for validity.
     */
    modifier validAddress(address _address) {
        if (_address != address(0)) revert InvalidAddress();
        _;
    }

    /**
     * @dev Modifier to check if the provided amount is valid.
     * @param _amount The amount to be checked for validity.
     */
    modifier validAmount(uint256 _amount) {
        if (_amount == 0) revert InvalidAmount();
        _;
    }

    modifier onlyStakingManager() {
        if (msg.sender != stakingManager) revert UnauthorizedCaller();
        _;
    }

    /**
     * @notice Constructor function for initializing the Staker contract.
     * @param _initialOwner Address of the initial owner.
     * @param _tokenIn Address of the staking token.
     * @param _rewardToken Address of the reward token.
     */
    constructor(
        address _initialOwner,
        address _tokenIn,
        address _rewardToken,
        address _stakingManager
    )
        validAddress(_initialOwner)
        validAddress(_tokenIn)
        validAddress(_rewardToken)
        Ownable(_initialOwner)
    {
        tokenIn = _tokenIn;
        rewardToken = _rewardToken;
        stakingManager = _stakingManager;
        periodFinish = block.timestamp + 365 days;
    }

    // -- Administration --

    /**
     * @notice Sets the duration of each reward period.
     * @param _rewardsDuration The new rewards duration.
     */
    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        if (block.timestamp <= periodFinish) revert PreviousPeriodNotFinished(block.timestamp, periodFinish);
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    /**
     * @notice Adds more rewards to the contract.
     * @param _amount The amount of new rewards.
     */
    function addRewards(uint256 _amount) external onlyOwner validAmount(_amount) updateReward(address(0)) {
        if (rewardsDuration == 0) revert ZeroRewardsDuration();
        if (block.timestamp >= periodFinish) {
            rewardRate = _amount / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (_amount + leftover) / rewardsDuration;
        }

        if (rewardRate == 0) revert RewardAmountTooSmall();

        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardRate > (balance / rewardsDuration)) revert RewardRateTooBig();

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(_amount);
    }

    /**
     * @dev Triggers stopped state.
     */
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    // -- Getters --

    /**
     * @notice Returns the total supply of the staking token.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Returns the total invested amount for an account.
     * @param _account The participant's address.
     */
    function balanceOf(address _account) external view override returns (uint256) {
        return _balances[_account];
    }

    /**
     * @notice Returns the last time rewards were applicable.
     */
    function lastTimeRewardApplicable() public view override returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Returns rewards per token.
     */
    function rewardPerToken() public view override returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored + (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }

    /**
     * @notice Returns accrued rewards for an account.
     * @param _account The participant's address.
     */
    function earned(address _account) public view override returns (uint256) {
        return
            ((_balances[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) + rewards[_account];
    }

    /**
     * @notice Returns the reward amount for a specific time range.
     */
    function getRewardForDuration() external view override returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    // -- Staker's operations  --

    /**
     * @notice Performs a deposit operation for `_user`.
     * @dev Updates participants' rewards.
     *
     * @param _user to deposit for.
     * @param _amount to deposit.
     */
    function deposit(
        address _user,
        uint256 _amount
    )
        external
        override
        onlyStakingManager
        whenNotPaused
        nonReentrant
        updateReward(_user)
        validAmount(_amount)
    {
        uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardBalance == 0) revert NoRewardsToDistribute();

        _totalSupply += _amount;
        if (_totalSupply > totalSupplyLimit) revert DepositSurpassesSupplyLimit(_amount, totalSupplyLimit);

        _balances[_user] += _amount;
        emit Staked(_user, _amount);
    }

    /**
     * @notice Withdraws investment from staking.
     * @dev Updates participants' rewards.
     *
     * @param _user to withdraw for.
     * @param _amount to withdraw.
     */
    function withdraw(
        address _user,
        uint256 _amount
    )
        public
        override
        onlyStakingManager
        whenNotPaused
        nonReentrant
        updateReward(_user)
        validAmount(_amount)
    {
        _totalSupply -= _amount;
        _balances[_user] = _balances[_user] - _amount;
        emit Withdrawn(_user, _amount);
    }

    /**
     * @notice Claims the rewards for the caller.
     * @dev This function allows the caller to claim their earned rewards.
     *
     *  @param _user to claim rewards for.
     */
    function claimRewards(address _user) public override onlyStakingManager nonReentrant updateReward(_user) {
        uint256 reward = rewards[_user];
        if (reward == 0) revert NothingToClaim();

        rewards[_user] = 0;
        emit RewardPaid(_user, reward);
        IERC20(rewardToken).safeTransfer(_user, reward);
    }

    /**
     * @notice Withdraws specified `_amount` and claims rewards for the `_user`.
     * @dev This function enables the caller to exit the investment and claim their rewards.
     *
     *  @param _user to withdraw and claim for.
     *  @param _amount to withdraw.
     */
    function exit(address _user, uint256 _amount) external override onlyStakingManager {
        withdraw(_user, _amount);

        uint256 reward = rewards[_user];
        if (reward > 0) {
            claimRewards(_user);
        }
    }

    /**
     * @notice Renounce ownership override to prevent accidental loss of contract ownership.
     * @dev This function ensures that the contract's ownership cannot be lost unintentionally.
     */
    function renounceOwnership() public pure override {
        revert RenouncingOwnershipProhibited();
    }
}
