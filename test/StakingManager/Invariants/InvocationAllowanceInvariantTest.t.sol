// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StakingManager } from "../../../src/StakingManager.sol";
import { JigsawPoints } from "../../../src/JigsawPoints.sol";

import { IonPool } from "../../utils/IonMockPool.sol";
import { SampleTokenERC20 } from "../../utils/SampleTokenERC20.sol";
import { IStaker } from "../../../src/interfaces/IStaker.sol";

address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
address constant GENERIC_CALLER = address(uint160(uint256(keccak256(bytes("GENERIC_CALLER")))));

contract InvocationAllowanceInvariantTest is Test {
    address internal holdingReferenceImplementation;
    address internal wstETH;
    address internal callableContract;

    JigsawPoints rewardToken;
    StakingManager internal stakingManager;
    IonPool internal ION_POOL;
    InvocationHandler internal invocationHandler;
    IStaker internal staker;

    address[] USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5"))))
    ];

    function setUp() external {
        rewardToken = new JigsawPoints({ _initialAdmin: ADMIN, _premintAmount: 100 });
        callableContract = address(rewardToken);
        wstETH = address(new SampleTokenERC20("wstETH", "wstETH", 0));
        ION_POOL = new IonPool();

        stakingManager = new StakingManager({
            _admin: ADMIN,
            _underlyingAsset: wstETH,
            _rewardToken: address(rewardToken),
            _ionPool: address(ION_POOL),
            _rewardsDuration: 365 days
        });

        vm.startPrank(ADMIN, ADMIN);
        staker = IStaker(stakingManager.staker());
        deal(address(rewardToken), address(staker), 1e6 * 10e18);
        staker.addRewards(1e6 * 10e18);

        stakingManager.grantRole(keccak256("GENERIC_CALLER"), GENERIC_CALLER);
        vm.stopPrank();

        invocationHandler = new InvocationHandler(stakingManager, callableContract, wstETH, USER_ADDRESSES);
        targetContract(address(invocationHandler));
    }

    function invariant_stakingManager_invocationAllowance_equals_tracked_invocationAllowance() public {
        assertEq(getAllowancesAmountInStakingManager(), getAllowancesAmountInHandler(), "Allowances incorrect");
    }

    function getAllowancesAmountInHandler() private view returns (uint256 totalAllowances) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalAllowances += invocationHandler.allowances(USER_ADDRESSES[i]);
        }
    }

    function getAllowancesAmountInStakingManager() private view returns (uint256 totalAllowances) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalAllowances += stakingManager.getInvocationAllowance({
                _user: USER_ADDRESSES[i],
                _genericCaller: GENERIC_CALLER,
                _callableContract: callableContract
            });
        }
    }
}

contract InvocationHandler is CommonBase, StdCheats, StdUtils {
    error InvocationNotAllowed(address caller);

    StakingManager internal stakingManager;

    address internal callableContract;
    address internal wstETH;

    mapping(address => uint256) public allowances;
    address[] internal USER_ADDRESSES;

    constructor(StakingManager _stakingManager, address _callableContract, address _wstETH, address[] memory _users) {
        stakingManager = _stakingManager;
        callableContract = _callableContract;
        wstETH = _wstETH;
        USER_ADDRESSES = _users;
    }

    function setAllowance(uint256 user_idx, uint256 _allowance) public {
        _allowance = bound(_allowance, 0, 1e5);
        address user = USER_ADDRESSES[bound(user_idx, 0, USER_ADDRESSES.length - 1)];

        if (stakingManager.getUserHolding(user) == address(0)) initUser(user);

        vm.prank(user, user);
        stakingManager.setInvocationAllowance({
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
        stakingManager.invokeHolding(
            stakingManager.getUserHolding(user), callableContract, abi.encodeWithSignature("decimals()")
        );
        vm.stopPrank();

        allowances[user]--;
    }

    function initUser(address _user) private {
        vm.startPrank(_user, _user);
        deal(wstETH, _user, 100e18);
        IERC20(wstETH).approve(address(stakingManager), 100e18);
        stakingManager.stake(100e18);
        vm.stopPrank();
    }
}
