// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHolding {
    // --- Errors ---
    /**
     * @dev The operation failed because caller was unauthorized for the action.
     */
    error UnauthorizedCaller();

    /**
     * @dev The operation failed because provided address is zero.
     */
    error ZeroAddress();

    // --- Events ---
    /**
     * @dev emitted when participant unstaked
     *
     * @param holding address the tokens are being unstaked from.
     * @param to address receiving the unstaked tokens.
     * @param amount of tokens unstaked.
     */
    event Unstaked(address indexed holding, address indexed to, uint256 indexed amount);

    /**
     * @notice Returns the HoldingManager address.
     */
    function holdingManager() external view returns (address);

    /**
     * @dev Initializes the contract (instead of a constructor) to be cloned.
     * @param _holdingManager The address of the contract handling staking operations.
     */
    function init(address _holdingManager) external;

    /**
     * @notice Allows to withdraw a specified amount of tokens to a designated address from Ion Pool.
     * @dev Only accessible by the staking manager and protected against reentrancy.
     *
     * @param _pool The address of the pool from which to withdraw underlying assets.
     * @param _to Address to which the redeemed underlying asset should be sent to.
     * @param _amount of underlying to redeem for.
     */
    function unstake(address _pool, address _to, uint256 _amount) external;

    /**
     * @notice Executes a generic call to interact with another contract.
     * @dev This function is restricted to be called only by Staking Manager contract
     * aimed at mitigating potential risks associated with unauthorized calls.
     *
     * @param _contract The address of the target contract for the call.
     * @param _call ABI-encoded data representing the call to be made.
     *
     * @return success A boolean indicating whether the call was successful or not.
     * @return result The result of the call as bytes.
     */
    function genericCall(
        address _contract,
        bytes calldata _call
    )
        external
        returns (bool success, bytes memory result);
}
