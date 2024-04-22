// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { HoldingManager } from "../../../src/HoldingManager.sol";

import { SampleTokenERC20 } from "../../utils/SampleTokenERC20.sol";

address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
address constant GENERIC_CALLER = address(uint160(uint256(keccak256(bytes("GENERIC_CALLER")))));
address constant STAKING_MANAGER = address(uint160(uint256(keccak256(bytes("STAKING_MANAGER")))));

contract InvocationAllowanceInvariantTest is Test {
    address internal callableContract;

    HoldingManager internal holdingManager;
    InvocationHandler internal invocationHandler;

    address[] USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5"))))
    ];

    function setUp() external {
        holdingManager = new HoldingManager(ADMIN);
        callableContract = address(new SampleTokenERC20("MOCK", "MK", 0));

        vm.startPrank(ADMIN, ADMIN);
        holdingManager.grantRole(holdingManager.GENERIC_CALLER_ROLE(), GENERIC_CALLER);
        holdingManager.grantRole(holdingManager.STAKING_MANAGER_ROLE(), STAKING_MANAGER);
        vm.stopPrank();

        invocationHandler = new InvocationHandler(holdingManager, callableContract, USER_ADDRESSES);
        targetContract(address(invocationHandler));
    }

    function invariant_holdingManager_invocationAllowance_equals_tracked_invocationAllowance() public view {
        assertEq(getAllowancesAmountInHoldingManager(), getAllowancesAmountInHandler(), "Allowances incorrect");
    }

    function getAllowancesAmountInHandler() private view returns (uint256 totalAllowances) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalAllowances += invocationHandler.allowances(USER_ADDRESSES[i]);
        }
    }

    function getAllowancesAmountInHoldingManager() private view returns (uint256 totalAllowances) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalAllowances += holdingManager.getInvocationAllowance({
                _user: USER_ADDRESSES[i],
                _genericCaller: GENERIC_CALLER,
                _callableContract: callableContract
            });
        }
    }
}

contract InvocationHandler is CommonBase, StdCheats, StdUtils {
    HoldingManager internal holdingManager;
    address internal callableContract;

    mapping(address => uint256) public allowances;
    address[] internal USER_ADDRESSES;

    constructor(HoldingManager _holdingManager, address _callableContract, address[] memory _users) {
        holdingManager = _holdingManager;
        callableContract = _callableContract;
        USER_ADDRESSES = _users;
    }

    function setAllowance(uint256 user_idx, uint256 _allowance) public {
        _allowance = bound(_allowance, 0, 1e5);
        address user = USER_ADDRESSES[bound(user_idx, 0, USER_ADDRESSES.length - 1)];

        if (holdingManager.getUserHolding(user) == address(0)) initUser(user);

        vm.prank(user, user);
        holdingManager.setInvocationAllowance({
            _genericCaller: GENERIC_CALLER,
            _callableContract: callableContract,
            _invocationsAllowance: _allowance
        });

        allowances[user] = _allowance;
    }

    function invokeHolding(uint256 user_idx) public {
        address user = USER_ADDRESSES[bound(user_idx, 0, USER_ADDRESSES.length - 1)];

        if (allowances[user] == 0) return;

        vm.startPrank(GENERIC_CALLER, GENERIC_CALLER);
        holdingManager.invokeHolding(
            holdingManager.getUserHolding(user), callableContract, 0, abi.encodeWithSignature("decimals()")
        );
        vm.stopPrank();

        allowances[user]--;
    }

    function initUser(address _user) private {
        vm.startPrank(STAKING_MANAGER, STAKING_MANAGER);
        holdingManager.createHolding(_user);
        vm.stopPrank();
    }
}
