// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StakingManager } from "../../src/StakingManager.sol";
import { jPoints } from "../../src/jPoints.sol";

import { IIonPool } from "../utils/IIonPool.sol";
import { IStaker } from "../../src/interfaces/IStaker.sol";
import { IWhitelist } from "../utils/IWhitelist.sol";

IIonPool constant ION_POOL = IIonPool(0x0000000000eaEbd95dAfcA37A39fd09745739b78);

contract StakingManagerForkTest is Test {
    uint256 constant STAKING_SUPPLY_LIMIT = 1e34;

    address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
    address constant USER = address(uint160(uint256(keccak256(bytes("USER")))));
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    jPoints rewardToken;

    StakingManager internal stakingManager;
    IStaker internal staker;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        rewardToken = new jPoints( {_initialOwner: ADMIN,_limit: 1e6} );

        stakingManager = new StakingManager({            
            _admin: ADMIN,
            _underlyingAsset: wstETH,
            _rewardToken: address(rewardToken),
           _ionPool: address(ION_POOL),
           _rewardsDuration: 12 weeks
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
    }

    function test_stake_when_authorized(uint256 _amount) public validAmount(_amount) {
        deal(wstETH, USER, _amount);

        vm.startPrank(USER, USER);
        IERC20(wstETH).approve(address(stakingManager), _amount);
        stakingManager.stake(_amount);
    }

    modifier validAmount(uint256 _amount) {
        vm.assume(_amount > 0.0001e18 && _amount <= STAKING_SUPPLY_LIMIT);
        _;
    }
}
