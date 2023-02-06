// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

/// @title Abstract contract to calculate the utilization rate of the GammaPool.
/// @author Daniel D. Alcarraz
/// @notice All rate models inherit this contract since all rate models depend on utilization rate
/// @dev All strategies inherit a rate model in its base and therefore all strategies inherit this contract.
abstract contract AbstractRateModel {
    /// @notice Calculates the utilization rate of the pool. How much borrowed out of how much liquidity is in the AMM through GammaSwap
    /// @dev The utilization rate always has 18 decimal places, even if the reserve tokens do not. Everything is adjusted to 18 decimal points
    /// @param lpInvariant - invariant amount available to be borrowed from LP tokens deposited in GammaSwap
    /// @param borrowedInvariant - invariant amount borrowed from GammaSwap
    /// @return utilizationRate - borrowedInvariant / (lpInvariant + borrowedInvairant)
    function calcUtilizationRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual view returns(uint256) {
        uint256 totalInvariant = lpInvariant + borrowedInvariant; // total invariant belonging to liquidity depositors in GammaSwap
        if(totalInvariant == 0) // avoid division by zero
            return 0;

        return borrowedInvariant * 1e18 / totalInvariant; // utilization rate will always have 18 decimals
    }

    /// @notice Calculates the borrow rate according to an implementation formula
    /// @dev The borrow rate is expected to always have 18 decimal places
    /// @param lpInvariant - invariant amount available to be borrowed from LP tokens deposited in GammaSwap
    /// @param borrowedInvariant - invariant amount borrowed from GammaSwap
    /// @return borrowRate - rate that will be charged to liquidity borrowers
    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual view returns(uint256);
}
