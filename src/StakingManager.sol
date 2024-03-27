// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { Holding } from "./Holding.sol";
import { Staker } from "./Staker.sol";

import { IStakerManager } from "./interfaces/IStakerManager.sol";
import { IStaker } from "./interfaces/IStaker.sol";
import { IIonPool } from "./interfaces/IIonPool.sol";

/**
 * @notice `StakerManager` is a contract dedicated to distributing rewards to early users of Jigsaw.
 * @notice It accepts Lido's wstETH token as the underlying asset for staking and subsequent token distribution.
 * @notice wstETH tokens staked through StakerManager are deposited into Ion protocol's Pool contract to generate yield,
 * while also farming jPoints, which will later be exchanged for Jigsaw's governance $JIG tokens.
 *
 * @dev Inherits the OpenZepplin Ownable2Step and Pausable implentation
 *
 * @custom:security-contact @note Please add security-contact for further inquiries.
 */
contract StakerManager is IStakerManager, Pausable, Ownable2Step, ReentrancyGuard {
    /**
     * @notice Stores a mapping of each user to their holding.
     * @dev returns holding address.
     */
    mapping(address => address) private userHolding;

    /**
     * @dev Address of holding implementation to be cloned from
     */
    address public immutable holdingImplementationReference;

    /**
     * @dev Address of the underlying asset used for staking.
     */
    address public immutable underlyingAsset;

    /**
     * @dev Address of the Ion Pool contract.
     */
    address public immutable ionPool;

    /**
     * @dev Address of the Staker contract used for jPoints distribution.
     */
    address public immutable staker;

    // --- Modifiers ---

    /**
     * @dev Modifier to ensure that user has provided valid amount;
     *
     */
    modifier validAmount(uint256 _amount) {
        if (_amount == 0) revert InvalidAmount();
        _;
    }

    /**
     * @dev Constructor function for initializing the StakerManager contract.
     * @param _underlyingAsset Address of the underlying asset used for staking.
     * @param _ionPool Address of the ionPool contract.
     */
    constructor(
        address _initialOwner,
        address _underlyingAsset,
        address _rewardToken,
        address _ionPool
    )
        Ownable(_initialOwner)
    {
        underlyingAsset = _underlyingAsset;
        ionPool = _ionPool;
        staker = address(
            new Staker(
                _initialOwner,
            _underlyingAsset,
            _rewardToken
            )
        );
        holdingImplementationReference = address(new Holding());
    }

    /**
     * @notice Stakes a specified amount of assets for the msg.sender.
     * @dev Initiates the staking operation by depositing the specified `_amount`
     * into the Ion Pool contract, while simultaneously recording this deposit within the Jigsaw Staking Contract.
     *
     * Requirements:
     * - The caller must have sufficient assets to stake.
     * - The Ion Pool Contract's supply cap should not exceed its limit after the user's stake operation.
     *
     * Effects:
     * - If the user does not have an existing holding, a new holding is created for the user.
     * - Emits a `Staked` event indicating the staking action.
     * - Supplies the specified amount of underlying asset to the Ion Pool to earn interest.
     * - Tracks the deposit in the Staker contract to earn jPoints for staking.
     *
     * Emits:
     * - `Staked` event indicating the staking action.
     *
     * @param _amount The amount of assets to stake.
     */
    function stake(uint256 _amount) external override nonReentrant whenNotPaused validAmount(_amount) {
        address holding = userHolding[msg.sender];

        // Create a holding for msg.sender if there is no holding associated with their address yet.
        if (holding == address(0)) _createHolding();

        emit Staked(msg.sender, _amount);

        // Supply to the Ion Pool to earn interest on underlying asset.
        IIonPool(ionPool).supply(holding, _amount, new bytes32[](0));
        // Track deposit in Staker to earn jPoints for staking.
        IStaker(staker).deposit(_amount);
    }

    /**
     * @notice Withdraws a specified amount of staked assets.
     * @dev Initiates the withdrawal of staked assets by transferring the specified `_amount`
     * from the Ion Pool contract to the designated recipient `_to`.
     *
     * Requirements:
     * - The caller must have sufficient staked assets to fulfill the withdrawal.
     * - The `_to` address must be a valid Ethereum address.
     *
     * @param _to The address to receive the unstaked assets.
     * @param _amount The amount of staked assets to withdraw.
     */
    function unstake(address _to, uint256 _amount) external override nonReentrant whenNotPaused validAmount(_amount) { }

    // --- Administration ---

    // @dev renounce ownership override to avoid losing contract's ownership
    function renounceOwnership() public pure override {
        revert RenouncingOwnershipIsProhibited();
    }

    // --- Helpers ---

    /**
     * @notice Creates a new holding instance for the msg.sender.
     * @dev Clones a new holding contract instance using the reference implementation
     * and associates it with the caller's address. Emits an event to signify the creation
     * of the holding contract. Additionally, initializes the holding contract.
     *
     * @return newHoldingAddress The address of the newly created holding contract.
     */
    function _createHolding() private returns (address newHoldingAddress) {
        // Deploy a new holding contract instance
        newHoldingAddress = Clones.clone(holdingImplementationReference);
        // Associate the new holding contract with msg.sender
        userHolding[msg.sender] = newHoldingAddress;

        // Emit an event to notify of the creation of the holding contract
        emit HoldingCreated(msg.sender, newHoldingAddress);

        // Initialize the newly created holding contract
        Holding(newHoldingAddress).init(address(this));
    }

    // --- Getters ---

    function _getUserHolding(address _user) public view returns (address) {
        return userHolding[_user];
    }
}
