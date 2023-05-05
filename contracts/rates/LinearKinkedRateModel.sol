// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/rates/ILinearKinkedRateModel.sol";
import "./AbstractRateModel.sol";

/// @title Linear Kinked Rate Model used to calculate the yearly rate charged to liquidity borrowers according to the current utilization rate of the pool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Function that is defined here is the calcBorrowRate
/// @dev This contract is abstract and therefore supposed to be inherited by BaseStrategy. Modeled after AAVE's rate model
abstract contract LinearKinkedRateModel is AbstractRateModel, ILinearKinkedRateModel {

    /// @dev Error thrown when optimal util rate initialized to greater than 1e18
    error OptimalUtilRate();

    /// @dev See {ILinearKinkedRateModel-baseRate}.
    uint64 immutable public override baseRate;

    /// @dev See {ILinearKinkedRateModel-optimalUtilRate}.
    uint64 immutable public override optimalUtilRate;

    /// @dev See {ILinearKinkedRateModel-slope1}.
    uint64 immutable public override slope1;

    /// @dev See {ILinearKinkedRateModel-slope2}.
    uint64 immutable public override slope2;

    /// @dev Initializes the contract by setting `_baseRate`, `_optimalUtilRate`, `_slope1`, and `_slope2`. the target rate (`_optimalUtilRate`) cannot be greater than 1e18
    constructor(uint64 _baseRate, uint64 _optimalUtilRate, uint64 _slope1, uint64 _slope2) {
        if(!(_optimalUtilRate > 0 && _optimalUtilRate < 1e18)){
            revert OptimalUtilRate();
        }
        baseRate = _baseRate;
        optimalUtilRate = _optimalUtilRate;
        slope1 = _slope1;
        slope2 = _slope2;
    }

    /// @notice formula is as follows: max{ baseRate + (utilRate * slope1) / optimalRate, baseRate + slope1 + slope2 * (utilRate - optimalRate) / (1 - optimalUtilRate) }
    /// @dev See {AbstractRateModel-calcBorrowRate}.
    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual override view returns(uint256 borrowRate, uint256 utilizationRate) {
        utilizationRate = calcUtilizationRate(lpInvariant, borrowedInvariant);
        if(utilizationRate == 0) { // if utilization rate is zero, the borrow rate is zero
            return (0, 0);
        }
        if(utilizationRate <= optimalUtilRate) { // if pool funds are underutilized use slope1
            uint256 variableRate = (utilizationRate * slope1) / optimalUtilRate;
            borrowRate = baseRate + variableRate;
        } else { // if pool funds are overutilized use slope2
            uint256 utilizationRateDiff = utilizationRate - optimalUtilRate;
            uint256 variableRate = (utilizationRateDiff * slope2) / (1e18 - optimalUtilRate);
            borrowRate = baseRate + slope1 + variableRate;
        }
    }

    /// @dev See {IRateModel-validateParameters}.
    function validateParameters(bytes calldata _data) external override view returns(bool) {
        return true;
    }
}
