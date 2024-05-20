// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//Ion Pool Mock for testing deployment and interface verification
contract IonPool {
    using SafeERC20 for IERC20;

    address immutable underlyingAsset;
    address immutable addr;
    uint256 immutable val;

    mapping(address user => uint256 balance) userBalance;

    constructor(address _underlyingAsset) {
        underlyingAsset = _underlyingAsset;
    }

    function balanceOf(address user) external view returns (uint256) {
        return userBalance[user];
    }

    function debt() external view returns (uint256) {
        return val;
    }

    function getIlkAddress(uint256) external view returns (address) {
        return addr;
    }

    function supply(address user, uint256 amount, bytes32[] calldata) external {
        userBalance[user] += amount;
        IERC20(underlyingAsset).safeTransferFrom({ from: msg.sender, to: address(this), value: amount });
    }

    function withdraw(address to, uint256 amount) external {
        userBalance[msg.sender] -= amount;
        IERC20(underlyingAsset).safeTransfer({ to: to, value: amount });
    }
}
