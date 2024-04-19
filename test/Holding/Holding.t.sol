// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { Holding } from "../../src/Holding.sol";

contract StakingManagerForkTest is Test {
    error ZeroAddress();

    address internal holdingReferenceImplementation;

    function setUp() public {
        holdingReferenceImplementation = address(new Holding());
    }

    // Tests if initializtion with invalid params reverts correctly
    function test_init_when_invalidInitParams() public {
        address newHolding = Clones.clone(holdingReferenceImplementation);

        vm.expectRevert(ZeroAddress.selector);
        Holding(newHolding).init({ _holdingManager: address(0) });
    }
}
