// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { HoldingManager } from "../../../src/HoldingManager.sol";
import { StakingManager } from "../../../src/StakingManager.sol";
import { JigsawPoints } from "../../../src/JigsawPoints.sol";

import { IIonPool } from "../../utils/IIonPool.sol";
import { IStaker } from "../../../src/interfaces/IStaker.sol";
import { IWhitelist } from "../../utils/IWhitelist.sol";

import { StakeHandler } from "./StakingManagerInvariantTestHandler_fork.t.sol";
import { UnstakeHandler } from "./StakingManagerInvariantTestHandler_fork.t.sol";

abstract contract Fixture is Test {
    IIonPool constant ION_POOL = IIonPool(0x0000000000eaEbd95dAfcA37A39fd09745739b78);

    address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    uint256 constant rewardsDuration = 365 days;
    address internal tokenIn;

    JigsawPoints rewardToken;
    StakingManager internal stakingManager;
    IStaker internal staker;
    HoldingManager internal holdingManager;

    address[] internal USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5")))),
        address(uint160(uint256(keccak256("user6")))),
        address(uint160(uint256(keccak256("user7")))),
        address(uint160(uint256(keccak256("user8")))),
        address(uint160(uint256(keccak256("user9")))),
        address(uint160(uint256(keccak256("user10"))))
    ];

    function init() internal {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 19_573_312);

        rewardToken = new JigsawPoints({ _initialAdmin: ADMIN, _premintAmount: 100 });
        holdingManager = new HoldingManager(ADMIN);
        stakingManager = new StakingManager({
            _initialOwner: ADMIN,
            _holdingManager: address(holdingManager),
            _underlyingAsset: wstETH,
            _rewardToken: address(rewardToken),
            _ionPool: address(ION_POOL),
            _rewardsDuration: rewardsDuration
        });

        staker = IStaker(stakingManager.staker());

        vm.startPrank(ADMIN, ADMIN);
        holdingManager.grantRole(holdingManager.STAKING_MANAGER_ROLE(), address(stakingManager));
        deal(address(rewardToken), address(staker), 1e6 * 10e18);
        staker.addRewards(1e6 * 10e18);
        vm.stopPrank();

        vm.startPrank(ION_POOL.owner());
        ION_POOL.updateIlkDebtCeiling(0, type(uint256).max);
        ION_POOL.updateSupplyCap(type(uint256).max);
        IWhitelist(ION_POOL.whitelist()).approveProtocolWhitelist(address(stakingManager));
        vm.stopPrank();
    }
}

contract StakingManagerInvariantTest_Stake is Fixture {
    StakeHandler internal stakeHandler;

    function setUp() external {
        init();
        stakeHandler = new StakeHandler(stakingManager, USER_ADDRESSES);
        targetContract(address(stakeHandler));
    }

    // Test that deposited amounts in Ion Pool and Staker contract are correct at all times
    function invariant_stakingManager_tokenInBalance_equals_tracked_deposits() external view {
        assertEq(staker.totalSupply(), stakeHandler.totalDeposited(), "Staker's totalSupply incorrect");
        assertApproxEqAbs(getIonDeposits(), stakeHandler.totalDeposited(), 1000, "Ion's deposits incorrect");
    }

    // Utility functions

    function getIonDeposits() private view returns (uint256 userDeposits) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            userDeposits += ION_POOL.balanceOf(stakingManager.getUserHolding(USER_ADDRESSES[i]));
        }
    }
}

contract StakingManagerInvariantTest_Unstake is Fixture {
    UnstakeHandler internal unstakeHandler;

    function setUp() external {
        init();
        unstakeHandler = new UnstakeHandler(stakingManager);
        targetContract(address(unstakeHandler));
    }

    // Ensure withdraws are correct
    function invariant_stakingManager_withdraws_correct() external view {
        assertGe(
            unstakeHandler.ionTotalWithdrawn(), unstakeHandler.ionTotalDeposited(), "Ion withdrawn amount incorrect"
        );
        assertEq(
            unstakeHandler.stakerTotalWithdrawn(), unstakeHandler.totalDeposited(), "Staker withdrawn amount incorrect"
        );
    }
}
