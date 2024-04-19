// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import { HoldingManager } from "../../src/HoldingManager.sol";

import { SampleTokenERC20 } from "../utils/SampleTokenERC20.sol";

contract HoldingManagerTest is Test {
    // -- Errors --
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error InvalidAddress();
    error InvocationNotAllowed(address caller);
    error RenouncingDefaultAdminRoleProhibited();

    // -- Events --
    event HoldingImplementationReferenceUpdated(address indexed _newReference);
    event InvocationAllowanceSet(
        address holding, address genericCaller, address callableContract, uint256 invocationsAllowance
    );

    HoldingManager internal holdingManager;
    address internal ERC20Mock;
    address internal ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));

    function setUp() external {
        holdingManager = new HoldingManager(ADMIN);
        ERC20Mock = address(new SampleTokenERC20("MOCK", "MK", 0));
    }

    // Tests if invokeHolding reverts correctly when caller doesn't have GENERIC_CALLER_ROLE
    function test_invokeHolding_when_callerWithoutRole(address _caller) public {
        address holding = address(uint160(uint256(keccak256("random holding"))));

        vm.startPrank(_caller, _caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, _caller, holdingManager.GENERIC_CALLER_ROLE()
            )
        );
        holdingManager.invokeHolding(holding, ERC20Mock, bytes(""));

        vm.stopPrank();
    }

    // Tests if invokeHolding reverts correctly when caller has GENERIC_CALLER_ROLE but doesn't have allowance for
    // generic call
    function test_invokeHolding_when_noAllowanceForInvocation(address _caller, address _stakingManager) public {
        vm.startPrank(ADMIN, ADMIN);
        holdingManager.grantRole(holdingManager.GENERIC_CALLER_ROLE(), _caller);
        holdingManager.grantRole(holdingManager.STAKING_MANAGER_ROLE(), _stakingManager);
        vm.stopPrank();

        address callableContract = ERC20Mock;

        vm.prank(_stakingManager, _stakingManager);
        address holding = holdingManager.createHolding(address(101));

        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(InvocationNotAllowed.selector, _caller));
        holdingManager.invokeHolding(holding, callableContract, abi.encodeWithSignature("decimals()"));
    }

    // Tests if invokeHolding works correctly when caller has GENERIC_CALLER_ROLE and has allowance for generic call
    function test_invokeHolding_when_authorized(
        address _caller,
        address _user,
        uint256 allowance,
        address _stakingManager
    )
        public
    {
        vm.assume(_user != address(0));
        vm.assume(_caller != address(0));
        vm.assume(allowance != 0);

        address callableContract = ERC20Mock;

        vm.startPrank(ADMIN, ADMIN);
        holdingManager.grantRole(holdingManager.GENERIC_CALLER_ROLE(), _caller);
        holdingManager.grantRole(holdingManager.STAKING_MANAGER_ROLE(), _stakingManager);
        vm.stopPrank();

        vm.prank(_stakingManager, _stakingManager);
        address holding = holdingManager.createHolding(_user);

        vm.expectEmit();
        emit InvocationAllowanceSet(holding, _caller, callableContract, allowance);
        vm.prank(_user, _user);
        holdingManager.setInvocationAllowance({
            _genericCaller: _caller,
            _callableContract: callableContract,
            _invocationsAllowance: allowance
        });

        assertEq(
            holdingManager.getInvocationAllowance({
                _user: _user,
                _genericCaller: _caller,
                _callableContract: callableContract
            }),
            allowance,
            "Allowance set incorrect"
        );

        vm.prank(_caller, _caller);
        (bool success,) = holdingManager.invokeHolding(holding, callableContract, abi.encodeWithSignature("decimals()"));

        assertEq(success, true, "invokeHolding failed");
        assertEq(
            holdingManager.getInvocationAllowance({
                _user: _user,
                _genericCaller: _caller,
                _callableContract: callableContract
            }),
            allowance - 1,
            "Allowance wrong after invocation"
        );
    }

    function test_setHoldingImplementationReference_when_unauthorized(address _caller) public {
        vm.assume(_caller != ADMIN);
        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, _caller, 0x0));
        holdingManager.setHoldingImplementationReference(address(1));
    }

    function test_setHoldingImplementationReference_when_invalidImplementationAddress() public {
        vm.prank(ADMIN, ADMIN);
        vm.expectRevert(InvalidAddress.selector);
        holdingManager.setHoldingImplementationReference(address(0));
    }

    function test_setHoldingImplementationReference_when_authorized(address _newRef) public {
        vm.assume(_newRef != address(0));

        vm.expectEmit();
        emit HoldingImplementationReferenceUpdated(_newRef);
        vm.prank(ADMIN, ADMIN);
        holdingManager.setHoldingImplementationReference(_newRef);

        assertEq(
            holdingManager.holdingImplementationReference(), _newRef, "New holdingImplementationReference incorrect"
        );
    }

    // Tests if beginDefaultAdminTransfer reverts correctly when transferred to address(0)
    function test_beginDefaultAdminTransfer_when_address0() public {
        vm.prank(ADMIN, ADMIN);
        vm.expectRevert(RenouncingDefaultAdminRoleProhibited.selector);
        holdingManager.beginDefaultAdminTransfer(address(0));
    }

    // Tests if beginDefaultAdminTransfer reverts correctly when caller is unauthorized
    function test_beginDefaultAdminTransfer_when_unauthorized(address _caller) public {
        vm.assume(_caller != address(0));
        vm.assume(_caller != ADMIN);

        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, _caller, 0x0));
        holdingManager.beginDefaultAdminTransfer(address(1));
    }

    // Tests if renouncing ownership works correctly
    function test_beginDefaultAdminTransfer_when_authorized() public {
        address newAdmin = address(uint160(uint256(keccak256(bytes("NEW ADMIN")))));

        vm.prank(ADMIN, ADMIN);
        holdingManager.beginDefaultAdminTransfer(newAdmin);

        (address _newAdmin,) = holdingManager.pendingDefaultAdmin();
        vm.assertEq(_newAdmin, newAdmin, "Incorrect pendingDefaultAdmin");

        vm.warp(block.timestamp + holdingManager.defaultAdminDelay() + 1);

        vm.prank(newAdmin, newAdmin);
        holdingManager.acceptDefaultAdminTransfer();

        vm.assertEq(holdingManager.defaultAdmin(), newAdmin, "Incorrect new admin");
    }
}
