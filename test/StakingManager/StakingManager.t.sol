// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { Holding } from "../../src/Holding.sol";
import { StakingManager } from "../../src/StakingManager.sol";
import { JigsawPoints } from "../../src/JigsawPoints.sol";

import { IIonPool } from "../utils/IIonPool.sol";
import { IonPool } from "../utils/IonMockPool.sol";
import { IStaker } from "../../src/interfaces/IStaker.sol";
import { IWhitelist } from "../utils/IWhitelist.sol";
import { SampleTokenERC20 } from "../utils/SampleTokenERC20.sol";

contract StakingManagerTest is Test {
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error RenouncingOwnershipProhibited();
    error InvalidAddress();

    event Paused(address account);
    event Unpaused(address account);
    event LockupExpirationDateUpdated(uint256 indexed oldDate, uint256 indexed newDate);

    uint256 constant rewardsDuration = 365 days;

    address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
    address constant USER = address(uint160(uint256(keccak256(bytes("USER")))));

    bytes32 public constant GENERIC_CALLER_ROLE = keccak256("GENERIC_CALLER");

    JigsawPoints rewardToken;
    StakingManager internal stakingManager;
    IStaker internal staker;
    IonPool internal ION_POOL;
    address internal holdingReferenceImplementation;
    address internal wstETH;

    function setUp() public {
        rewardToken = new JigsawPoints({ _initialAdmin: ADMIN, _premintAmount: 100 });
        wstETH = address(new SampleTokenERC20("wstETH", "wstETH", 0));
        ION_POOL = new IonPool();

        stakingManager = new StakingManager({
            _initialOwner: ADMIN,
            _holdingManager: address(uint160(uint256(keccak256(bytes("HOLDING MANAGER"))))),
            _underlyingAsset: wstETH,
            _rewardToken: address(rewardToken),
            _ionPool: address(ION_POOL),
            _rewardsDuration: rewardsDuration
        });

        staker = IStaker(stakingManager.staker());

        holdingReferenceImplementation = address(new Holding());

        vm.startPrank(ADMIN, ADMIN);
        deal(staker.rewardToken(), ADMIN, 1e6 * 10e18);
        IERC20(staker.rewardToken()).approve(address(staker), 1e6 * 10e18);
        staker.addRewards(ADMIN, 1e6 * 10e18);
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

    // Tests if renounceOwnership reverts correctly
    function test_renounceOwnership_when() public {
        vm.prank(ADMIN, ADMIN);
        vm.expectRevert(RenouncingOwnershipProhibited.selector);
        stakingManager.renounceOwnership();
    }

    function test_setLockupExpirationDate_when_unauthorized(address _caller) public {
        vm.assume(_caller != ADMIN);
        vm.prank(_caller, _caller);
        vm.expectRevert();
        stakingManager.setLockupExpirationDate(block.timestamp);
    }

    function test_setLockupExpirationDate_when_authorized(uint256 _days) public {
        uint256 newDate = block.timestamp + bound(_days, 1 days, 365 days);

        vm.expectEmit();
        emit LockupExpirationDateUpdated(stakingManager.lockupExpirationDate(), newDate);
        vm.prank(ADMIN, ADMIN);
        stakingManager.setLockupExpirationDate(newDate);

        assertEq(stakingManager.lockupExpirationDate(), newDate, "New lockupExpirationDate incorrect");
    }
}
