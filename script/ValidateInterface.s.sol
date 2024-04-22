// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IIonPool } from "../test/utils/IIonPool.sol";
import { IHoldingManager } from "../src/interfaces/IHoldingManager.sol";

/**
 * @notice Validates that an address implements the expected interface by
 * checking there is code at the provided address and calling a few functions.
 */
abstract contract ValidateInterface {
    function _validateInterface(IHoldingManager holdingManager) internal view {
        require(address(holdingManager).code.length > 0, "HoldingManager address must have code");
        holdingManager.getUserHolding(address(this));
        holdingManager.getInvocationAllowance(address(this), address(this), address(this));
    }

    function _validateInterface(IIonPool ionPool) internal view {
        require(address(ionPool).code.length > 0, "ionPool address must have code");
        ionPool.balanceOf(address(this));
        ionPool.debt();
        ionPool.getIlkAddress(0);
    }

    function _validateInterface(IERC20 tokenAddress) internal view {
        require(address(tokenAddress).code.length > 0, "Token address must have code");
        tokenAddress.balanceOf(address(this));
        tokenAddress.totalSupply();
        tokenAddress.allowance(address(this), address(this));
    }
}
