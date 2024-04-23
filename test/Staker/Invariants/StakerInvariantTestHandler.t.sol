// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20Metadata, IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SampleTokenERC20 } from "../../utils/SampleTokenERC20.sol";
import { StakerWrapper as Staker } from "../../utils/StakerWrapper.sol";

import { IStaker } from "../../../src/interfaces/IStaker.sol";

contract StakerInvariantTestHandler is CommonBase, StdCheats, StdUtils {
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal OWNER;
    Staker internal staker;
    address internal tokenIn;
    address internal rewardToken;

    address[] public USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5"))))
    ];

    EnumerableSet.AddressSet internal investorsSet;

    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalRewardsAmount;
    uint256 public totalRewardsClaimed;

    constructor(address _owner, Staker _staker, address _tokenIn, address _rewardToken) {
        OWNER = _owner;
        staker = _staker;
        tokenIn = _tokenIn;
        rewardToken = _rewardToken;

        addRewards(100e18);
    }

    // Make a deposit for a user
    function deposit(uint256 amount, uint256 user_idx) public {
        address user = pickUpUser(user_idx);

        amount = bound(amount, 100_000, 1000e18);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(user, amount);

        totalDeposited += amount;
        investorsSet.add(user);

        vm.warp(block.timestamp + 2 days);
    }

    // Withdraw deposit for a user
    function withdraw(uint256 amount, uint256 user_idx) external {
        address user = pickUpUserFromInvestors(user_idx);
        if (user == address(0)) return;

        uint256 userBalance = staker.balanceOf(user);
        uint256 withdrawAmount = bound(amount, 1, userBalance);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.withdraw_wrapper(user, withdrawAmount);

        if (withdrawAmount == userBalance) investorsSet.remove(user);
        if (investorsSet.length() == 0) {
            deposit(amount, user_idx);
            vm.warp(block.timestamp + 2 days);
        }
        totalWithdrawn += withdrawAmount;
    }

    // Claim rewards for a user
    function claimRewards(uint256 user_idx) external {
        address user = pickUpUserFromInvestors(user_idx);
        uint256 userRewards = staker.earned(user);

        if (userRewards == 0) return;

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.claimRewards_wrapper(user, user);

        totalRewardsClaimed += userRewards;
    }

    // Owner's handlers

    function addRewards(uint256 _rewards) private {
        _rewards = bound(_rewards, 1e18, 10e18);

        vm.startPrank(OWNER, OWNER);
        deal(rewardToken, OWNER, _rewards);
        IERC20Metadata(rewardToken).approve(address(staker), _rewards);
        staker.addRewards(OWNER, _rewards);

        totalRewardsAmount += _rewards;
        vm.stopPrank();
    }

    // Utility functions

    function pickUpUser(uint256 user_idx) public view returns (address) {
        user_idx = user_idx % USER_ADDRESSES.length;
        return USER_ADDRESSES[user_idx];
    }

    function pickUpUserFromInvestors(uint256 user_idx) public view returns (address) {
        uint256 investorsNumber = investorsSet.length();
        if (investorsNumber == 0) return address(0);

        user_idx = bound(user_idx, 0, investorsNumber - 1);

        return investorsSet.at(user_idx);
    }

    function getUserRewards() public view returns (uint256 userRewards) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            userRewards += IERC20Metadata(rewardToken).balanceOf(USER_ADDRESSES[i]);
        }
    }
}
