// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import { JigsawPoints } from "../../src/JigsawPoints.sol";

contract JigsawPointsForkTest is Test {
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error RenouncingDefaultAdminRoleProhibited();
    error InvalidAmount();

    address internal ADMIN = vm.addr(uint256(keccak256(bytes("ADMIN"))));
    address internal BURNER = vm.addr(uint256(keccak256(bytes("BURNER"))));
    bytes32 internal BURNER_ROLE = keccak256("BURNER_ROLE");
    uint256 internal premintAmount = 1e6;

    JigsawPoints internal jPoints;

    function setUp() public {
        jPoints = new JigsawPoints(ADMIN, premintAmount);
    }

    // Tests that initial state of the contract is correct
    function test_initial_state() public view {
        assertEq(jPoints.defaultAdmin(), ADMIN, "Admin set up failed");
        assertEq(jPoints.balanceOf(ADMIN), premintAmount * 10 ** jPoints.decimals(), "Premint failed");
    }

    // Test if mint function reverts correctly when caller is unauthorized
    function test_mint_when_unauthorized(address _caller) public {
        vm.assume(_caller != ADMIN);
        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, _caller, 0x0));
        jPoints.mint(address(1), 1);
    }

    // Test if mint function works correctly when authorized
    function test_mint_when_authorized(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_to != ADMIN);

        _amount = bound(_amount, 1, type(uint256).max - jPoints.totalSupply());

        vm.prank(ADMIN, ADMIN);
        jPoints.mint(_to, _amount);

        assertEq(jPoints.balanceOf(_to), _amount, "Mint failed");
    }

    // Test if burnFrom function reverts correctly when caller is unauthorized
    function test_burnFrom_when_unauthorized(address _caller) public {
        vm.assume(_caller != address(0));

        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, _caller, BURNER_ROLE));
        jPoints.burnFrom(address(1), 1);
    }

    // Test if burnFrom function reverts correctly when provided amount is invalid
    function test_burnFrom_when_invalidAmount() public {
        vm.prank(ADMIN, ADMIN);
        jPoints.grantRole(BURNER_ROLE, BURNER);

        vm.prank(BURNER, BURNER);
        vm.expectRevert(InvalidAmount.selector);
        jPoints.burnFrom(address(1), 0);
    }

    // Test if burnFrom function works correctly when authorized
    function test_burnFrom_when_authorized(address _from, uint256 _amount) public {
        vm.assume(_from != address(0));
        vm.assume(_from != ADMIN);

        uint256 initialSupply = jPoints.totalSupply();
        _amount = bound(_amount, 1, type(uint256).max - initialSupply);

        vm.startPrank(ADMIN, ADMIN);
        jPoints.mint(_from, _amount);
        jPoints.grantRole(BURNER_ROLE, BURNER);
        vm.stopPrank();

        vm.prank(BURNER, BURNER);
        jPoints.burnFrom(_from, _amount);

        assertEq(jPoints.balanceOf(_from), 0, "Balance failed to change after burn");
        assertEq(jPoints.totalSupply(), initialSupply, "Total supply failed to change after burn");
    }

    // Tests if beginDefaultAdminTransfer reverts correctly when transferred to address(0)
    function test_beginDefaultAdminTransfer_when_address0() public {
        vm.prank(ADMIN, ADMIN);
        vm.expectRevert(RenouncingDefaultAdminRoleProhibited.selector);
        jPoints.beginDefaultAdminTransfer(address(0));
    }

    // Tests if beginDefaultAdminTransfer reverts correctly when caller is unauthorized
    function test_beginDefaultAdminTransfer_when_unauthorized(address _caller) public {
        vm.assume(_caller != address(0));
        vm.assume(_caller != ADMIN);

        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, _caller, 0x0));
        jPoints.beginDefaultAdminTransfer(address(1));
    }

    // Tests if renouncing ownership works correctly
    function test_beginDefaultAdminTransfer_when_authorized() public {
        address newAdmin = address(uint160(uint256(keccak256(bytes("NEW ADMIN")))));

        vm.prank(ADMIN, ADMIN);
        jPoints.beginDefaultAdminTransfer(newAdmin);

        (address _newAdmin,) = jPoints.pendingDefaultAdmin();
        vm.assertEq(_newAdmin, newAdmin, "Incorrect pendingDefaultAdmin");

        vm.warp(block.timestamp + jPoints.defaultAdminDelay() + 1);

        vm.prank(newAdmin, newAdmin);
        jPoints.acceptDefaultAdminTransfer();

        vm.assertEq(jPoints.defaultAdmin(), newAdmin, "Incorrect new admin");
    }
}
