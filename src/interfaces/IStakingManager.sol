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
     * @notice The operation failed because renouncing ownership is prohibited.
     */
    error RenouncingOwnershipProhibited();

    /**
     * @notice The operation failed because amount is invalid.
     */
    error InvalidAmount();

    /**
     * @notice The operation failed because the same value was provided for an update.
     */
    error SameValue();

    /**
     * @notice The operation failed because provided address is invalid.
     */
    error InvalidAddress();

    /**
     * @notice The operation failed because unstaking is not possible before lockup period ends.
     */
    error PreLockupPeriodUnstaking();

    /**
     * @notice The operation failed because caller's holding balance in the Ion Pool is zero.
     * @param caller address whose holding balance is zero.
     */
    error NothingToWithdrawFromIon(address caller);

    // --- Events ---
    /**
     * @notice Emitted when a participant stakes tokens.
     * @param user address of the participant who staked.
     * @param amount of the staked tokens.
     */
    event Staked(address indexed user, uint256 indexed amount);

    /**
     * @notice Emitted when a participant unstakes tokens.
     * @param user address of the participant who unstaked.
     * @param amount of the unstaked tokens.
     */
    event Unstaked(address indexed user, uint256 indexed amount);

    /**
     * @notice emitted when the expiration date of a lockup is updated.
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
     * @notice Address of the underlying asset used for staking.
     */
    function underlyingAsset() external view returns (address);

    /**
     * @notice Address of the reward token distributed for staking.
     */
    function rewardToken() external view returns (address);

    /**
     * @notice Address of the Ion Pool contract.
     */
    function ionPool() external view returns (address);

    /**
     * @notice Address of the Staker contract used for jPoints distribution.
     */
    function staker() external view returns (address);

    /**
     * @notice Represents the expiration date for the staking lockup period.
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
     * contract, while simultaneously recording this deposit within the Jigsaw `Staker` Contract.
     *
     * @notice Requirements:
     * - The caller must have sufficient assets to stake.
     * - The Ion `Pool` Contract's supply cap should not exceed its limit after the user's stake operation.
     * - Prior approval is required for this contract to transfer assets on behalf of the user.
     *
     * @notice Effects:
     * - If the user does not have an existing holding, a new holding is created for the user.
     * - Supplies the specified amount of underlying asset to the Ion's `Pool` Contract to earn interest.
     * - Tracks the deposit in the `Staker` Contract to earn jPoints for staking.
     *
     * @notice Emits:
     * - `Staked` event indicating the staking action.
     *
     * @param _amount of assets to stake.
     */
    function stake(uint256 _amount) external;

    /**
     * @notice Performs unstake operation.
     * @dev Initiates the withdrawal of staked assets by transferring all the deposited assets plus generated yield from
     * the Ion's `Pool` Contract and earned jPoint rewards from `Staker` Contract to the designated recipient `_to`.
     *
     * @notice Requirements:
     * - The `lockupExpirationDate` should have already expired.
     * - The caller must possess sufficient staked assets to fulfill the withdrawal.
     * - The `_to` address must be a valid Ethereum address.
     *
     * @notice Effects:
     * - Unstakes deposited and accrued underlying assets from Ion's `Pool` Contract.
     * - Withdraws jPoint rewards from `Staker` Contract.
     * - Withdraws Ion rewards from `Holding` through `HoldingManager` Contract.
     *
     *
     * @notice Emits:
     * - `Unstaked` event indicating the unstaking action.
     *
     * @param _to address to receive the unstaked assets.
     */
    function unstake(address _to) external;

    /**
     * @notice Triggers stopped state.
     */
    function pause() external;

    /**
     * @notice Returns to normal state.
     */
    function unpause() external;

    /**
     * @notice Renounce ownership override to prevent accidental loss of contract ownership.
     * @dev This function ensures that the contract's ownership cannot be lost unintentionally.
     */
    function renounceOwnership() external pure;

    /**
     * @notice Allows the default admin role to set a new lockup expiration date.
     *
     * @notice Requirements:
     * - Caller must be `Owner`.
     * - `_newDate` should be different from `lockupExpirationDate`.
     *
     * @notice Effects:
     * - Sets `lockupExpirationDate` to `_newDate`.
     *
     *  @notice Emits:
     * - `LockupExpirationDateUpdated` event indicating that lockup expiration date has been updated.
     *
     * @param _newDate The new lockup expiration date to be set.
     */
    function setLockupExpirationDate(uint256 _newDate) external;

    /**
     * @notice Get the address of the holding associated with the user.
     * @param _user The address of the user.
     * @return the holding address.
     */
    function getUserHolding(address _user) external view returns (address);
}
