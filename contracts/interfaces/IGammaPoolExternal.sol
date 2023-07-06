// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./IGammaPool.sol";

/// @title Interface for GammaPoolExternal
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used for GammaPool implementations that have flash loan functionality
interface IGammaPoolExternal {

    /// @dev External Rebalance Strategy implementation contract for this GammaPool
    function externalRebalanceStrategy() external view returns(address);

    /// @dev External Liquidation Strategy implementation contract for this GammaPool
    function externalLiquidationStrategy() external view returns(address);

    /// @dev Flash loan pool's collateral and/or lp tokens to external address. Rebalanced loan collateral is acceptable in  repayment of flash loan
    /// @param tokenId - unique id identifying loan
    /// @param amounts - collateral amounts being flash loaned
    /// @param lpTokens - amount of CFMM LP tokens being flash loaned
    /// @param to - address that will receive flash loan swaps and potentially rebalance loan's collateral
    /// @param data - optional bytes parameter for custom user defined data
    /// @return loanLiquidity - updated loan liquidity, includes flash loan fees
    /// @return tokensHeld - updated collateral token amounts backing loan
    function rebalanceExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external returns(uint256 loanLiquidity, uint128[] memory tokensHeld);

    /// @notice The entire pool's collateral is available in the flash loan. Flash loan must result in a net CFMM LP token deposit that repays loan's liquidity debt
    /// @dev Function to liquidate a loan using using a flash loan of collateral tokens from the pool and/or CFMM LP tokens. Seeks full liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @param amounts - amount collateral tokens from the pool to flash loan
    /// @param lpTokens - amount of CFMM LP tokens being flash loaned
    /// @param to - address that will receive the collateral tokens and/or lpTokens in flash loan
    /// @param data - optional bytes parameter for custom user defined data
    /// @return loanLiquidity - loan liquidity liquidated (after write down if there's bad debt), flash loan fees added after write down
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external returns(uint256 loanLiquidity, uint256[] memory refund);

}
