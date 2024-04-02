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
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    event Paused(address account);
    event Unpaused(address account);

    uint256 constant rewardsDuration = 365 days;

    address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
    address constant USER = address(uint160(uint256(keccak256(bytes("USER")))));
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    jPoints rewardToken;
    StakingManager internal stakingManager;
    IStaker internal staker;

    function setUp() public {
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
    }

    // Tests setting contract paused from non-Owner's address
    function test_pause_when_unauthorized(address _caller) public {
        vm.assume(_caller != ADMIN);
        vm.prank(_caller, _caller);
        vm.expectRevert();

        stakingManager.pause();
    }

    // Tests setting contract paused from non-Owner's address
    function test_unpause_when_unauthorized(address _caller) public {
        vm.assume(_caller != ADMIN);

        vm.prank(ADMIN, ADMIN);
        stakingManager.pause();

        vm.prank(_caller, _caller);
        vm.expectRevert();

        stakingManager.pause();
    }

    // Tests setting contract paused from Owner's address
    function test_setPaused_when_authorized() public {
        //Sets contract paused and checks if after pausing contract is paused and event is emitted
        vm.startPrank(ADMIN, ADMIN);
        vm.expectEmit();
        emit Paused(ADMIN);
        stakingManager.pause();
        assertEq(stakingManager.paused(), true);

        //Sets contract unpaused and checks if after pausing contract is unpaused and event is emitted
        vm.expectEmit();
        emit Unpaused(ADMIN);
        stakingManager.unpause();
        assertEq(stakingManager.paused(), false);
        vm.stopPrank();
    }
}
