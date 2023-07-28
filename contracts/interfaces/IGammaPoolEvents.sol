// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./strategies/events/ILiquidationStrategyEvents.sol";
import "./strategies/events/IShortStrategyEvents.sol";
import "./strategies/events/IExternalStrategyEvents.sol";

/// @title GammaPool Events Interface
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Events emitted by all GammaPool implementations (contains all strategy events)
interface IGammaPoolEvents is IShortStrategyEvents, ILiquidationStrategyEvents, IExternalStrategyEvents {
    /// @dev Event emitted when a Loan is created
    /// @param caller - address that created the loan
    /// @param tokenId - unique id that identifies the loan in question
    /// @param refId - Reference id of post transaction activities attached to this loan
    event LoanCreated(address indexed caller, uint256 tokenId, uint16 refId);
}
