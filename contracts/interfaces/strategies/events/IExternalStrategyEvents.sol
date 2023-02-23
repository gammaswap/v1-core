// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./IStrategyEvents.sol";

/// @title External Strategy Events Interface
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Events emitted by external strategy (flash loans) implementations
interface IExternalStrategyEvents is IStrategyEvents {
    /// @dev Event emitted when a flash loan is made. Purpose of flash loan is for external swaps/rebalance of loan collateral
    /// @param tokenId - unique id that identifies the loan in question
    /// @param amounts - amounts of tokens held as collateral in pool that were swapped
    /// @param lpTokens - LP tokens swapped externally
    /// @param liquidity - total liquidity externally swapped in flash loan (amounts + lpTokens)
    /// @param txType - transaction type. Possible values come from enum TX_TYPE
    event ExternalSwap(uint256 indexed tokenId, uint128[] amounts, uint256 lpTokens, uint128 liquidity, TX_TYPE indexed txType);
}
