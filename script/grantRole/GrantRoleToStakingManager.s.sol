// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, stdJson } from "forge-std/Script.sol";

import { HoldingManager } from "../../src/HoldingManager.sol";

contract GrantRoleToStakingManager is Script {
    using stdJson for string;

    address HOLDING_MANAGER =
        vm.readFile("./deployment-config/StakingManagerConfig.json").readAddress(".holdingManager");
    address STAKING_MANAGER =
        vm.readFile("./deployment-config/StakingManagerConfig.json").readAddress(".holdingManager");

    function run() external {
        vm.startBroadcast(vm.envUint("HOLDING_MANAGER_ADMIN_PRIVATE_KEY"));
        HoldingManager(HOLDING_MANAGER).grantRole(keccak256("STAKING_MANAGER"), STAKING_MANAGER);
        vm.stopBroadcast();
    }
}
