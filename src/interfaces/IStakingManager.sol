// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IHoldingManager } from "./IHoldingManager.sol";

/**
 * @title IStakingManager interface
 * @notice Interface for the Staking Manager contract of the Jigsaw Protocol
 *
 */
interface IStakingManager {
    // --- Errors ---
    /**
     * @dev The operation failed because renouncing ownership is prohibited.
     */
    error RenouncingOwnershipProhibited();

    /**
     * @dev The operation failed because amount is invalid.
     */
    error InvalidAmount();

    /**
     * @dev The operation failed because provided address is invalid.
     */
    error InvalidAddress();

    /**
     * @dev The operation failed because unstaking is not possible before lockup period ends.
     */
    error PreLockupPeriodUnstaking();

    /**
     * @dev The operation failed because caller's holding balance in the Ion Pool is zero.
     * @param caller address whose holding balance is zero.
     */
    error NothingToWithdrawFromIon(address caller);

    // --- Events ---
    /**
     * @dev emitted when participant staked.
     */
    event Staked(address indexed user, uint256 indexed amount);

    /**
     * @dev emitted when participant unstaked.
     */
    event Unstaked(address indexed to, uint256 indexed amount);

    /**
     * @dev emitted when the expiration date of a lockup is updated.
     * @param oldDate The previous expiration date of the lockup.
     * @param newDate The new expiration date of the lockup.
     */
    event LockupExpirationDateUpdated(uint256 indexed oldDate, uint256 indexed newDate);

    /**
     * @notice Address of the Holding Manager contract.
     * @dev The Holding Manager is responsible for creating and managing user Holdings.
     */
    function holdingManager() external view returns (IHoldingManager);

    /**
     * @dev Address of the underlying asset used for staking.
     */
    function underlyingAsset() external view returns (address);

    /**
     * @dev Address of the reward token distributed for staking.
     */
    function rewardToken() external view returns (address);

    /**
     * @dev Address of the Ion Pool contract.
     */
    function ionPool() external view returns (address);

    /**
     * @dev Address of the Staker contract used for jPoints distribution.
     */
    function staker() external view returns (address);

    /**
     * @dev Represents the expiration date for the staking lockup period.
     * After this date, staked funds can be withdrawn.
     * @notice If not withdrawn will continue to generate rewards in `underlyingAsset` and,
     * if applicable, additional jPoints as long as staked.
     *
     * @return The expiration date for the staking lockup period, in Unix timestamp format.
     */
    function lockupExpirationDate() external view returns (uint256);

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
    function stake(uint256 _amount) external;

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
    function unstake(address _to) external;

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external;

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external;

    /**
     * @notice Renounce ownership override to prevent accidental loss of contract ownership.
     * @dev This function ensures that the contract's ownership cannot be lost unintentionally.
     */
    function renounceOwnership() external pure;

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
    function setLockupExpirationDate(uint256 _newDate) external;

    /**
     * @dev Get the address of the holding associated with the user.
     * @param _user The address of the user.
     * @return the holding address.
     */
    function getUserHolding(address _user) external view returns (address);
}
