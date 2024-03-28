// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { StakingManager } from "../../src/StakingManager.sol";

import { IIonPool } from "../utils/IIonPool.sol";
import { IWhitelist } from "../utils/IWhitelist.sol";

IIonPool constant ION_POOL = IIonPool(0x0000000000eaEbd95dAfcA37A39fd09745739b78);

contract IntegrationPoC is Test {
    string public MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address constant ADMIN = address(uint160(uint256(keccak256(bytes("ADMIN")))));
    address constant underlyingAsset = address(uint160(uint256(keccak256(bytes("underlyingAsset")))));
    address constant rewardToken = address(uint160(uint256(keccak256(bytes("rewardToken")))));

    StakingManager internal stakingManager;

    function setUp() public {
        vm.createSelectFork(MAINNET_RPC_URL);

        stakingManager = new StakingManager(
            ADMIN,
            underlyingAsset,
            rewardToken,
            address(ION_POOL)
        );
    }

    function test_RemoveConstraints() public {
        IWhitelist whitelist = IWhitelist(ION_POOL.whitelist());

        vm.startPrank(ION_POOL.owner());
        whitelist.approveProtocolWhitelist(address(stakingManager));
    }
}
