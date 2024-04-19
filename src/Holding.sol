// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { IHolding } from "./interfaces/IHolding.sol";
import { IIonPool } from "./interfaces/IIonPool.sol";

/**
 * @title Holding Contract
 *
 * @dev This contract serves as the implementation for clones used in StakingManager Contract.
 *
 * This contract is responsible for managing staking operations within the Jigsaw lite protocol.
 * Stakers can deposit tokens into the Ion Pool and withdraw them on behalf of the Holding.
 * Additionally, the contract allows for executing generic calls to interact with other contracts,
 * with restrictions to ensure security and integrity of the protocol.
 *
 * This contract inherits the following:
 * - ReentrancyGuard: A contract module that helps prevent reentrancy attacks by utilizing mutex locks.
 * - Initializable: A contract module that provides a mechanism for initializing contracts post-deployment.
 *
 * This contract implements the IHolding interface, defining the functions required by the Jigsaw protocol.
 *
 * @author Hovooo (@hovooo)
 */
contract Holding is IHolding, ReentrancyGuard, Initializable {
    using SafeERC20 for IERC20;

    /**
     * @dev Address of the Holding Manager contract.
     */
    address public holdingManager;

    // --- Modifiers ---

    modifier onlyHoldingManager() {
        if (msg.sender != holdingManager) revert UnauthorizedCaller();
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
     * @param _holdingManager The address of the contract handling staking operations.
     */
    function init(address _holdingManager) external initializer {
        if (_holdingManager == address(0)) revert ZeroAddress();
        holdingManager = _holdingManager;
    }

    // -- Staker's operations  --

    /**
     * @notice Allows to withdraw a specified amount of tokens to a designated address from Ion Pool.
     * @dev Only accessible by the staking manager and protected against reentrancy.
     *
     * @param _pool The address of the pool from which to withdraw underlying assets.
     * @param _to Address to which the redeemed underlying asset should be sent to.
     * @param _amount of underlying to redeem for.
     */
    function unstake(address _pool, address _to, uint256 _amount) external override onlyHoldingManager nonReentrant {
        IIonPool(_pool).withdraw(_to, _amount);
        emit Unstaked(address(this), _to, _amount);
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
        override
        onlyHoldingManager
        nonReentrant
        returns (bool success, bytes memory result)
    {
        (success, result) = _contract.call(_call);
    }
}
