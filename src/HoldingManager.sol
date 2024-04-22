// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AccessControlDefaultAdminRules } from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { Holding } from "./Holding.sol";

import { IHolding } from "./interfaces/IHolding.sol";
import { IHoldingManager } from "./interfaces/IHoldingManager.sol";

/**
 * @title HoldingManager
 *
 * @notice Manages holding creation, management, and interaction for a more secure and dynamic flow.
 * @notice The HoldingManager contract allows for the creation of holding contracts, unstaking funds from these
 * holdings, and management of the holding implementation reference.
 *
 * @dev This contract inherits functionalities from `ReentrancyGuard` and `AccessControlDefaultAdminRules`.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract HoldingManager is IHoldingManager, ReentrancyGuard, AccessControlDefaultAdminRules {
    /**
     * Declaration of the Staking Manager role - privileged actor, allowed to call unstake function on Holdings.
     */
    bytes32 public constant override STAKING_MANAGER_ROLE = keccak256("STAKING_MANAGER");

    /**
     * Declaration of the Generic Caller role - privileged actor, allowed to perform low level calls on Holdings.
     */
    bytes32 public constant override GENERIC_CALLER_ROLE = keccak256("GENERIC_CALLER");

    /**
     * @dev Address of holding implementation to be cloned from.
     */
    address public override holdingImplementationReference;

    /**
     * @notice Stores a mapping of each user to their holding.
     * @dev returns holding address.
     */
    mapping(address => address) private userHolding;

    /**
     * @dev Tracks allowances for each generic caller to invoke contracts via a holding contract.
     * @dev Structure: holding => generic caller => contract to be invoked => number of invocations allowed
     */
    mapping(address => mapping(address => mapping(address => uint256))) private holdingToCallerToContractAllowance;

    // --- Modifiers ---

    /**
     * @dev Modifier to check if the provided address is valid.
     * @param _address The address to be checked for validity.
     */
    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }

    // --- Constructor ---

    /**
     * @dev Constructor function for initializing the HoldingManager contract.
     * @param _admin Address of the initial admin who has the DEFAULT_ADMIN_ROLE.
     */
    constructor(address _admin) AccessControlDefaultAdminRules(2 days, _admin) {
        holdingImplementationReference = address(new Holding());
    }

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
        external
        override
        validAddress(_genericCaller)
        validAddress(_callableContract)
    {
        // Ensure that the caller has a holding contract associated with their address
        address holding = userHolding[msg.sender];
        if (holding == address(0)) revert MissingHoldingContractForUser(msg.sender);

        // Ensure that the specified `_genericCaller` address has the `GENERIC_CALLER_ROLE`
        _checkRole({ role: GENERIC_CALLER_ROLE, account: _genericCaller });

        // Set the allowance for `_callableContract` by `_genericCaller` for the user's holding contract
        holdingToCallerToContractAllowance[holding][_genericCaller][_callableContract] = _invocationsAllowance;

        // Emit an event indicating that an invocation allowance has been set
        emit InvocationAllowanceSet(holding, _genericCaller, _callableContract, _invocationsAllowance);
    }

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
    function createHolding(address _user) external override onlyRole(STAKING_MANAGER_ROLE) returns (address holding) {
        // Create a new holding contract instance
        holding = Clones.clone(holdingImplementationReference);
        // Associate the new holding contract with specified `_user`
        userHolding[_user] = holding;

        // Emit an event to notify of the creation of the holding contract
        emit HoldingCreated(_user, holding);

        // Initialize the newly created holding contract
        IHolding(holding).init({ _holdingManager: address(this) });
    }

    /**
     * @dev Unstake funds from a the specified Ion Protocol's `_pool` contract for `_holding`.
     *
     * @param _holding address to unstake for.
     * @param _pool address of Ion's pool.
     * @param _to The address where unstaked tokens will be sent.
     * @param _amount The amount of tokens to unstake.
     */
    function unstake(
        address _holding,
        address _pool,
        address _to,
        uint256 _amount
    )
        external
        override
        onlyRole(STAKING_MANAGER_ROLE)
    {
        IHolding(_holding).unstake(_pool, _to, _amount);
    }

    // --- Administration ---

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
        override
        validAddress(_holding)
        validAddress(_contract)
        onlyRole(GENERIC_CALLER_ROLE)
        nonReentrant
        returns (bool success, bytes memory result)
    {
        // Ensure that caller has enough allowance to perform generic call on specified contract address
        if (holdingToCallerToContractAllowance[_holding][msg.sender][_contract] == 0) {
            revert InvocationNotAllowed(msg.sender);
        }

        // Decrease generic caller's allowance by 1
        holdingToCallerToContractAllowance[_holding][msg.sender][_contract]--;

        // Perform the generic call
        (success, result) = IHolding(_holding).genericCall({ _contract: _contract, _value: _value, _call: _call });
    }

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
    function setHoldingImplementationReference(address _newReference)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(_newReference)
    {
        emit HoldingImplementationReferenceUpdated(_newReference);
        holdingImplementationReference = _newReference;
    }

    /**
     * @dev Prevents the renouncement of the default admin role by overriding beginDefaultAdminTransfer
     * @param newAdmin address of the new admin.
     */
    function beginDefaultAdminTransfer(address newAdmin)
        public
        override(AccessControlDefaultAdminRules, IHoldingManager)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newAdmin == address(0)) revert RenouncingDefaultAdminRoleProhibited();
        _beginDefaultAdminTransfer(newAdmin);
    }

    // --- Getters ---

    /**
     * @dev Get the address of the holding associated with the user.
     * @param _user The address of the user.
     * @return the holding address.
     */
    function getUserHolding(address _user) external view override returns (address) {
        return userHolding[_user];
    }

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
        override
        returns (uint256)
    {
        return holdingToCallerToContractAllowance[userHolding[_user]][_genericCaller][_callableContract];
    }
}
