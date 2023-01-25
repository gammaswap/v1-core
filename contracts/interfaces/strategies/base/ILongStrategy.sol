// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./IBaseLongStrategy.sol";

/// @title Interface for Long Strategy
/// @author Daniel D. Alcarraz
/// @dev Used in strategies that borrow and repay liquidity loans
interface ILongStrategy is IBaseLongStrategy {
    /// @dev Get latest reserves in the CFMM, which can be used for pricing
    /// @param cfmm - address of CFMM
    /// @return cfmmReserves - reserves in the CFMM
    function _getLatestCFMMReserves(address cfmm) external view returns(uint256[] memory cfmmReserves);

    /// @dev Deposit more collateral in loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _increaseCollateral(uint256 tokenId) external returns(uint128[] memory tokensHeld);

    /// @dev Withdraw collateral from loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param amounts - amounts of collateral tokens requested to withdraw
    /// @param to - destination address of receiver of collateral withdrawn
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint128[] memory tokensHeld);

    /// @dev Borrow liquidity from the CFMM and add it to the debt and collateral of loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param lpTokens - amount of CFMM LP tokens requested to short
    /// @return amounts - reserves quantities withdrawn from CFMM that correspond to the LP tokens shorted, now used as collateral
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint256[] memory amounts);

    /// @dev Repay liquidity debt of loan identified by tokenId, debt is repaid using available collateral in loan
    /// @param tokenId - unique id identifying loan
    /// @param liquidity - liquidity debt being repaid, capped at actual liquidity owed. Can't repay more than you owe
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return amounts - collateral amounts consumed in repaying liquidity debt
    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint256[] memory amounts);

    /// @dev Rebalance collateral amounts of loan identified by tokenId by purchasing or selling some of the collateral
    /// @param tokenId - unique id identifying loan
    /// @param deltas - collateral amounts being bought or sold (>0 buy, <0 sell), index matches tokensHeld[] index. Only n-1 tokens can be traded
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external returns(uint128[] memory tokensHeld);
}
