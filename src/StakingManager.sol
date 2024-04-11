// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AccessControlDefaultAdminRules } from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Holding } from "./Holding.sol";
import { Staker } from "./Staker.sol";

import { IHolding } from "./interfaces/IHolding.sol";
import { IIonPool } from "./interfaces/IIonPool.sol";
import { IStakerManager } from "./interfaces/IStakerManager.sol";
import { IStaker } from "./interfaces/IStaker.sol";

/**
 * @title StakingManager
 *
 * @notice Manages the distribution of rewards to early users of Jigsaw by staking Lido's wstETH tokens.
 * @notice wstETH tokens are staked through this contract and deposited into the Ion protocol's Pool contract to
 * generate yield.
 * @notice Additionally, stakers farm jPoints, which will later be exchanged for Jigsaw's governance $JIG tokens.
 *
 * @dev This contract inherits functionalities from `Pausable`, `ReentrancyGuard`, and `AccessControlDefaultAdminRules`.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract StakingManager is IStakerManager, Pausable, ReentrancyGuard, AccessControlDefaultAdminRules {
    using SafeERC20 for IERC20;

    /**
     * Declaration of the Generic Caller role - privileged actor, allowed to perform low level calls on Holdings.
     */
    bytes32 public constant GENERIC_CALLER_ROLE = keccak256("GENERIC_CALLER");

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

    /**
     * @dev Address of holding implementation to be cloned from
     */
    address public override holdingImplementationReference;

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
     * After this date, staked funds can be withdrawn. If not withdrawn will continue to
     * generate wstETH rewards and, if applicable, additional jPoints as long as staked.
     *
     * @return The expiration date for the staking lockup period, in Unix timestamp format.
     */
    uint256 public override lockupExpirationDate;

    // --- Modifiers ---

    /**
     * @dev Modifier to check if the provided amount is valid.
     * @param _amount The amount to be checked for validity.
     */
    modifier validAmount(uint256 _amount) {
        if (_amount == 0) revert InvalidAmount();
        _;
    }

    /**
     * @dev Modifier to check if the provided address is valid.
     * @param _address The address to be checked for validity.
     */
    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }

    /**
     * @dev Constructor function for initializing the StakerManager contract.
     * @param _underlyingAsset Address of the underlying asset used for staking.
     * @param _ionPool Address of the ionPool contract.
     */
    constructor(
        address _admin,
        address _underlyingAsset,
        address _rewardToken,
        address _ionPool,
        uint256 _rewardsDuration
    )
        AccessControlDefaultAdminRules(
            2 days,
            _admin // Explicit initial `DEFAULT_ADMIN_ROLE` holder
        )
        validAddress(_admin)
        validAddress(_underlyingAsset)
        validAddress(_rewardToken)
        validAddress(_ionPool)
        validAmount(_rewardsDuration)
    {
        underlyingAsset = _underlyingAsset;
        rewardToken = _rewardToken;
        ionPool = _ionPool;
        staker = address(
            new Staker({
                _initialOwner: _admin,
                _tokenIn: _underlyingAsset,
                _rewardToken: _rewardToken,
                _stakingManager: address(this),
                _rewardsDuration: _rewardsDuration
            })
        );
        holdingImplementationReference = address(new Holding());
        lockupExpirationDate = block.timestamp + _rewardsDuration;
    }

    /**
     * @notice Stakes a specified amount of assets for the msg.sender.
     * @dev Initiates the staking operation by transferring the specified `_amount`
     * from the user's wallet to the contract, while simultaneously recording this deposit within the Jigsaw Staking
     * Contract.
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
     * @param _amount The amount of assets to stake.
     */
    function stake(uint256 _amount) external override nonReentrant whenNotPaused validAmount(_amount) {
        address holding = userHolding[msg.sender];

        // Create a holding for msg.sender if there is no holding associated with their address yet.
        if (holding == address(0)) holding = _createHolding();

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
     * @notice Withdraws a all staked assets.
     *
     * @dev Initiates the withdrawal of staked assets by transferring all the deposited assets plus generated rewards
     * from the Ion Pool contract to the designated recipient `_to`.
     *
     * Requirements:
     * - The caller must have sufficient staked assets to fulfill the withdrawal.
     * - The `_to` address must be a valid Ethereum address.
     *
     * @param _to The address to receive the unstaked assets.
     */
    function unstake(address _to) external override nonReentrant whenNotPaused validAddress(_to) {
        if (lockupExpirationDate > block.timestamp) revert PreLockupPeriodUnstaking();
        address holding = userHolding[msg.sender];

        uint256 ionPoolBalance = IIonPool(ionPool).balanceOf(holding);
        if (ionPoolBalance == 0) revert NothingToWithdrawFromIon(msg.sender);

        emit Unstaked(msg.sender, IStaker(staker).balanceOf(holding));

        IHolding(holding).unstake({ _to: _to, _amount: ionPoolBalance });
        IStaker(staker).exit({ _user: holding, _to: _to });
    }

    /**
     * @dev Sets the allowance for a generic caller to invoke contracts via a holding contract.
     *
     * Requirements:
     * - `_genericCaller` must be a valid address.
     * - `_callableContract` must be a valid address.
     * - The caller must have a holding contract associated with their address.
     * - The `_genericCaller` must have the `GENERIC_CALLER_ROLE`.
     *
     * Effects:
     * - Emits an `InvocationSet` event upon successful execution.
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
     * @param _call The call data.
     *
     * @return success Indicates whether the call was successful or not.
     * @return result Data obtained from the external call.
     */
    function invokeHolding(
        address _holding,
        address _contract,
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
        (success, result) = IHolding(_holding).genericCall({ _contract: _contract, _call: _call });
    }

    /**
     * @dev Triggers stopped state.
     */
    function pause() external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     */
    function unpause() external override onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        _unpause();
    }

    /**
     * @dev Prevents the renouncement of the default admin role by overriding beginDefaultAdminTransfer
     */
    function beginDefaultAdminTransfer(address newAdmin)
        public
        override(AccessControlDefaultAdminRules, IStakerManager)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newAdmin == address(0)) revert RenouncingDefaultAdminRoleProhibited();
        _beginDefaultAdminTransfer(newAdmin);
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
    function setLockupExpirationDate(uint256 _newDate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit LockupExpirationDateUpdated(lockupExpirationDate, _newDate);
        lockupExpirationDate = _newDate;
    }

    /**
     * @dev Allows the default admin role to set a new holdingImplementationReference.
     *
     * Requirements:
     * - Caller must have the DEFAULT_ADMIN_ROLE.
     *
     * Emits:
     * - `HoldingImplementationReferenceUpdated` event indicating that holding implementation reference
     * has been updated.
     *
     * @param _newReference The address of the new implementation reference.
     */
    function setHoldingImplementationReference(address _newReference)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(_newReference)
    {
        emit HoldingImplementationReferenceUpdated(_newReference);
        holdingImplementationReference = _newReference;
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
        IHolding(newHoldingAddress).init({ _stakingManager: address(this), _ionPool: ionPool });
    }
}
