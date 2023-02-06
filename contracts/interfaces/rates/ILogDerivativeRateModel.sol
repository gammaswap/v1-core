// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

/// @title Interface of Rate Model that calculates borrow rate according to a first derivative of the logarithmic function
/// @author Daniel D. Alcarraz
/// @notice Interface for Logarithmic Derivative rate model contract
/// @dev Inheritors of this interface has to also inherit AbstractRateModel
interface ILogDerivativeRateModel {
    /// @notice Base rate of Logarithmic Derivative Rate model. This percentage is fixed and same amount is charged to every borrower
    /// @dev Base rate is expected to be of 18 decimals but of size uint64, therefore max value is approximately 1,844%
    /// @return baseRate - fixed rate that will be charged to liquidity borrowers
    function baseRate() external view returns(uint64);

    /// @notice Factor multiplier in Logarithmic Derivative Rate model. This is the weight assigned to the variable section of the rate model
    /// @dev Factor is expected to be of 18 decimals but of size uint80, therefore max value is approximately 1,208,925
    /// @return factor - fixed rate that will be charged to liquidity borrowers
    function factor() external view returns(uint80);

    /// @notice Maximum borrow rate of Logarithmic Derivative Rate model. The borrow rate calculated by the model will never exceed this number
    /// @dev The maximum borrow rate is expected to be of 18 decimals but of size uint80, therefore max possible borrow rate is approximately 120,892,500%
    /// @return maxApy - the maximum borrow rate charged to liquidity borrowers
    function maxApy() external view returns(uint80);
}
