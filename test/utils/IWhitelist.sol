// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWhitelist {
    /**
     * @notice Approves a protocol controlled address to bypass the merkle proof check.
     * @param addr The address to approve.
     */
    function approveProtocolWhitelist(address addr) external;
}
