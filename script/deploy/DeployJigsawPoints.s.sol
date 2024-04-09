// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { stdJson as StdJson } from "forge-std/Script.sol";

import { BaseScript } from "./Base.s.sol";
import { JigsawPoints } from "../../src/JigsawPoints.sol";

contract DeployJigsawPointsScript is BaseScript {
    using StdJson for string;

    string configPath = "./deployment-config/JigsawPointsConfig.json";
    string config = vm.readFile(configPath);

    address DEFAULT_ADMIN = config.readAddress(".initialDefaultAdmin");
    uint256 PREMINT_AMOUNT = config.readUint(".premintAmount");

    function run() external broadcast returns (JigsawPoints jPoints) {
        jPoints = new JigsawPoints(DEFAULT_ADMIN, PREMINT_AMOUNT);
    }
}
