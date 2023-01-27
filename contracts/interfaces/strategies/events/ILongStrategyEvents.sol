// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./IStrategyEvents.sol";

/// @title Long Strategy Events Interface
/// @author Daniel D. Alcarraz LongStrategyEvents
/// @dev Events emitted by all long strategy implementations
interface ILongStrategyEvents is IStrategyEvents {
    /// @dev Event emitted when a Loan is updated
    /// @param tokenId - unique id that identifies the loan in question
    /// @param tokensHeld - amounts of tokens held as collateral against the loan
    /// @param liquidity - liquidity invariant that was borrowed including accrued interest
    /// @param lpTokens - LP tokens borrowed excluding interest (principal)
    /// @param rateIndex - interest rate index of GammaPool at time loan is updated
    event LoanUpdated(uint256 indexed tokenId, uint128[] tokensHeld, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);
}
