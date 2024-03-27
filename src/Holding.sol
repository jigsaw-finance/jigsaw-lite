// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IHolding } from "./interfaces/IHolding.sol";

contract Holding is IHolding {
    using SafeERC20 for IERC20;

    /// @notice returns the StakingManager address
    address public override stakingManager;

    /// @notice indicates if the contract has been initialized
    bool private _initialized;

    /// @notice this function initializes the contract (instead of a constructor) to be cloned
    /// @param _stakingManager contract handler for staking
    function init(address _stakingManager) public {
        require(!_initialized, "");
        require(_stakingManager != address(0), "");
        _initialized = true;
        stakingManager = _stakingManager;
    }

    modifier onlyStakingManager() {
        require(msg.sender == stakingManager, "1000");
        _;
    }
}
