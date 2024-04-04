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
    }

    // Stake for a user
    function stake(uint256 user_idx, uint256 _amount) external {
        uint256 amount = bound(_amount, 0.00001e18, 10e18);
        address user = pickUpUser(user_idx);

        _stake(user, amount);

        investorsSet.add(user);
        totalDeposited += amount;
    }

    // Unstake for a user
    function unstake(uint256 user_idx) external timeMachine {
        address user = pickUpUserFromInvestors(user_idx);
        if (user == address(0)) return;

        uint256 stakerWithdrawAmount = staker.balanceOf(userHolding[user]);
        if (stakerWithdrawAmount == 0) return;

        vm.prank(user, user);
        stakingManager.unstake(user);

        investorsSet.remove(user);
        stakerTotalWithdrawn += stakerWithdrawAmount;
    }

    // Utility functions

    function pickUpUser(uint256 user_idx) internal view returns (address) {
        // return USER_ADDRESSES[user_idx % USER_ADDRESSES.length];
        return USER_ADDRESSES[bound(user_idx, 0, USER_ADDRESSES.length - 1)];
    }

    function pickUpUserFromInvestors(uint256 user_idx) internal view returns (address) {
        uint256 investorsNumber = investorsSet.length();
        if (investorsNumber == 0) return address(0);
        return investorsSet.at(bound(user_idx, 0, investorsNumber - 1));
    }

    function _stake(address _user, uint256 _amount) internal {
        deal(wstETH, _user, _amount);

        vm.startPrank(_user, _user);
        IERC20(wstETH).approve(address(stakingManager), _amount);
        stakingManager.stake(_amount);
        vm.stopPrank();

        userHolding[_user] = stakingManager.getUserHolding(_user);
    }

    // Modifiers

    // Change block.timestamp to allow unstaking
    modifier timeMachine() {
        uint256 currentTimestamp = block.timestamp;
        vm.warp(
            currentTimestamp < stakingManager.lockupExpirationDate()
                ? stakingManager.lockupExpirationDate() + 1
                : currentTimestamp
        );
        _;
        // vm.warp(currentTimestamp);
    }
}
