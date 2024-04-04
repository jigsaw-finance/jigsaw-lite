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

contract StakeHandler is CommonBase, StdCheats, StdUtils {
    address internal ADMIN;
    address internal wstETH;
    address internal rewardToken;
    uint256 internal rewardsDuration;

    StakingManager internal stakingManager;
    IStaker internal staker;
    IIonPool internal ionPool;

    address[] public USER_ADDRESSES;
    mapping(address => address) userHolding;
    uint256 public totalDeposited;

    constructor(StakingManager _stakingManager, address[] memory _users) {
        stakingManager = _stakingManager;
        ADMIN = stakingManager.defaultAdmin();
        staker = IStaker(stakingManager.staker());
        ionPool = IIonPool(stakingManager.ionPool());
        wstETH = stakingManager.underlyingAsset();
        rewardToken = stakingManager.rewardToken();
        USER_ADDRESSES = _users;
    }

    // Stake for a user
    function stake(uint256 user_idx, uint256 _amount) external {
        uint256 amount = bound(_amount, 0.1e18, 1e18);
        address user = USER_ADDRESSES[bound(user_idx, 0, USER_ADDRESSES.length - 1)];

        _stake(user, amount);

        totalDeposited += amount;
    }

    // Utility functions

    function _stake(address _user, uint256 _amount) internal {
        deal(wstETH, _user, _amount);

        vm.startPrank(_user, _user);
        IERC20(wstETH).approve(address(stakingManager), _amount);
        stakingManager.stake(_amount);
        vm.stopPrank();

        userHolding[_user] = stakingManager.getUserHolding(_user);
    }
}

contract UnstakeHandler is CommonBase, StdCheats, StdUtils {
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal ADMIN;
    address internal wstETH;
    address internal rewardToken;
    uint256 internal rewardsDuration;

    StakingManager internal stakingManager;
    IStaker internal staker;
    IIonPool internal ionPool;

    address[] public USER_ADDRESSES;
    mapping(address => address) userHolding;

    EnumerableSet.AddressSet internal investorsSet;

    uint256 public totalDeposited;

    uint256 public stakerTotalWithdrawn;
    // uint256 public ionTotalWithdrawn;

    uint256 public totalRewardsAmount;
    uint256 public totalRewardsClaimed;

    constructor(StakingManager _stakingManager, address[] memory _users) {
        stakingManager = _stakingManager;
        ADMIN = stakingManager.defaultAdmin();
        staker = IStaker(stakingManager.staker());
        ionPool = IIonPool(stakingManager.ionPool());
        wstETH = stakingManager.underlyingAsset();
        rewardToken = stakingManager.rewardToken();
        USER_ADDRESSES = _users;

        _initAllUsers();

        vm.warp(stakingManager.lockupExpirationDate() + 1);
    }

    // Unstake for a user
    function unstake(uint256 user_idx) external {
        address user = pickUpUserFromInvestors(user_idx);

        uint256 stakerWithdrawAmount = staker.balanceOf(userHolding[user]);
        if (stakerWithdrawAmount == 0) return;
        if (ionPool.balanceOf(userHolding[user]) == 0) return;

        vm.prank(user, user);
        stakingManager.unstake(user);

        investorsSet.remove(user);
        stakerTotalWithdrawn += stakerWithdrawAmount;
    }

    // Utility functions
    function _initAllUsers() private {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            address _user = USER_ADDRESSES[i];
            uint256 _amount = bound(uint256(18_937_232), 0.1e18, 1e18);
            deal(wstETH, _user, _amount);

            vm.startPrank(_user, _user);
            IERC20(wstETH).approve(address(stakingManager), _amount);
            stakingManager.stake(_amount);
            vm.stopPrank();

            userHolding[_user] = stakingManager.getUserHolding(_user);

            investorsSet.add(_user);
            totalDeposited += _amount;
        }
    }

    function pickUpUserFromInvestors(uint256 user_idx) internal view returns (address) {
        return investorsSet.at(bound(user_idx, 0, investorsSet.length() - 1));
    }
}
