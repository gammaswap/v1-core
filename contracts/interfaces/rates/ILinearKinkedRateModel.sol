// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./IRateModel.sol";

/// @title Interface of Rate Model that calculates borrow rate according to a linear kinked rate model
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Interface for Linear Kinked rate model contract
/// @dev Inheritors of this interface has to also inherit AbstractRateModel
interface ILinearKinkedRateModel is IRateModel {
    /// @notice Base rate of Linear Kinked Rate model. This percentage is fixed and same amount is charged to every borrower
    /// @dev Base rate is expected to be of 18 decimals but of size uint64, therefore max value is approximately 1,844%
    /// @return baseRate - fixed rate that will be charged to liquidity borrowers
    function baseRate() external view returns(uint64);

    /// @notice Optimal Utilization rate of Linear Kinked Rate model. This percentage is the target utilization rate of the model
    /// @dev Optimal Utilization rate is expected to be of 18 decimals but of size uint64, although it must never be greater than 1e18
    /// @return optimalUtilRate - target utilization rate of model
    function optimalUtilRate() external view returns(uint64);

    /// @notice Slope1 of Linear Kinked Rate model. Rate of rate increase when utilization rate is below the target rate
    /// @dev Slope1 is expected to be lower than slope2
    /// @return slope1 - rate of increase of interest rate when utilization rate is below target rate
    function slope1() external view returns(uint64);

    /// @notice Slope2 of Linear Kinked Rate model. Rate of rate increase when utilization rate is above the target rate
    /// @dev Slope2 is expected to be greater than slope1
    /// @return slope2 - rate of increase of interest rate when utilization rate is above target rate
    function slope2() external view returns(uint64);

    /// @dev Get interest rate model parameters
    /// @param paramsStore - address storing rate params
    /// @param pool - address of contract to get parameters for
    /// @return baseRate - baseRate parameter of model
    /// @return optimalUtilRate - target utilization rate of model
    /// @return slope1 - factor parameter of model
    /// @return slope2 - maxApy parameter of model
    function getRateModelParams(address paramsStore, address pool) external view returns(uint64, uint64, uint64, uint64);
}
