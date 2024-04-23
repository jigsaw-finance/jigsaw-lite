// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Staker } from "../../src/Staker.sol";

import { IStaker } from "../../src/interfaces/IStaker.sol";

contract StakerWrapper is Staker {
    constructor(
        address _initialOwner,
        address _tokenIn,
        address _rewardToken,
        address _stakingManager,
        uint256 _rewardsDuration
    )
        Staker(_initialOwner, _tokenIn, _rewardToken, _stakingManager, _rewardsDuration)
    { }

    function withdraw_wrapper(address _user, uint256 _amount) public {
        super.withdraw(_user, _amount);
    }

    function claimRewards_wrapper(address _user, address _to) public {
        super.claimRewards(_user, _to);
    }
}
