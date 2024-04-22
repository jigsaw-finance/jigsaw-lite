// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import { IERC20Metadata, IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SampleTokenERC20 } from "../utils/SampleTokenERC20.sol";
import { StakerWrapper as Staker } from "../utils/StakerWrapper.sol";

import { IStaker } from "../../src/interfaces/IStaker.sol";

contract StakerTest is Test {
    error InvalidAddress();
    error InvalidAmount();
    error UnauthorizedCaller();
    error PreviousPeriodNotFinished(uint256 timestamp, uint256 periodFinish);
    error ZeroRewardsDuration();
    error RewardAmountTooSmall();
    error RewardRateTooBig();
    error NoRewardsToDistribute();
    error DepositSurpassesSupplyLimit(uint256 _amount, uint256 supplyLimit);
    error NothingToClaim();
    error RenouncingOwnershipProhibited();

    error OwnableUnauthorizedAccount(address account);
    error ExpectedPause();
    error EnforcedPause();

    event SavedFunds(address indexed token, uint256 amount);
    event RewardsDurationUpdated(uint256 newDuration);
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    event Paused(address account);
    event Unpaused(address account);

    address internal OWNER = vm.addr(uint256(keccak256(bytes("Owner"))));
    address internal STAKING_MANAGER = vm.addr(uint256(keccak256(bytes("Staking Manager"))));

    address internal tokenIn;
    address internal rewardToken;
    uint256 internal rewardsDuration = 365 days;

    SampleTokenERC20 internal usdc;
    SampleTokenERC20 internal weth;
    Staker internal staker;

    function setUp() public {
        vm.startPrank(OWNER, OWNER);

        usdc = new SampleTokenERC20("USDC", "USDC", 0);
        weth = new SampleTokenERC20("WETH", "WETH", 0);

        tokenIn = address(new SampleTokenERC20("TokenIn", "TI", 0));
        rewardToken = address(new SampleTokenERC20("RewardToken", "RT", 0));

        staker = new Staker({
            _initialOwner: OWNER,
            _tokenIn: tokenIn,
            _rewardToken: rewardToken,
            _stakingManager: STAKING_MANAGER,
            _rewardsDuration: rewardsDuration
        });
        vm.stopPrank();
    }

    // Checks if initial state of the contract is correct
    function test_staker_initialState() public view {
        assertEq(staker.tokenIn(), tokenIn, "TokenIn set up incorrect");
        assertEq(staker.rewardToken(), rewardToken, "Reward token set up incorrect");
        assertEq(staker.owner(), OWNER, "Owner set up incorrect");
        assertEq(staker.rewardsDuration(), rewardsDuration, "Rewards duration set up incorrect");
        assertEq(staker.stakingManager(), STAKING_MANAGER, "Staking Manager set up incorrect");
    }

    // Tests if initialization of the contract with invalid arguments reverts correctly
    function test_init_staker_when_invalidInitialization() public {
        {
            vm.expectRevert();
            Staker failedStaker = new Staker({
                _initialOwner: address(0),
                _tokenIn: tokenIn,
                _rewardToken: rewardToken,
                _stakingManager: STAKING_MANAGER,
                _rewardsDuration: rewardsDuration
            });
            failedStaker;
        }
        {
            vm.expectRevert(InvalidAddress.selector);
            Staker failedStaker = new Staker({
                _initialOwner: OWNER,
                _tokenIn: address(0),
                _rewardToken: rewardToken,
                _stakingManager: STAKING_MANAGER,
                _rewardsDuration: rewardsDuration
            });
            failedStaker;
        }
        {
            vm.expectRevert(InvalidAddress.selector);
            Staker failedStaker = new Staker({
                _initialOwner: OWNER,
                _tokenIn: tokenIn,
                _rewardToken: address(0),
                _stakingManager: STAKING_MANAGER,
                _rewardsDuration: rewardsDuration
            });
            failedStaker;
        }
        {
            vm.expectRevert(InvalidAddress.selector);
            Staker failedStaker = new Staker({
                _initialOwner: OWNER,
                _tokenIn: tokenIn,
                _rewardToken: rewardToken,
                _stakingManager: address(0),
                _rewardsDuration: rewardsDuration
            });
            failedStaker;
        }
        {
            vm.expectRevert(InvalidAmount.selector);
            Staker failedStaker = new Staker({
                _initialOwner: OWNER,
                _tokenIn: tokenIn,
                _rewardToken: rewardToken,
                _stakingManager: STAKING_MANAGER,
                _rewardsDuration: 0
            });
            failedStaker;
        }
    }

    // Tests setting contract paused from non-Owner's address
    function test_setPaused_when_unauthorized(address _caller) public {
        vm.assume(_caller != staker.owner());
        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _caller));

        staker.pause();
    }

    // Tests setting contract paused from Owner's address
    function test_setPaused_when_authorized() public {
        //Sets contract paused and checks if after pausing contract is paused and event is emitted
        vm.startPrank(staker.owner(), staker.owner());
        vm.expectEmit();
        emit Paused(staker.owner());
        staker.pause();
        assertEq(staker.paused(), true);

        //Sets contract unpaused and checks if after pausing contract is unpaused and event is emitted
        vm.expectEmit();
        emit Unpaused(staker.owner());
        staker.unpause();
        assertEq(staker.paused(), false);
        vm.stopPrank();
    }

    // Tests if setRewardsDuration reverts correctly when caller is unauthorized
    function test_setRewardsDuration_when_unauthorized(address _caller) public {
        vm.assume(_caller != staker.owner());
        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _caller));
        staker.setRewardsDuration(1);
    }

    // Tests if setRewardsDuration reverts correctly when previous rewards period hasn't finished yet
    function test_setRewardsDuration_when_periodNotEnded() public {
        vm.startPrank(staker.owner(), staker.owner());
        vm.expectRevert(
            abi.encodeWithSelector(PreviousPeriodNotFinished.selector, block.timestamp, staker.periodFinish())
        );

        staker.setRewardsDuration(1);
        vm.stopPrank();
    }

    // Tests if setRewardsDuration works correctly when authorized
    function test_setRewardsDuration_when_authorized(uint256 _amount) public {
        vm.warp(block.timestamp + staker.rewardsDuration() + 1);
        vm.startPrank(staker.owner(), staker.owner());
        vm.expectEmit();
        emit RewardsDurationUpdated(_amount);
        staker.setRewardsDuration(_amount);
        vm.stopPrank();

        assertEq(staker.rewardsDuration(), _amount, "Rewards duration set incrorect");
    }

    // Tests if addRewards reverts correctly when caller is unauthorized
    function test_addRewards_when_unauthorized(address _caller) public {
        vm.assume(_caller != staker.owner());
        vm.prank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _caller));
        staker.addRewards(1);
    }

    // Tests if addRewards reverts correctly when amount == 0
    function test_addRewards_when_invalidAmount() public {
        vm.prank(staker.owner(), staker.owner());
        vm.expectRevert(InvalidAmount.selector);

        staker.addRewards(0);
    }

    // Tests if addRewards reverts correctly when rewardsDuration == 0
    function test_addRewards_when_rewardsDuration0() public {
        // We fast forward to the period when current reward distribution ends,
        // so we can change the reward duration
        vm.warp(block.timestamp + staker.rewardsDuration() + 1);

        vm.startPrank(staker.owner(), staker.owner());
        staker.setRewardsDuration(0);
        vm.expectRevert(ZeroRewardsDuration.selector);
        staker.addRewards(1);
        vm.stopPrank();
    }

    // Tests if addRewards reverts correctly when _amount is small, which leads to rewardRate being 0
    function test_addRewards_when_amountTooSmall(uint256 _amount) public {
        vm.assume(_amount != 0 && _amount / staker.rewardsDuration() == 0);

        vm.prank(staker.owner(), staker.owner());
        vm.expectRevert(RewardAmountTooSmall.selector);

        staker.addRewards(_amount);
    }

    // Tests if addRewards reverts correctly when contract doesn't have enough balance to add rewards
    function test_addRewards_when_insufficientBalance(uint256 _amount) public {
        console.log(IERC20(rewardToken).balanceOf(address(staker)));
        vm.assume(_amount / staker.rewardsDuration() != 0);

        vm.prank(staker.owner(), staker.owner());
        vm.expectRevert(RewardRateTooBig.selector);
        staker.addRewards(_amount);
    }

    // Tests if addRewards works correctly when block.timestamp >= periodFinish
    function test_addRewards_when_periodFinished(uint256 _amount) public {
        vm.assume(_amount / staker.rewardsDuration() != 0);
        // We fast forward to the period when current reward distribution ends,
        // so we can test block.timestamp >= periodFinish branch
        vm.warp(block.timestamp + staker.rewardsDuration() + 1);
        deal(staker.rewardToken(), address(staker), _amount);

        vm.startPrank(staker.owner(), staker.owner());
        vm.expectEmit();
        emit RewardAdded(_amount);
        staker.addRewards(_amount);

        assertEq(staker.rewardRate(), _amount / staker.rewardsDuration(), "Rewards added incorrectly");
    }

    // Tests if addRewards works correctly when block.timestamp < periodFinish
    function test_addRewards_when_periodNotFinished(uint256 _amount) public {
        vm.assume(_amount / staker.rewardsDuration() != 0);

        deal(staker.rewardToken(), address(staker), _amount);

        vm.startPrank(staker.owner(), staker.owner());
        vm.expectEmit();
        emit RewardAdded(_amount);
        staker.addRewards(_amount);

        assertEq(staker.rewardRate(), _amount / staker.rewardsDuration(), "Rewards added incorrectly");
    }

    // Tests if totalSuply works correctly
    function test_totalSupply(uint256 _amount, address _caller) public {
        vm.assume(_amount != 0 && _amount <= 1e34);
        vm.assume(_caller != address(0));

        deal(rewardToken, address(staker), 1);
        deal(tokenIn, _caller, _amount);

        vm.prank(_caller, _caller);
        IERC20Metadata(tokenIn).approve(address(staker), _amount);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(_caller, _amount);

        assertEq(staker.totalSupply(), _amount, "Total supply incorrect");
    }

    // Tests if balanceOf works correctly
    function test_balanceOf(uint256 _amount, address _caller) public {
        vm.assume(_amount != 0 && _amount <= 1e34);
        vm.assume(_caller != address(0));

        deal(rewardToken, address(staker), 1);
        deal(tokenIn, _caller, _amount);

        vm.prank(_caller, _caller);
        IERC20Metadata(tokenIn).approve(address(staker), _amount);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(_caller, _amount);

        assertEq(staker.balanceOf(_caller), _amount, "Balance of investor incorrect");
    }

    // Tests if lastTimeRewardApplicable works correctly
    function test_lastTimeRewardApplicable() public view {
        assertEq(
            staker.lastTimeRewardApplicable(),
            block.timestamp < staker.periodFinish() ? block.timestamp : staker.periodFinish(),
            "lastTimeRewardApplicable incorrect"
        );
    }

    // Tests if rewardPerToken works correctly
    function test_rewardPerToken_when_totalSupplyNot0(uint256 investment) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));

        deal(rewardToken, address(staker), 1e18);
        deal(tokenIn, investor, investment);

        vm.startPrank(staker.owner(), staker.owner());
        staker.addRewards(1e18);
        vm.stopPrank();

        vm.prank(investor, investor);
        IERC20Metadata(tokenIn).approve(address(staker), investment);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(investor, investment);

        // We fast forward 10 days to have some rewards generated
        uint256 warpAmount = 10 days;
        vm.warp(block.timestamp + warpAmount);

        assertEq(
            staker.rewardPerToken(),
            staker.rewardPerTokenStored() + ((warpAmount * staker.rewardRate() * 1e18) / staker.totalSupply()),
            "Reward per token incorrect"
        );
    }

    // Tests if getRewardForDuration works correctly
    function test_getRewardForDuration(uint256 _amount) public {
        vm.assume(_amount / staker.rewardsDuration() != 0);
        deal(rewardToken, address(staker), _amount);
        vm.prank(staker.owner(), staker.owner());
        staker.addRewards(_amount);

        assertEq(
            staker.getRewardForDuration(),
            staker.rewardRate() * staker.rewardsDuration(),
            "RewardForDuration incorrect "
        );
    }

    // Tests if deposit reverts correctly when invalid amount
    function test_deposit_when_invalidAmount() public {
        vm.prank(staker.stakingManager(), staker.stakingManager());
        vm.expectRevert(InvalidAmount.selector);
        staker.deposit(address(1), 0);
    }

    // Tests if deposit reverts correctly when caller is unauthorized
    function test_deposit_when_unauthorized() public {
        vm.expectRevert(UnauthorizedCaller.selector);
        staker.deposit(address(1), 1);
    }

    // Tests if deposit reverts correctly when paused
    function test_deposit_when_paused() public {
        vm.prank(staker.owner(), staker.owner());
        staker.pause();

        vm.prank(staker.stakingManager(), staker.stakingManager());
        vm.expectRevert(EnforcedPause.selector);

        staker.deposit(address(1), 1);
    }

    // Tests if deposit reverts correctly when contract's reward balance is insufficient
    function test_deposit_when_insufficientRewards() public {
        vm.prank(staker.stakingManager(), staker.stakingManager());
        vm.expectRevert(NoRewardsToDistribute.selector);
        staker.deposit(address(1), 1);
    }

    // Tests if deposit reverts correctly when reached supply limit
    function test_deposit_when_reachedSupplyLimit() public {
        deal(staker.rewardToken(), address(staker), 1);

        vm.startPrank(staker.stakingManager(), staker.stakingManager());
        vm.expectRevert(
            abi.encodeWithSelector(DepositSurpassesSupplyLimit.selector, type(uint256).max, staker.totalSupplyLimit())
        );
        staker.deposit(address(1), type(uint256).max);
        vm.stopPrank();
    }

    // Tests if deposit works correctly
    function test_deposit_when_authorized(uint256 investment) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));

        deal(rewardToken, address(staker), 1e18);
        deal(tokenIn, investor, investment);

        vm.prank(staker.owner(), staker.owner());
        staker.addRewards(1e18);

        vm.prank(investor, investor);
        IERC20Metadata(tokenIn).approve(address(staker), investment);

        vm.expectEmit();
        emit Staked(investor, investment);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(investor, investment);

        vm.stopPrank();

        assertEq(staker.balanceOf(investor), investment, "Investor's balance after deposit incorrect");
        assertEq(staker.totalSupply(), investment, "Total supply after deposit incorrect");
    }

    // Tests if withdraw reverts correctly when invalid amount
    function test_withdraw_when_invalidAmount() public {
        vm.prank(staker.stakingManager(), staker.stakingManager());
        vm.expectRevert(InvalidAmount.selector);
        staker.withdraw_wrapper(address(1), 0);
    }

    // Tests if withdraw works correctly when authorized
    function test_withdraw_when_authorized(uint256 investment) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));

        deal(rewardToken, address(staker), 1e18);
        deal(tokenIn, investor, investment);

        vm.startPrank(staker.owner(), staker.owner());
        staker.addRewards(1e18);
        vm.stopPrank();

        vm.prank(investor, investor);
        IERC20Metadata(tokenIn).approve(address(staker), investment);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(investor, investment);

        vm.expectEmit();
        emit Withdrawn(investor, investment);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.withdraw_wrapper(investor, investment);

        assertEq(staker.balanceOf(investor), 0, "Investor's balance after withdraw incorrect");
        assertEq(staker.totalSupply(), 0, "Total supply after withdraw incorrect");
    }

    // Tests if claimRewards reverts correctly when there are no rewards to claim
    function test_claimRewards_when_noRewards() public {
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));
        uint256 investorRewardBalanceBefore = IERC20Metadata(rewardToken).balanceOf(investor);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        vm.expectRevert(NothingToClaim.selector);
        staker.claimRewards_wrapper(investor, investor);

        assertEq(
            IERC20Metadata(rewardToken).balanceOf(investor),
            investorRewardBalanceBefore,
            "Investor wrongfully got rewards when never deposited"
        );
    }

    // Tests if claimRewards fails if user has already withdrawn his investment
    function test_claimRewards_when_investmentWithdrawn(uint256 investment) public {
        vm.assume(investment > 2 && investment < 1e25);
        address investor1 = vm.addr(uint256(keccak256(bytes("Investor1"))));
        address investor2 = vm.addr(uint256(keccak256(bytes("Investor2"))));

        deal(rewardToken, address(staker), 1e18);
        deal(tokenIn, investor1, investment);
        deal(tokenIn, investor2, investment / 2);

        vm.startPrank(staker.owner(), staker.owner());
        staker.addRewards(1e18);
        vm.stopPrank();

        vm.prank(investor1, investor1);
        IERC20Metadata(tokenIn).approve(address(staker), investment);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(investor1, investment);

        vm.prank(investor2, investor2);
        IERC20Metadata(tokenIn).approve(address(staker), investment / 2);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(investor2, investment / 2);

        vm.warp(block.timestamp + 30 days);
        uint256 rewardsPerTokenBeforeExit = staker.rewardPerToken();

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.exit(investor1, investor1);

        vm.warp(block.timestamp + 30 days);

        assertEq(staker.rewards(investor1), 0, "Investor wrongfully got rewards after full withdrawal");
        assertGt(staker.rewardPerToken(), rewardsPerTokenBeforeExit, "rewardPerToken didn't increase");
    }

    // Tests if claimRewards works correctly when authorized
    function test_claimRewards_when_authorized(uint256 investment) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));

        uint256 stakerRewardBalance = 10_000e18;

        deal(rewardToken, address(staker), stakerRewardBalance);
        deal(tokenIn, investor, investment);

        vm.prank(staker.owner(), staker.owner());
        staker.addRewards(1e18);

        vm.prank(investor, investor);
        IERC20Metadata(tokenIn).approve(address(staker), investment);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(investor, investment);

        // We fast forward 10 days to have some rewards generated
        uint256 warpAmount = 10 days;
        vm.warp(block.timestamp + warpAmount);

        uint256 investorRewards = staker.earned(investor);

        vm.expectEmit();
        emit RewardPaid(investor, investorRewards);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.exit(investor, investor);

        assertEq(
            IERC20Metadata(rewardToken).balanceOf(investor),
            investorRewards,
            "Investor's reward balance wrong after claimRewards"
        );
        assertEq(
            IERC20Metadata(rewardToken).balanceOf(address(staker)),
            stakerRewardBalance - investorRewards,
            "Staker's reward balance wrong after claimRewards"
        );
        assertEq(staker.rewards(investor), 0, "Investor's rewards count didn't change  after claimRewards");
    }

    // Tests if exit reverts correctly when caller is unauthorized
    function test_exit_when_unauthorized() public {
        vm.expectRevert(UnauthorizedCaller.selector);
        staker.exit(address(1), address(1));
    }

    // Tests if exit works correctly when authorized
    function test_exit_when_authorized(uint256 investment) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));

        uint256 stakerRewardBalance = 10_000e18;

        deal(rewardToken, address(staker), stakerRewardBalance);
        deal(tokenIn, investor, investment);

        vm.prank(staker.owner(), staker.owner());
        staker.addRewards(1e18);

        vm.prank(investor, investor);
        IERC20Metadata(tokenIn).approve(address(staker), investment);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.deposit(investor, investment);

        // We fast forward 10 days to have some rewards generated
        uint256 warpAmount = 10 days;
        vm.warp(block.timestamp + warpAmount);

        uint256 investorRewards = staker.earned(investor);

        vm.expectEmit();
        emit Withdrawn(investor, investment);

        emit RewardPaid(investor, investorRewards);

        vm.prank(staker.stakingManager(), staker.stakingManager());
        staker.exit(investor, investor);

        assertEq(staker.balanceOf(investor), 0, "Investor's balance after exit incorrect");
        assertEq(staker.totalSupply(), 0, "Total supply after exit incorrect");
        assertEq(
            IERC20Metadata(rewardToken).balanceOf(investor),
            investorRewards,
            "Investor's reward balance wrong after claimRewards"
        );
        assertEq(
            IERC20Metadata(rewardToken).balanceOf(address(staker)),
            stakerRewardBalance - investorRewards,
            "Staker's reward balance wrong after claimRewards"
        );
        assertEq(staker.rewards(investor), 0, "Investor's rewards count didn't change  after claimRewards");
    }

    //Tests if renouncing ownership reverts correctly
    function test_renounceOwnership_staker() public {
        vm.expectRevert(RenouncingOwnershipProhibited.selector);
        staker.renounceOwnership();
    }
}
