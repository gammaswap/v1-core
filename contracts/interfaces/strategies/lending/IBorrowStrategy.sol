// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../base/ILongStrategy.sol";

/// @title Interface for Borrow Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used in strategies that borrow liquidity
interface IBorrowStrategy is ILongStrategy {
    /// @dev Calculate and return dynamic origination fee in basis points
    /// @param baseOrigFee - base origination fee charge
    /// @param utilRate - current utilization rate of GammaPool
    /// @param lowUtilRate - low utilization rate threshold, used as a lower bound for the utilization rate
    /// @param minUtilRate1 - minimum utilization rate after which origination fee will start increasing exponentially
    /// @param minUtilRate2 - minimum utilization rate after which origination fee will start increasing linearly
    /// @param feeDivisor - fee divisor of formula for dynamic origination fee
    /// @return origFee - origination fee that will be applied to loan
    function calcDynamicOriginationFee(uint256 baseOrigFee, uint256 utilRate, uint256 lowUtilRate, uint256 minUtilRate1, uint256 minUtilRate2, uint256 feeDivisor) external view returns(uint256 origFee);

    /// @dev Deposit more collateral in loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param ratio - ratio to rebalance collateral after increasing collateral
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _increaseCollateral(uint256 tokenId, uint256[] calldata ratio) external returns(uint128[] memory tokensHeld);

    /// @dev Withdraw collateral from loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param amounts - amounts of collateral tokens requested to withdraw
    /// @param to - destination address of receiver of collateral withdrawn
    /// @param ratio - ratio to rebalance collateral after withdrawing collateral
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _decreaseCollateral(uint256 tokenId, uint128[] memory amounts, address to, uint256[] calldata ratio) external returns(uint128[] memory tokensHeld);

    /// @dev Borrow liquidity from the CFMM and add it to the debt and collateral of loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param lpTokens - amount of CFMM LP tokens requested to short
    /// @param ratio - weights of collateral after borrowing liquidity
    /// @return liquidityBorrowed - liquidity amount that has been borrowed
    /// @return amounts - reserves quantities withdrawn from CFMM that correspond to the LP tokens shorted, now used as collateral
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external returns(uint256 liquidityBorrowed, uint256[] memory amounts, uint128[] memory tokensHeld);
}
