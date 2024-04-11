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

contract StakingManagerForkTest is Test {
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error RenouncingDefaultAdminRoleProhibited();
    error InvalidAddress();
    error InvocationNotAllowed(address caller);

    event Paused(address account);
    event Unpaused(address account);
    event LockupExpirationDateUpdated(uint256 indexed oldDate, uint256 indexed newDate);
    event HoldingImplementationReferenceUpdated(address indexed _newReference);
    event InvocationAllowanceSet(
        address holding, address genericCaller, address callableContract, uint256 invocationsAllowance
    );

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
            _admin: ADMIN,
            _underlyingAsset: wstETH,
            _rewardToken: address(rewardToken),
            _ionPool: address(ION_POOL),
            _rewardsDuration: rewardsDuration
        });

        staker = IStaker(stakingManager.staker());

        holdingReferenceImplementation = address(new Holding());

        vm.startPrank(ADMIN, ADMIN);
        deal(address(rewardToken), address(staker), 1e6 * 10e18);
        staker.addRewards(1e6 * 10e18);
        vm.stopPrank();
    }

    // Tests if invokeHolding reverts correctly when caller doesn't have GENERIC_CALLER_ROLE
    function test_invokeHolding_when_callerWithoutRole(address _caller) public {
        address holding = address(uint160(uint256(keccak256("random holding"))));

        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, _caller, GENERIC_CALLER_ROLE));
        stakingManager.invokeHolding(holding, address(rewardToken), bytes(""));
    }

    // Tests if invokeHolding reverts correctly when caller has GENERIC_CALLER_ROLE but doesn't have allowance for
    // generic call
    function test_invokeHolding_when_noAllowanceForInvocation(address _caller) public {
        address holding = Clones.clone(holdingReferenceImplementation);
        Holding(holding).init({ _stakingManager: address(stakingManager), _ionPool: address(ION_POOL) });

        address callableContract = address(rewardToken);

        vm.prank(ADMIN, ADMIN);
        stakingManager.grantRole(keccak256("GENERIC_CALLER"), _caller);

        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(InvocationNotAllowed.selector, _caller));
        (bool success,) = stakingManager.invokeHolding(holding, callableContract, abi.encodeWithSignature("decimals()"));
    }

    // Tests if invokeHolding works correctly when caller has GENERIC_CALLER_ROLE and has allowance for generic call
    function test_invokeHolding_when_authorized(address _caller, address _user, uint256 allowance) public {
        vm.assume(_user != address(0));
        vm.assume(_caller != address(0));
        vm.assume(allowance != 0);

        address callableContract = address(rewardToken);

        vm.startPrank(_user, _user);
        deal(wstETH, _user, 100e18);
        IERC20(wstETH).approve(address(stakingManager), 100e18);
        stakingManager.stake(100e18);
        address holding = stakingManager.getUserHolding(_user);
        vm.stopPrank();

        vm.prank(ADMIN, ADMIN);
        stakingManager.grantRole(keccak256("GENERIC_CALLER"), _caller);

        vm.expectEmit();
        emit InvocationAllowanceSet(holding, _caller, callableContract, allowance);
        vm.prank(_user, _user);
        stakingManager.setInvocationAllowance({
            _genericCaller: _caller,
            _callableContract: callableContract,
            _invocationsAllowance: allowance
        });

        assertEq(
            stakingManager.getInvocationAllowance({
                _user: _user,
                _genericCaller: _caller,
                _callableContract: callableContract
            }),
            allowance,
            "Allowance set incorrect"
        );

        vm.prank(_caller, _caller);
        (bool success,) = stakingManager.invokeHolding(holding, callableContract, abi.encodeWithSignature("decimals()"));

        assertEq(success, true, "invokeHolding failed");
        assertEq(
            stakingManager.getInvocationAllowance({
                _user: _user,
                _genericCaller: _caller,
                _callableContract: callableContract
            }),
            allowance - 1,
            "Allowance wrong after invocation"
        );
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

    // Tests if beginDefaultAdminTransfer reverts correctly when transferred to address(0)
    function test_beginDefaultAdminTransfer_when_address0() public {
        vm.prank(ADMIN, ADMIN);
        vm.expectRevert(RenouncingDefaultAdminRoleProhibited.selector);
        stakingManager.beginDefaultAdminTransfer(address(0));
    }

    // Tests if beginDefaultAdminTransfer reverts correctly when caller is unauthorized
    function test_beginDefaultAdminTransfer_when_unauthorized(address _caller) public {
        vm.assume(_caller != address(0));
        vm.assume(_caller != ADMIN);

        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, _caller, 0x0));
        stakingManager.beginDefaultAdminTransfer(address(1));
    }

    // Tests if renouncing ownership works correctly
    function test_beginDefaultAdminTransfer_when_authorized() public {
        address newAdmin = address(uint160(uint256(keccak256(bytes("NEW ADMIN")))));

        vm.prank(ADMIN, ADMIN);
        stakingManager.beginDefaultAdminTransfer(newAdmin);

        (address _newAdmin,) = stakingManager.pendingDefaultAdmin();
        vm.assertEq(_newAdmin, newAdmin, "Incorrect pendingDefaultAdmin");

        vm.warp(block.timestamp + stakingManager.defaultAdminDelay() + 1);

        vm.prank(newAdmin, newAdmin);
        stakingManager.acceptDefaultAdminTransfer();

        vm.assertEq(stakingManager.defaultAdmin(), newAdmin, "Incorrect new admin");
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

    function test_setHoldingImplementationReference_when_unauthorized(address _caller) public {
        vm.assume(_caller != ADMIN);
        vm.prank(_caller, _caller);
        vm.expectRevert();
        stakingManager.setHoldingImplementationReference(address(1));
    }

    function test_setHoldingImplementationReference_when_invalidImplementationAddress() public {
        vm.prank(ADMIN, ADMIN);
        vm.expectRevert(InvalidAddress.selector);
        stakingManager.setHoldingImplementationReference(address(0));
    }

    function test_setHoldingImplementationReference_when_authorized(address _newRef) public {
        vm.assume(_newRef != address(0));

        vm.expectEmit();
        emit HoldingImplementationReferenceUpdated(_newRef);
        vm.prank(ADMIN, ADMIN);
        stakingManager.setHoldingImplementationReference(_newRef);

        assertEq(
            stakingManager.holdingImplementationReference(), _newRef, "New holdingImplementationReference incorrect"
        );
    }
}
