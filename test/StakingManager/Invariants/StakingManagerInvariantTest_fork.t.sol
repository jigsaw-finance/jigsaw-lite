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

import { StakingManagerInvariantTestHandler } from "./StakingManagerInvariantTestHadler_fork.t.sol";

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

        handler = new StakingManagerInvariantTestHandler(stakingManager);
        targetContract(address(handler));
    }

    /**
     * Should assert that:
     *      1. Deposited to Staker == deposited to ION
     *      2. Users can withdraw more then they deposited
     *      3. Users can withdraw more then they deposited
     *      4. Every user has holding?
     */

    // Test that deposited amounts in Ion Pool and Staker contract are correct at all times
    function invariant_staker_tokenInBalance_equals_tracked_deposits() external {
        uint256 expectedAmount = handler.totalDeposited() - handler.stakerTotalWithdrawn();

        assertEq(staker.totalSupply(), expectedAmount, "Staker's totalSupply incorrect");
        assertGe(handler.getIonDeposits(), expectedAmount, "Ion's deposits incorrect");
    }
}
