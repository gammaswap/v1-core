// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../base/ILiquidationStrategy.sol";
import "../events/IExternalStrategyEvents.sol";

/// @title Interface for External Liquidation Strategy contracts
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used to liquidate loans using a flash loan. Purpose of flash loan is for external swaps/rebalance of loan collateral
interface IExternalLiquidationStrategy is ILiquidationStrategy, IExternalStrategyEvents {
    /// @notice The entire pool's collateral is available in the flash loan. Flash loan must result in a net CFMM LP token deposit that repays loan's liquidity debt
    /// @dev Function to liquidate a loan using using a flash loan of collateral tokens from the pool and/or CFMM LP tokens. Seeks full liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @param amounts - amount collateral tokens from the pool to flash loan
    /// @param lpTokens - amount of CFMM LP tokens being flash loaned
    /// @param to - address that will receive the collateral tokens and/or lpTokens in flash loan
    /// @param data - optional bytes parameter for custom user defined data
    /// @return loanLiquidity - loan liquidity liquidated (after write down if there's bad debt), flash loan fees added after write down
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function _liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external returns(uint256 loanLiquidity, uint128[] memory refund);
}
