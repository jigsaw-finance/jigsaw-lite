// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
 *
 * @notice `StakerManager` is a contract dedicated to distributing rewards to early users of Jigsaw.
 * @notice It accepts Lido's wstETH token as the underlying asset for staking and subsequent token distribution.
 * @notice wstETH tokens staked through StakerManager are deposited into Ion protocol's Pool contract to generate yield,
 * while also farming jPoints, which will later be exchanged for Jigsaw's governance $JIG tokens.
 *
 * @custom:security-contact @note Please add security-contact for further inquiries.
 */
contract StakingManager is IStakerManager, Pausable, ReentrancyGuard, AccessControlDefaultAdminRules {
    using SafeERC20 for IERC20;

    bytes32 public constant GENERIC_CALLER_ROLE = keccak256("GENERIC_CALLER");

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
    {
        underlyingAsset = _underlyingAsset;
        ionPool = _ionPool;
        staker = address(
            new Staker({
            _initialOwner:  _admin,
            _tokenIn: _underlyingAsset,
            _rewardToken: _rewardToken,
            _stakingManager: address(this),
            _rewardsDuration: _rewardsDuration
            })
        );
        holdingImplementationReference = address(new Holding());
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
    function unstake(address _to, uint256 _amount) external override nonReentrant whenNotPaused validAmount(_amount) {
        if (IStaker(staker).periodFinish() > block.timestamp) revert PreLockupPeriodUnstaking();
        address holding = userHolding[msg.sender];

        emit Unstaked(msg.sender, _amount);

        IHolding(holding).unstake({ _to: _to, _amount: _amount });
        IStaker(staker).exit({ _user: holding, _amount: _amount });
    }

    // --- Administration ---

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
        override
        onlyRole(GENERIC_CALLER_ROLE)
        nonReentrant
        returns (bool success, bytes memory result)
    {
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

    // --- Getters ---

    function _getUserHolding(address _user) public view returns (address) {
        return userHolding[_user];
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
