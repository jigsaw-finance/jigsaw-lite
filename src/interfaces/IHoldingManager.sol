// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IHoldingManager interface
 * @dev Interface for the HoldingManager contract.
 */
interface IHoldingManager {
    // --- Errors ---

    /**
     * @dev The operation failed because provided address is invalid.
     */
    error InvalidAddress();

    /**
     * @dev The operation failed because renouncing default admin role is prohibited.
     */
    error RenouncingDefaultAdminRoleProhibited();

    /**
     * @dev The operation failed because user attempts an action that requires a holding contract associated with their
     * address, but no holding contract is found.
     * @param user The address of the user who hasn't holding contract.
     */
    error MissingHoldingContractForUser(address user);

    /**
     * @dev The operation failed because the generic caller attempts to invoke a contract via a holding contract,
     * but the allowance for the invocation is not permitted.
     * @param caller The address of the generic caller attempting the invocation.
     */
    error InvocationNotAllowed(address caller);

    /**
     * @dev The operation failed because the generic call failed.
     * @param data returned by the failed call.
     */
    error InvocationFailed(bytes data);

    // --- Events ---

    /**
     * @dev emitted when a new holding is created.
     */
    event HoldingCreated(address indexed user, address indexed holdingAddress);

    /**
     * @dev emitted when the holding implementation reference is updated.
     * @param _newReference The address of the new implementation reference.
     */
    event HoldingImplementationReferenceUpdated(address indexed _newReference);

    /**
     * @dev emitted when the allowance for invoking contracts via a holding contract is set.
     *
     * @param holding The address of the holding contract.
     * @param genericCaller The address of the generic caller.
     * @param callableContract The address of the contract that can be invoked.
     * @param invocationsAllowance The number of invocations allowed for the specified contract by the generic caller
     * via the holding contract.
     */
    event InvocationAllowanceSet(
        address holding, address genericCaller, address callableContract, uint256 invocationsAllowance
    );

    /**
     * Declaration of the Staking Manager role - privileged actor, allowed to call unstake function on Holdings.
     */
    function STAKING_MANAGER_ROLE() external view returns (bytes32);

    /**
     * Declaration of the Generic Caller role - privileged actor, allowed to perform low level calls on Holdings.
     */
    function GENERIC_CALLER_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the address of the holding implementation reference.
     */
    function holdingImplementationReference() external view returns (address);

    /**
     * @dev Sets the allowance for a generic caller to invoke specified contracts on behalf of the user
     * through their holding contract.
     *
     * Requirements:
     * - `_genericCaller` must be a valid address.
     * - `_callableContract` must be a valid address.
     * - The caller must have a holding contract associated with their address.
     * - The `_genericCaller` must have the `GENERIC_CALLER_ROLE`.
     *
     * Effects:
     * - Emits an `InvocationAllowanceSet` event upon successful execution.
     *
     * @param _genericCaller The address of the generic caller.
     * @param _callableContract The address of the contract to be invoked.
     * @param _invocationsAllowance The number of invocations allowed for the specified contract by the generic caller
     * via the holding contract.
     */
    function setInvocationAllowance(
        address _genericCaller,
        address _callableContract,
        uint256 _invocationsAllowance
    )
        external;

    /**
     * @notice Creates a new holding instance for the specified `user`.
     * @dev Clones a new holding contract instance using the reference implementation and associates it with the
     * `user`'s address and initializes the holding contract.
     * @dev Emits an event to signify the creation of the holding contract.
     *
     * @param _user The address of the user.
     *
     * @return holding The address of the newly created holding contract.
     */
    function createHolding(address _user) external returns (address holding);

    /**
     * @dev Unstake funds from a the specified Ion Protocol's `_pool` contract for `_holding`.
     *
     * @param _holding address to unstake for.
     * @param _pool address of Ion's pool.
     * @param _to The address where unstaked tokens will be sent.
     * @param _amount The amount of tokens to unstake.
     */
    function unstake(address _holding, address _pool, address _to, uint256 _amount) external;

    /**
     * @dev Allows a generic caller to invoke a function on a contract via a holding contract.
     * This function performs a generic call on the specified contract address using the provided call data.
     *
     * Requirements:
     * - `_holding` must be a valid address representing the holding contract.
     * - `_contract` must be a valid address representing the target contract.
     * - The caller must have the `GENERIC_CALLER_ROLE`.
     * - The allowance for the caller on the specified `_contract` via `_holding` must be greater than 0.
     *
     * @param _holding The address of the holding contract where the call is invoked.
     * @param _contract The external contract being called by the holding contract.
     * @param _value The amount of Ether to transfer in the call.
     * @param _call The call data.
     *
     * @return success Indicates whether the call was successful or not.
     * @return result Data obtained from the external call.
     */
    function invokeHolding(
        address _holding,
        address _contract,
        uint256 _value,
        bytes calldata _call
    )
        external
        returns (bool success, bytes memory result);

    /**
     * @dev Allows the Default Admin to set a new address for `holdingImplementationReference` to be cloned from.
     *
     * Requirements:
     * - Caller must have the `DEFAULT_ADMIN_ROLE`.
     *  - `_newReference` should be valid address.
     *
     * Emits:
     * - `HoldingImplementationReferenceUpdated` event indicating that holding implementation reference
     * has been updated.
     *
     * @param _newReference The address of the new implementation reference.
     */
    function setHoldingImplementationReference(address _newReference) external;

    /**
     * @dev Prevents the renouncement of the default admin role by overriding beginDefaultAdminTransfer
     * @param newAdmin address of the new admin.
     */
    function beginDefaultAdminTransfer(address newAdmin) external;

    /**
     * @dev Get the address of the holding associated with the user.
     * @param _user The address of the user.
     * @return the holding address.
     */
    function getUserHolding(address _user) external view returns (address);

    /**
     * @dev Get the allowance for a generic caller to invoke contracts via a holding contract.
     *
     * @param _user The address of the user.
     * @param _genericCaller The address of the generic caller.
     * @param _callableContract The address of the contract to be invoked.
     * @return The number of invocations allowed for the specified contract by the generic caller
     * via the holding contract.
     */
    function getInvocationAllowance(
        address _user,
        address _genericCaller,
        address _callableContract
    )
        external
        view
        returns (uint256);
}
