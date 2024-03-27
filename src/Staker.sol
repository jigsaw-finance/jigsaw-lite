// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IStaker } from "./interfaces/IStaker.sol";

/// @title Staking and reward distribution contract based on synthetix
/// @author Hovooo (@hovooo)
contract Staker is IStaker, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice returns staking token
    address public immutable override tokenIn;

    // @note should it be reward tokenS?
    /// @notice returns reward token
    address public immutable override rewardToken;

    /// @notice when current reward distribution ends
    uint256 public override periodFinish = 0;

    /// @notice rewards per second
    uint256 public override rewardRate = 0;

    /// @notice reward period
    uint256 public override rewardsDuration;

    /// @notice last reward update timestamp
    uint256 public override lastUpdateTime;

    // @note should it be JIG reward per token?
    // @note what to do with rewards from ION? How can we get it?
    /// @notice reward-token share
    uint256 public override rewardPerTokenStored;

    // @note should it be JIG rewards paid?
    /// @notice rewards paid to participants so far
    mapping(address => uint256) public override userRewardPerTokenPaid;

    // @note should it be JIG rewards?
    /// @notice accrued rewards per participant
    mapping(address => uint256) public override rewards;

    /// @notice returns the pause state of the contract
    bool public override paused;

    // @note do we need to limit it more?
    uint256 public totalSupplyLimit = 1e34;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /// @notice creates a new Staker contract
    /// @param _tokenIn staking token address
    /// @param _rewardToken reward token address
    constructor(
        address _initialOwner,
        address _tokenIn,
        address _rewardToken
    )
        Ownable(_initialOwner)
        validAddress(_tokenIn)
        validAddress(_rewardToken)
    {
        tokenIn = _tokenIn;
        rewardToken = _rewardToken;
        periodFinish = block.timestamp + 365 days;
    }

    // -- Owner specific methods --

    /// @notice sets a new value for pause state
    /// @param _val the new value
    function setPaused(bool _val) external onlyOwner {
        emit PauseUpdated(paused, _val);
        paused = _val;
    }

    /// @notice sets the new rewards duration
    /// @param _rewardsDuration amount
    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(block.timestamp > periodFinish, "3087");
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    /// @notice adds more rewards to the contract
    /// @param _amount new rewards amount
    function addRewards(uint256 _amount) external onlyOwner validAmount(_amount) updateReward(address(0)) {
        require(rewardsDuration > 0, "3089");
        if (block.timestamp >= periodFinish) {
            rewardRate = _amount / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (_amount + leftover) / rewardsDuration;
        }

        // prevent setting rewardRate to 0 because of precision loss
        require(rewardRate != 0, "3088");

        // prevent overflows
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        require(rewardRate <= (balance / rewardsDuration), "2003");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(_amount);
    }

    // -- View type methods --
    /// @notice returns the total tokenIn supply
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /// @notice returns total invested amount for an account
    /// @param _account participant address
    function balanceOf(address _account) external view override returns (uint256) {
        return _balances[_account];
    }

    /// @notice returns the last time rewards were applicable
    function lastTimeRewardApplicable() public view override returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @notice returns rewards per tokenIn
    function rewardPerToken() public view override returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored + (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }

    /// @notice rewards accrued rewards for account
    /// @param _account participant's address
    function earned(address _account) public view override returns (uint256) {
        return
            ((_balances[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) + rewards[_account];
    }

    /// @notice returns reward amount for a specific time range
    function getRewardForDuration() external view override returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    // -- User write type methods --

    /// @notice performs a deposit operation for msg.sender
    /// @dev updates participants rewards
    /// @param _amount deposited amount
    function deposit(uint256 _amount) external override nonReentrant updateReward(msg.sender) validAmount(_amount) {
        require(!paused, "1200");

        uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));
        require(rewardBalance > 0, "3090");

        _totalSupply += _amount;
        require(_totalSupply <= totalSupplyLimit, "3091");
        _balances[msg.sender] += _amount;
        emit Staked(msg.sender, _amount);
    }

    /// @notice claims investment from strategy
    /// @dev updates participants rewards
    /// @param _amount amount to withdraw
    function withdraw(uint256 _amount) public override nonReentrant updateReward(msg.sender) validAmount(_amount) {
        _totalSupply -= _amount;
        _balances[msg.sender] = _balances[msg.sender] - _amount;
        emit Withdrawn(msg.sender, _amount);
        IERC20(tokenIn).safeTransfer(msg.sender, _amount);
    }

    /// @notice claims the rewards for msg.sender
    function claimRewards() public override nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "3092");

        rewards[msg.sender] = 0;
        emit RewardPaid(msg.sender, reward);
        IERC20(rewardToken).safeTransfer(msg.sender, reward);
    }

    /// @notice withdraws the entire investment and claims rewards for msg.sender
    function exit() external override {
        withdraw(_balances[msg.sender]);

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            claimRewards();
        }
    }

    // @dev renounce ownership override to avoid losing contract's ownership
    function renounceOwnership() public pure override {
        revert("1000");
    }

    // -- Modifiers --
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "3000");
        _;
    }

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "2001");
        _;
    }
}
