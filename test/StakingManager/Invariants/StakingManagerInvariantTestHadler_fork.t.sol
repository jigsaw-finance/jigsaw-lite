// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20Metadata, IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { StakingManager } from "../../../src/StakingManager.sol";
import { jPoints } from "../../../src/jPoints.sol";

import { IIonPool } from "../../utils/IIonPool.sol";
import { IStaker } from "../../../src/interfaces/IStaker.sol";
import { IWhitelist } from "../../utils/IWhitelist.sol";

contract StakingManagerInvariantTestHandler is CommonBase, StdCheats, StdUtils {
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal ADMIN;
    address internal wstETH;

    address internal tokenIn;
    address internal rewardToken;
    uint256 internal rewardsDuration;

    StakingManager internal stakingManager;
    IStaker internal staker;
    IIonPool internal ionPool;

    address[] public USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5"))))
    ];

    EnumerableSet.AddressSet internal investorsSet;

    uint256 public totalDeposited;

    uint256 public stakerTotalWithdrawn;
    uint256 public ionTotalWithdrawn;

    uint256 public totalRewardsAmount;
    uint256 public totalRewardsClaimed;

    constructor(StakingManager _stakingManager) {
        stakingManager = _stakingManager;
        ADMIN = stakingManager.defaultAdmin();
        staker = IStaker(stakingManager.staker());
        ionPool = IIonPool(stakingManager.ionPool());
        tokenIn = stakingManager.underlyingAsset();
        rewardToken = stakingManager.rewardToken();
    }

    // Stake for a user
    function stake(uint256 amount, uint256 user_idx) external {
        address user = pickUpUser(user_idx);
        amount = bound(amount, 1, 1000e18);

        stakingManager.stake(amount);

        investorsSet.add(user);
        totalDeposited += amount;
    }

    // Unstake for a user
    function unstake(uint256 user_idx) external {
        address user = pickUpUserFromInvestors(user_idx);
        if (user == address(0)) return;

        uint256 stakerWithdrawAmount = staker.balanceOf(user);
        uint256 ionWithdrawAmount = ionPool.balanceOf(user);

        vm.prank(user, user);
        stakingManager.unstake(user);

        investorsSet.remove(user);
        stakerTotalWithdrawn += stakerWithdrawAmount;
        ionTotalWithdrawn += ionWithdrawAmount;
    }

    // Owner's handlers

    function addRewards(uint256 _rewards) external {
        _rewards = bound(_rewards, 1e18, 1000e18);

        if (investorsSet.length() == 0) return;

        deal(rewardToken, address(staker), _rewards);
        vm.prank(ADMIN, ADMIN);
        staker.addRewards(_rewards);

        totalRewardsAmount += _rewards;
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
            userRewards += staker.earned(USER_ADDRESSES[i]);
        }
    }

    function getIonDeposits() public view returns (uint256 userDeposits) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            userDeposits += ionPool.balanceOf(USER_ADDRESSES[i]);
        }
    }
}
