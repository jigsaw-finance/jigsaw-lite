// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20Metadata, IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { StakingManager } from "../../../src/StakingManager.sol";
import { JigsawPoints } from "../../../src/JigsawPoints.sol";

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
        ADMIN = stakingManager.owner();
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
    uint256 public ionTotalDeposited;

    uint256 public stakerTotalWithdrawn;
    uint256 public ionTotalWithdrawn;

    uint256 public totalRewardsAmount;
    uint256 public totalRewardsClaimed;

    constructor(StakingManager _stakingManager) {
        stakingManager = _stakingManager;
        ADMIN = stakingManager.owner();
        staker = IStaker(stakingManager.staker());
        ionPool = IIonPool(stakingManager.ionPool());
        wstETH = stakingManager.underlyingAsset();
        rewardToken = stakingManager.rewardToken();

        vm.warp(stakingManager.lockupExpirationDate() + 1);
    }

    // Unstake for a user
    function unstake(uint256 user_idx) external {
        if (investorsSet.length() == 0) {
            _initRandomUser(user_idx);
        }
        address user = investorsSet.at(bound(user_idx, 0, investorsSet.length() - 1));

        uint256 stakerWithdrawAmount = staker.balanceOf(userHolding[user]);
        uint256 ionWithdrawAmount = ionPool.balanceOf(userHolding[user]);

        vm.prank(user, user);
        stakingManager.unstake(user);

        investorsSet.remove(user);
        stakerTotalWithdrawn += stakerWithdrawAmount;
        ionTotalWithdrawn += ionWithdrawAmount + 1;
    }

    // Utility functions
    function _initRandomUser(uint256 id) private returns (address _user) {
        _user = vm.addr(uint256(keccak256(abi.encodePacked(id))));
        USER_ADDRESSES.push(_user);
        _stake(_user, bound(id, 0.1e18, 1e18));
    }

    function _stake(address _user, uint256 _amount) private {
        deal(wstETH, _user, _amount);

        vm.startPrank(_user, _user);
        IERC20(wstETH).approve(address(stakingManager), _amount);
        stakingManager.stake(_amount);
        vm.stopPrank();

        userHolding[_user] = stakingManager.getUserHolding(_user);
        investorsSet.add(_user);

        totalDeposited += _amount;
        ionTotalDeposited += ionPool.balanceOf(userHolding[_user]);

        // fast forward random amount to generate some yield
        vm.warp(stakingManager.lockupExpirationDate() + bound(_amount, 1 days, 60 days));
    }
}
