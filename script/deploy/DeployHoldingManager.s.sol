// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { stdJson as StdJson } from "forge-std/Script.sol";

import { BaseScript } from "./Base.s.sol";
import { HoldingManager } from "../../src/HoldingManager.sol";

contract DeployHoldingManagerScript is BaseScript {
    using StdJson for string;

    string configPath = "./deployment-config/HoldingManagerConfig.json";
    string config = vm.readFile(configPath);

    address DEFAULT_ADMIN = config.readAddress(".initialDefaultAdmin");

    function run() external broadcast returns (HoldingManager holdingManager) {
        holdingManager = new HoldingManager({ _admin: DEFAULT_ADMIN });
    }
}
