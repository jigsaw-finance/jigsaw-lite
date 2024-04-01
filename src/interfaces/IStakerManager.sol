// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStakerManager interface
 * @notice Interface for the Staker Manager contract of the Jigsaw Protocol
 *
 */
interface IStakerManager {
    // --- Errors ---
    /**
     * @dev The operation failed because renouncing default admin role is prohibited.
     */
    error RenouncingDefaultAdminRoleProhibited();
    /**
     * @dev The operation failed because amount is zero;
     */
    error InvalidAmount();

    /**
     * @dev The operation failed because provided address is invalid.
     */
    error InvalidAddress();

    /**
     * @dev The operation failed because unstaking is not possible before lockup period ends;
     */
    error PreLockupPeriodUnstaking();

    // --- Events ---
    /**
     * @dev emitted when participant staked
     */
    event Staked(address indexed user, uint256 indexed amount);

    /**
     * @dev emitted when participant unstaked
     */
    event Unstaked(address indexed to, uint256 indexed amount);

    /**
     * @dev emitted when a new holding is created
     */
    event HoldingCreated(address indexed user, address indexed holdingAddress);

    /**
     * @dev Address of holding implementation to be cloned from
     */
    function holdingImplementationReference() external view returns (address);

    /**
     * @dev Address of the underlying asset used for staking.
     */
    function underlyingAsset() external view returns (address);

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
     * After this date, staked funds can be withdrawn. If not withdrawn will continue to
     * generate wstETH rewards and, if applicable, additional jPoints as long as staked.
     * @return The expiration date for the staking lockup period, in Unix timestamp format.
     */
    function lockupExpirationDate() external view returns (uint256);

    /**
     * @notice Invokes a generic call on a holding contract.
     * @dev This function is restricted to be called only by GENERIC_CALLER role
     * @param _holding The address of the holding contract where the call is invoked.
     * @param _contract The external contract being called by the holding contract.
     * @param _call The call data.
     * @return success Indicates whether the call was successful or not.
     * @return result Data obtained from the external call.
     */
    function invokeHolding(
        address _holding,
        address _contract,
        bytes calldata _call
    )
        external
        returns (bool success, bytes memory result);

    /**
     * @notice Stakes a specified amount of assets for the msg.sender.
     * @dev Initiates the staking operation by depositing the specified `_amount`
     * into the Ion Pool contract, while simultaneously recording this deposit within the Jigsaw Staking Contract.
     *
     * Requirements:
     * - The caller must have sufficient assets to stake.
     * - The Ion Pool Contract's supply cap should not exceed its limit after the user's stake operation.
     *
     * @param _amount The amount of assets to stake.
     */
    function stake(uint256 _amount) external;

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
    function unstake(address _to, uint256 _amount) external;

    function beginDefaultAdminTransfer(address newAdmin) external;

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
}
