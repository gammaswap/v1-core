// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../base/ILongStrategy.sol";
import "../events/IExternalStrategyEvents.sol";

/// @title Interface for External Rebalance Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used to rebalance loan's collateral using a flash loan.
interface IExternalRebalanceStrategy is ILongStrategy, IExternalStrategyEvents {
    /// @dev Flash loan pool's collateral and/or lp tokens to external address. Rebalanced loan collateral is acceptable in  repayment of flash loan
    /// @param tokenId - unique id identifying loan
    /// @param amounts - collateral amounts being flash loaned
    /// @param lpTokens - amount of CFMM LP tokens being flash loaned
    /// @param to - address that will receive flash loan swaps and potentially rebalance loan's collateral
    /// @param data - optional bytes parameter for custom user defined data
    /// @return loanLiquidity - updated loan liquidity, includes flash loan fees
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _rebalanceExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external returns(uint256 loanLiquidity, uint128[] memory tokensHeld);
}
