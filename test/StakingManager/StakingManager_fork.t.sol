// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StakingManager } from "../../src/StakingManager.sol";
import { jPoints } from "../../src/jPoints.sol";

import { IIonPool } from "../utils/IIonPool.sol";
import { IStaker } from "../../src/interfaces/IStaker.sol";
import { IWhitelist } from "../utils/IWhitelist.sol";

IIonPool constant ION_POOL = IIonPool(0x0000000000eaEbd95dAfcA37A39fd09745739b78);

contract StakingManagerForkTest is Test {
    error PreLockupPeriodUnstaking();

    uint256 constant STAKING_SUPPLY_LIMIT = 1e34;
    uint256 constant rewardsDuration = 365 days;

    address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
    address constant USER = address(uint160(uint256(keccak256(bytes("USER")))));
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    jPoints rewardToken;
    StakingManager internal stakingManager;
    IStaker internal staker;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        rewardToken = new jPoints({ _initialOwner: ADMIN, _limit: 1e6 });

        stakingManager = new StakingManager({
            _admin: ADMIN,
            _underlyingAsset: wstETH,
            _rewardToken: address(rewardToken),
            _ionPool: address(ION_POOL),
            _rewardsDuration: rewardsDuration
        });

        staker = IStaker(stakingManager.staker());

        vm.startPrank(ADMIN, ADMIN);
        deal(address(rewardToken), address(staker), 1e6 * 10e18);
        staker.addRewards(1e6 * 10e18);
        vm.stopPrank();

        vm.startPrank(ION_POOL.owner());
        ION_POOL.updateIlkDebtCeiling(0, type(uint256).max);
        ION_POOL.updateSupplyCap(type(uint256).max);
        IWhitelist(ION_POOL.whitelist()).approveProtocolWhitelist(address(stakingManager));
        vm.stopPrank();
    }

    function test_stake_when_newUser() public {
        address _user = USER;
        uint256 _amount = 1e18;

        address holding = _stake(_user, _amount);
        uint256 ionBalanceAfterStake = ION_POOL.balanceOf(holding);
        uint256 jPoinsRewardsBalanceAfterStake = staker.earned(holding);

        assertFalse(holding == address(0), "Wrong holding address");
        assertApproxEqAbs(ionBalanceAfterStake, _amount, 10, "Wrong balance in ION after stake");
        assertEq(staker.balanceOf(holding), _amount, "Wrong balance in Staker after stake");

        vm.warp(block.timestamp + 10 days);

        vm.expectRevert(PreLockupPeriodUnstaking.selector);
        stakingManager.unstake(_user);

        vm.warp(block.timestamp + rewardsDuration + 10 days);

        uint256 ionBalanceAfterYear = ION_POOL.balanceOf(holding);
        uint256 jPoinsRewardsBalanceAfterYear = staker.earned(holding);

        assertGt(ionBalanceAfterYear, ionBalanceAfterStake, "Wrong balance in ION after a year");
        assertGt(
            jPoinsRewardsBalanceAfterYear,
            jPoinsRewardsBalanceAfterStake,
            "Wrong jPoints balance in Staker after a year"
        );

        stakingManager.unstake(_user);

        assertEq(IERC20(wstETH).balanceOf(_user), ionBalanceAfterYear, "User didn't receive wstETH after unstake");
        assertEq(
            rewardToken.balanceOf(_user), jPoinsRewardsBalanceAfterYear, "User didn't receive jPoints after unstake"
        );
        assertEq(staker.balanceOf(holding), 0, "Wrong balance in Staker after unstake");
        assertEq(
            staker.userRewardPerTokenPaid(holding),
            jPoinsRewardsBalanceAfterYear,
            "Wrong rewards paid in Staker after unstake"
        );
        assertEq(staker.rewards(holding), 0, "Wrong rewards in Staker after unstake");
    }

    modifier validAmount(uint256 _amount) {
        vm.assume(_amount > 0.0001e18 && _amount <= STAKING_SUPPLY_LIMIT);
        _;
    }

    modifier validAddress(address _addr) {
        vm.assume(_addr != address(0));
        _;
    }

    // -- Utility functions --

    function _stake(address _user, uint256 _amount) public validAmount(_amount) returns (address) {
        deal(wstETH, _user, _amount);

        vm.startPrank(_user, _user);
        IERC20(wstETH).approve(address(stakingManager), _amount);
        stakingManager.stake(_amount);

        return stakingManager._getUserHolding(_user);
    }
}
