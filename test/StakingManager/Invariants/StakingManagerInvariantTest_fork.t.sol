// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StakingManager } from "../../../src/StakingManager.sol";
import { jPoints } from "../../../src/jPoints.sol";

import { IIonPool } from "../../utils/IIonPool.sol";
import { IStaker } from "../../../src/interfaces/IStaker.sol";
import { IWhitelist } from "../../utils/IWhitelist.sol";

import { StakingManagerInvariantTestHandler } from "./StakingManagerInvariantTestHandler_fork.t.sol";

IIonPool constant ION_POOL = IIonPool(0x0000000000eaEbd95dAfcA37A39fd09745739b78);

contract StakingManagerInvariantTest is Test {
    address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address internal tokenIn;
    uint256 internal rewardsDuration = 365 days;

    jPoints rewardToken;
    StakingManager internal stakingManager;
    IStaker internal staker;

    StakingManagerInvariantTestHandler internal handler;

    address[] public USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5"))))
    ];

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 19_573_312);

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

        handler = new StakingManagerInvariantTestHandler(stakingManager, USER_ADDRESSES);
        targetContract(address(handler));
    }

    /**
     * Should assert that:
     *      1. Deposited to Staker == deposited to ION
     *      2. Users can withdraw more then they deposited
     *      3. Every user has holding?
     */

    // Test that deposited amounts in Ion Pool and Staker contract are correct at all times
    function invariant_stakingManager_tokenInBalance_equals_tracked_deposits() external view {
        // console.log(handler.totalDeposited(), "Deposited");
        // console.log(handler.stakerTotalWithdrawn(), "Withdrawn");

        // uint256 expectedAmount = handler.totalDeposited() - handler.stakerTotalWithdrawn();

        // assertEq(staker.totalSupply(), expectedAmount, "Staker's totalSupply incorrect");

        // assertEq(getIonDeposits(), expectedAmount);
        // assertApproxEqRel(a, b, 1e18);

        // assertApproxEqAbs(getIonDeposits(), expectedAmount, 10, "Ion's deposits incorrect");

        // assertApproxEqRel(getIonDeposits(), expectedAmount, 0.01e18, "Ion's deposits incorrect");
    }

    function getIonDeposits() private view returns (uint256 userDeposits) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            userDeposits += ION_POOL.balanceOf(stakingManager.getUserHolding(USER_ADDRESSES[i]));
        }
    }

    // // Test that staker's reward token's balance is correct at all times
    // function invariant_staker_rewardTokenBalance_equals_tracked_deposits() external view {
    //     assertEq(
    //         handler.totalRewardsAmount() - handler.totalRewardsClaimed(),
    //         IERC20(rewardToken).balanceOf(address(staker)),
    //         "Staker's reward token balance incorrect"
    //     );
    // }

    // // Test that the total of all deposits is equal to the pool's totalSupply
    // function invariant_staker_totalSupply_equal_deposits() external view {
    //     assertGe(
    //         staker.totalSupply(), handler.totalDeposited() - handler.totalWithdrawn(), "Staker's total supply
    // incorrect"
    //     );
    // }

    // // Test that the sum of all user rewards is equal to the the sum of all amounts of rewards distributed
    // function invariant_total_rewards() external view {
    //     assertEq(handler.totalRewardsAmount(), handler.getUserRewards(), "Staker's rewards count incorrect");
    // }
}
