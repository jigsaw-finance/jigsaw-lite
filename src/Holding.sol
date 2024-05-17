// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { IHolding } from "./interfaces/IHolding.sol";
import { IIonPool } from "./interfaces/IIonPool.sol";

/**
 * @title Holding
 *
 * @notice This contract acts as the implementation for clones utilized in the `Staking Manager` Contract,
 * facilitating the management of user's staked assets and  staking operations.
 *
 * @notice This contract is responsible for managing staking operations within the Jigsaw lite protocol.
 * @notice Stakers can deposit tokens into the Ion `Pool`s and withdraw them on behalf of the `Holding`.
 * @notice Additionally, the contract allows for executing generic calls to interact with other contracts,
 * with restrictions to ensure security and integrity of the protocol.
 *
 * @dev This contract inherits functionalities from `ReentrancyGuard` and `Initializable`.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract Holding is IHolding, ReentrancyGuard, Initializable {
    using SafeERC20 for IERC20;

    /**
     * @notice Address of the `Holding Manager` Contract.
     */
    address public holdingManager;

    // --- Modifiers ---

    /**
     * @notice Modifier to restrict access to only the `Holding Manager` Contract.
     */
    modifier onlyHoldingManager() {
        if (msg.sender != holdingManager) revert UnauthorizedCaller();
        _;
    }

    /**
     * @notice Modifier to check if the provided address is valid.
     * @param _address to be checked for validity.
     */
    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
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
     * /**
     * @notice Initializes the contract (instead of a constructor) to be cloned.
     * @param _holdingManager contract address for handling staking operations
     */
    function init(address _holdingManager) external initializer validAddress(_holdingManager) {
        holdingManager = _holdingManager;
    }

    // -- Staker's operations  --

    /**
     * @notice Allows to withdraw a specified amount of tokens to a designated address from Ion `Pool`.
     *
     * @dev Only accessible by the `Holding Manager` Contract and protected against reentrancy.
     *
     * @param _pool address from which to withdraw underlying assets.
     * @param _to address to which the redeemed underlying asset should be sent to.
     * @param _amount of underlying to redeem for.
     */
    function unstake(address _pool, address _to, uint256 _amount) external override onlyHoldingManager nonReentrant {
        IIonPool(_pool).withdraw(_to, _amount);
        emit Unstaked(address(this), _to, _amount);
    }

    /**
     * @notice Executes a generic call to interact with another contract.
     * @dev This function is restricted to be called only by `Holding Manager` Contract
     * aimed at mitigating potential risks associated with unauthorized calls.
     *
     * @param _contract address of the target for the call.
     * @param _value of Ether to transfer in the call.
     * @param _call ABI-encoded data representing the call to be made.
     *
     * @return success A boolean indicating whether the call was successful or not.
     * @return result The result of the call as bytes.
     */
    function genericCall(
        address _contract,
        uint256 _value,
        bytes calldata _call
    )
        external
        override
        onlyHoldingManager
        nonReentrant
        returns (bool success, bytes memory result)
    {
        (success, result) = _contract.call{ value: _value }(_call);
    }
}
