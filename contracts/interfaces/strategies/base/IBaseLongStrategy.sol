// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./IBaseStrategy.sol";

/// @title Interface for Base Strategy contract used in strategies that deal with borrowed liquidity
/// @author Daniel D. Alcarraz
/// @dev Only used to define LoanUpdated event to avoid redefining the event in all the strategies that deal with borrowed liquidity
interface IBaseLongStrategy is IBaseStrategy {
    /// @dev Event emitted when a Loan is updated
    /// @param tokenId - unique id that identifies the loan in question
    /// @param tokensHeld - amounts of tokens held as collateral against the loan
    /// @param liquidity - liquidity invariant that was borrowed including accrued interest
    /// @param lpTokens - LP tokens borrowed excluding interest (principal)
    /// @param rateIndex - interest rate index of GammaPool at time loan is updated
    event LoanUpdated(uint256 indexed tokenId, uint128[] tokensHeld, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);
}
