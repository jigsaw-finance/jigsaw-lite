// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { stdJson as StdJson } from "forge-std/Script.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IIonPool } from "../../test/utils/IIonPool.sol";

import { BaseScript } from "./Base.s.sol";
import { StakingManager } from "../../src/StakingManager.sol";
import { IHoldingManager } from "../../src/interfaces/IHoldingManager.sol";

contract DeployStakingManagerScript is BaseScript {
    using StdJson for string;

    string configPath = "./deployment-config/StakingManagerConfig.json";
    string config = vm.readFile(configPath);

    address INITIAL_OWNER = config.readAddress(".initialDefaultAdmin");
    address HOLDING_MANAGER = config.readAddress(".holdingManager");
    address UNDERLYING = config.readAddress(".underlyingAsset");
    address REWARD_TOKEN = config.readAddress(".jPointsAddress");
    address ION_POOL = config.readAddress(".ionPool");
    uint256 REWARDS_DURATION = config.readUint(".rewardsDuration");

    function run() external broadcast returns (StakingManager stakingManager) {
        _validateInterface(IHoldingManager(HOLDING_MANAGER));
        _validateInterface(IIonPool(ION_POOL));
        _validateInterface(IERC20(UNDERLYING));
        _validateInterface(IERC20(REWARD_TOKEN));

        stakingManager = new StakingManager({
            _initialOwner: INITIAL_OWNER,
            _holdingManager: HOLDING_MANAGER,
            _underlyingAsset: UNDERLYING,
            _rewardToken: REWARD_TOKEN,
            _ionPool: ION_POOL,
            _rewardsDuration: REWARDS_DURATION
        });
    }
}
