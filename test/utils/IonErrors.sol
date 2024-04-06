// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

contract Errors {
    // IonPool Errors
    error CeilingExceeded(uint256 newDebt, uint256 debtCeiling);
    error UnsafePositionChange(uint256 newTotalDebtInVault, uint256 collateral, uint256 spot);
    error UnsafePositionChangeWithoutConsent(uint8 ilkIndex, address user, address unconsentedOperator);
    error GemTransferWithoutConsent(uint8 ilkIndex, address user, address unconsentedOperator);
    error UseOfCollateralWithoutConsent(uint8 ilkIndex, address depositor, address unconsentedOperator);
    error TakingWethWithoutConsent(address payer, address unconsentedOperator);
    error VaultCannotBeDusty(uint256 amountLeft, uint256 dust);
    error ArithmeticError();
    error IlkAlreadyAdded(address ilkAddress);
    error IlkNotInitialized(uint256 ilkIndex);
    error DepositSurpassesSupplyCap(uint256 depositAmount, uint256 supplyCap);
    error MaxIlksReached();

    error InvalidIlkAddress();
    error InvalidWhitelist();

    // YieldOracle Errors

    error InvalidExchangeRate(uint256 ilkIndex);
    error InvalidIlkIndex(uint256 ilkIndex);
    error AlreadyUpdated();

    // PausableUpgradeable Errors
    error EnforcedPause();
    error ExpectedPause();
    error InvalidInitialization();
    error NotInitializing();

    // TransparentUpgradeableProxy Errors
    error ProxyDeniedAdminAccess();

    // AccessControl Errors
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error AccessControlBadConfirmation();

    // UniswapFlashswapDirectMintHandler
    error InvalidUniswapPool();
    error InvalidZeroLiquidityRegionSwap();
    error CallbackOnlyCallableByPool(address unauthorizedCaller);
    error OutputAmountNotReceived(uint256 amountReceived, uint256 amountRequired);

    error InvalidBurnAmount();
    error InvalidMintAmount();
    error InvalidUnderlyingAddress();
    error InvalidTreasuryAddress();
    error InvalidSender(address sender);
    error InvalidReceiver(address receiver);
    error InsufficientBalance(address account, uint256 balance, uint256 needed);
}
