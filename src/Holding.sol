// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { IHolding } from "./interfaces/IHolding.sol";
import { IIonPool } from "./interfaces/IIonPool.sol";

contract Holding is IHolding, ReentrancyGuard, Initializable {
    using SafeERC20 for IERC20;

    /**
     * @dev Address of the Staking Manager contract.
     */
    address public stakingManager;

    /**
     * @dev Address of the Ion Pool contract.
     */
    address public ionPool;

    // --- Modifiers ---

    modifier onlyStakingManager() {
        if (msg.sender != stakingManager) revert UnauthorizedCaller();
        _;
    }

    // --- Constructor ---

    /**
     * To prevent the implementation contract from being used, the _disableInitializers function is invoked
     * in the constructor to automatically lock it when it is deployed.
     */
    constructor() {
        _disableInitializers();
    }

    // --- Initialization ---

    /**
     * @dev Initializes the contract (instead of a constructor) to be cloned.
     * @param _stakingManager The address of the contract handling staking operations.
     * @param _ionPool Address of the Ion Pool contract.
     */
    function init(address _stakingManager, address _ionPool) external initializer {
        if (_ionPool == address(0)) revert ZeroAddress();
        if (_stakingManager == address(0)) revert ZeroAddress();
        stakingManager = _stakingManager;
        ionPool = _ionPool;
    }

    // -- Staker's operations  --

    /**
     * @notice Allows to withdraw a specified amount of tokens to a designated address from Ion Pool.
     * @dev Only accessible by the staking manager and protected against reentrancy.
     *
     * @param _to Address to which the redeemed underlying asset should be sent to.
     * @param _amount of underlying to redeem for.
     */
    function unstake(address _to, uint256 _amount) external onlyStakingManager nonReentrant {
        IIonPool(ionPool).withdraw(_to, _amount);
        emit Unstaked(msg.sender, _amount);
    }

    /**
     * @notice Executes a generic call to interact with another contract.
     * @dev This function is restricted to be called only by Staking Manager contract
     * aimed at mitigating potential risks associated with unauthorized calls.
     *
     * @param _contract The address of the target contract for the call.
     * @param _call ABI-encoded data representing the call to be made.
     *
     * @return success A boolean indicating whether the call was successful or not.
     * @return result The result of the call as bytes.
     */
    function genericCall(
        address _contract,
        bytes calldata _call
    )
        external
        onlyStakingManager
        nonReentrant
        returns (bool success, bytes memory result)
    {
        (success, result) = _contract.call(_call);
    }
}
