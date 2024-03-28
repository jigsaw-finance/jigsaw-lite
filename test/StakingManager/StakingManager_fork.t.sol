// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { StakingManager } from "../../src/StakingManager.sol";
import { jPoints } from "../../src/jPoints.sol";

import { IIonPool } from "../utils/IIonPool.sol";
import { IWhitelist } from "../utils/IWhitelist.sol";

IIonPool constant ION_POOL = IIonPool(0x0000000000eaEbd95dAfcA37A39fd09745739b78);

contract IntegrationPoC is Test {
    string public MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
    address constant USER = address(uint160(uint256(keccak256(bytes("USER")))));
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    jPoints rewardToken;

    StakingManager internal stakingManager;

    function setUp() public {
        vm.createSelectFork(MAINNET_RPC_URL);

        rewardToken = new jPoints( {_initialOwner: ADMIN,_limit: 1e6} );

        stakingManager = new StakingManager({            
            _admin: ADMIN,
            _underlyingAsset: wstETH,
            _rewardToken: address(rewardToken),
           _ionPool: address(ION_POOL)}
        );

        vm.startPrank(ION_POOL.owner());
        ION_POOL.updateIlkDebtCeiling(0, type(uint256).max);
        ION_POOL.updateSupplyCap(1000e18);
        IWhitelist(ION_POOL.whitelist()).approveProtocolWhitelist(address(stakingManager));
        vm.stopPrank();
    }

    function test_stake_when_authorized(uint256 _amount) public {
        // vm.assume(_amount != 0);

        _amount = bound(_amount, 1e18, 1000e18);
        deal(wstETH, USER, _amount);

        vm.prank(USER, USER);
        stakingManager.stake(_amount);
    }
}
