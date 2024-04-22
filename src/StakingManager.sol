// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Staker } from "./Staker.sol";

import { IHoldingManager } from "./interfaces/IHoldingManager.sol";
import { IIonPool } from "./interfaces/IIonPool.sol";
import { IStakingManager } from "./interfaces/IStakingManager.sol";
import { IStaker } from "./interfaces/IStaker.sol";

/**
 * @title StakingManager
 *
 * @notice Manages the distribution of rewards to early users of Jigsaw by facilitating staking of underlying assets.
 * @notice Staked assets are deposited into Ion Pool contracts to generate yield and earn jPoints, redeemable for
 * governance $JIG tokens.
 * @notice For more information on Ion Protocol, visit https://ionprotocol.io.
 *
 * @dev This contract inherits functionalities from `Pausable`, `ReentrancyGuard`, and `Ownable2Step`.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract StakingManager is IStakingManager, Pausable, ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    /**
     * @dev Address of the Holding Manager contract.
     * @dev The Holding Manager is responsible for creating and managing user Holdings.
     */
    IHoldingManager public immutable override holdingManager;

    /**
     * @dev Address of the underlying asset used for staking.
     */
    address public immutable override underlyingAsset;

    /**
     * @dev Address of the reward token distributed for staking.
     */
    address public immutable override rewardToken;

    /**
     * @dev Address of the Ion Pool contract.
     */
    address public immutable override ionPool;

    /**
     * @dev Address of the Staker contract used for jPoints distribution.
     */
    address public immutable override staker;

    /**
     * @dev Represents the expiration date for the staking lockup period.
     * After this date, staked funds can be withdrawn.
     * @notice If not withdrawn will continue to generate rewards in `underlyingAsset` and,
     * if applicable, additional jPoints as long as staked.
     *
     * @return The expiration date for the staking lockup period, in Unix timestamp format.
     */
    uint256 public override lockupExpirationDate;

    // --- Modifiers ---

    /**
     * @dev Modifier to check if the provided amount is valid.
     * @param _amount to be checked for validity.
     */
    modifier validAmount(uint256 _amount) {
        if (_amount == 0) revert InvalidAmount();
        _;
    }

    /**
     * @dev Modifier to check if the provided address is valid.
     * @param _address to be checked for validity.
     */
    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }

    /**
     * @dev Constructor function for initializing the StakerManager contract.
     *
     * @param _initialOwner Address of the initial owner.
     * @param _holdingManager Address of the holding manager contract.
     * @param _underlyingAsset Address of the underlying asset used for staking.
     * @param _rewardToken Address of the reward token.
     * @param _ionPool Address of the IonPool contract.
     * @param _rewardsDuration Duration of the rewards period.
     */
    constructor(
        address _initialOwner,
        address _holdingManager,
        address _underlyingAsset,
        address _rewardToken,
        address _ionPool,
        uint256 _rewardsDuration
    )
        Ownable(_initialOwner)
        validAddress(_holdingManager)
        validAddress(_underlyingAsset)
        validAddress(_rewardToken)
        validAddress(_ionPool)
        validAmount(_rewardsDuration)
    {
        holdingManager = IHoldingManager(_holdingManager);
        underlyingAsset = _underlyingAsset;
        rewardToken = _rewardToken;
        ionPool = _ionPool;
        staker = address(
            new Staker({
                _initialOwner: _initialOwner,
                _tokenIn: _underlyingAsset,
                _rewardToken: _rewardToken,
                _stakingManager: address(this),
                _rewardsDuration: _rewardsDuration
            })
        );
        lockupExpirationDate = block.timestamp + _rewardsDuration;
    }

    /**
     * @notice Stakes a specified amount of assets for the msg.sender.
     * @dev Initiates the staking operation by transferring the specified `_amount` from the user's wallet to the
     * contract, while simultaneously recording this deposit within the Jigsaw Staking Contract.
     *
     * Requirements:
     * - The caller must have sufficient assets to stake.
     * - The Ion Pool Contract's supply cap should not exceed its limit after the user's stake operation.
     * - Prior approval is required for this contract to transfer assets on behalf of the user.
     *
     * Effects:
     * - If the user does not have an existing holding, a new holding is created for the user.
     * - Supplies the specified amount of underlying asset to the Ion Pool to earn interest.
     * - Tracks the deposit in the Staker contract to earn jPoints for staking.
     *
     * Emits:
     * - `Staked` event indicating the staking action.
     *
     * @param _amount of assets to stake.
     */
    function stake(uint256 _amount) external override nonReentrant whenNotPaused validAmount(_amount) {
        // Create a holding for msg.sender if there is no holding associated with their address yet.
        address holding = holdingManager.getUserHolding(msg.sender);
        if (holding == address(0)) holding = holdingManager.createHolding(msg.sender);

        // Emit an event indicating the staking action
        emit Staked(msg.sender, _amount);

        // Transfer assets from the user's wallet to this contract.
        IERC20(underlyingAsset).safeTransferFrom({ from: msg.sender, to: address(this), value: _amount });
        // Approve Ion Pool contract to spend the transferred assets.
        IERC20(underlyingAsset).safeIncreaseAllowance({ spender: ionPool, value: _amount });

        // Supply to the Ion Pool to earn interest on underlying asset.
        IIonPool(ionPool).supply({ user: holding, amount: _amount, proof: new bytes32[](0) });
        // Track deposit in Staker to earn jPoints for staking.
        IStaker(staker).deposit({ _user: holding, _amount: _amount });
    }

    /**
     * @notice Performs unstake operation.
     *
     * @dev Initiates the withdrawal of staked assets by transferring all the deposited assets plus generated yield from
     * the Ion Pool contract and earned jPoint rewards from Staker contract to the designated recipient `_to`.
     *
     * Requirements:
     * - The `lockupExpirationDate` should have already expired.
     * - The caller must possess sufficient staked assets to fulfill the withdrawal.
     * - The `_to` address must be a valid Ethereum address.
     *
     * @param _to address to receive the unstaked assets.
     */
    function unstake(address _to) external override nonReentrant whenNotPaused validAddress(_to) {
        // Check if the lockup expiration date has passed.
        if (lockupExpirationDate > block.timestamp) revert PreLockupPeriodUnstaking();
        // Get the holding address of the caller.
        address holding = holdingManager.getUserHolding(msg.sender);

        // If the caller has no balance in the Ion Pool, revert with `NothingToWithdrawFromIon` error.
        uint256 ionPoolBalance = IIonPool(ionPool).balanceOf(holding);
        if (ionPoolBalance == 0) revert NothingToWithdrawFromIon(msg.sender);

        // Emit an event indicating the unstaking action.
        emit Unstaked(msg.sender, IStaker(staker).balanceOf(holding));

        // Unstake assets and withdraw rewards and transfer them to the specified address.
        holdingManager.unstake({ _holding: holding, _pool: ionPool, _to: _to, _amount: ionPoolBalance });
        IStaker(staker).exit({ _user: holding, _to: _to });
    }

    // --- Administration ---

    /**
     * @dev Triggers stopped state.
     */
    function pause() external override onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     */
    function unpause() external override onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @notice Renounce ownership override to prevent accidental loss of contract ownership.
     * @dev This function ensures that the contract's ownership cannot be lost unintentionally.
     */
    function renounceOwnership() public pure override(IStakingManager, Ownable) {
        revert RenouncingOwnershipProhibited();
    }

    /**
     * @dev Allows the default admin role to set a new lockup expiration date.
     *
     * Requirements:
     * - Caller must have the DEFAULT_ADMIN_ROLE.
     *
     * Emits:
     * - `LockupExpirationDateUpdated` event indicating that lockup expiration date has been updated.
     *
     * @param _newDate The new lockup expiration date to be set.
     */
    function setLockupExpirationDate(uint256 _newDate) external onlyOwner {
        emit LockupExpirationDateUpdated(lockupExpirationDate, _newDate);
        lockupExpirationDate = _newDate;
    }

    // --- Getters ---

    /**
     * @dev Get the address of the holding associated with the user.
     * @param _user The address of the user.
     * @return the holding address.
     */
    function getUserHolding(address _user) external view override returns (address) {
        return holdingManager.getUserHolding(_user);
    }
}
