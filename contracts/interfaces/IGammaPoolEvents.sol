// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./strategies/events/ILiquidationStrategyEvents.sol";
import "./strategies/events/IShortStrategyEvents.sol";

/// @title GammaPool Events Interface
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Events emitted by all GammaPool implementations (contains all strategy events)
interface IGammaPoolEvents is IShortStrategyEvents, ILiquidationStrategyEvents {
    /// @dev Event emitted when a Loan is created
    /// @param caller - address that created the loan
    /// @param tokenId - unique id that identifies the loan in question
    event LoanCreated(address indexed caller, uint256 tokenId);

    /// @dev Event emitted when synchronizing CFMM LP token amounts (CFMM LP tokens deposited do not match LP_TOKEN_BALANCE)
    /// @param oldLpTokenBalance - previous LP_TOKEN_BALANCE
    /// @param newLpTokenBalance - updated LP_TOKEN_BALANCE
    event Sync(uint256 oldLpTokenBalance, uint256 newLpTokenBalance);
}
