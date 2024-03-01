// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/rates/storage/IRateParamsStore.sol";
import "../interfaces/rates/ILinearKinkedRateModel.sol";
import "../libraries/GSMath.sol";
import "./AbstractRateModel.sol";

/// @title Linear Kinked Rate Model used to calculate the yearly rate charged to liquidity borrowers according to the current utilization rate of the pool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Function that is defined here is the calcBorrowRate
/// @dev This contract is abstract and therefore supposed to be inherited by BaseStrategy. Modeled after AAVE's rate model
abstract contract LinearKinkedRateModel is AbstractRateModel, ILinearKinkedRateModel {

    /// @dev Error thrown when optimal util rate set to 0 or greater or equal to 1e18
    error OptimalUtilRate();
    /// @dev Error thrown when slope2 < slope1
    error Slope2LtSlope1();

    /// @dev struct containing model rate parameters, used in validation
    struct ModelRateParams {
        /// @dev baseRate - minimum rate charged to all loans
        uint64 baseRate;
        /// @dev optimalUtilRate - target utilization rate of model
        uint64 optimalUtilRate;
        /// @dev slope1 - factor parameter of model
        uint64 slope1;
        /// @dev slope2 - maxApy parameter of model
        uint64 slope2;
    }

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
        if(!(_optimalUtilRate > 0 && _optimalUtilRate < 1e18)) revert OptimalUtilRate();
        if(_slope2 < _slope1) revert Slope2LtSlope1();

        baseRate = _baseRate;
        optimalUtilRate = _optimalUtilRate;
        slope1 = _slope1;
        slope2 = _slope2;
    }

    /// @notice formula is as follows: max{ baseRate + (utilRate * slope1) / optimalRate, baseRate + slope1 + slope2 * (utilRate - optimalRate) / (1 - optimalUtilRate) }
    /// @dev See {AbstractRateModel-calcBorrowRate}.
    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant, address paramsStore, address pool) public virtual override view returns(uint256 borrowRate, uint256 utilizationRate, uint256 maxLeverage, uint256 spread) {
        utilizationRate = calcUtilizationRate(lpInvariant, borrowedInvariant); // at most 1e18 < max(uint64)
        (uint64 _baseRate, uint64 _optimalUtilRate, uint64 _slope1, uint64 _slope2) = getRateModelParams(paramsStore, pool);
        maxLeverage = _calcMaxLeverage(_optimalUtilRate);
        if(utilizationRate == 0) { // if utilization rate is zero, the borrow rate is zero
            return (0, 0, maxLeverage, 1e18);
        }
        unchecked {
            if(utilizationRate <= _optimalUtilRate) { // if pool funds are underutilized use slope1
                uint256 variableRate = (utilizationRate * _slope1) / _optimalUtilRate; // at most uint128
                borrowRate = _baseRate + variableRate;
            } else { // if pool funds are overutilized use slope2
                uint256 utilizationRateDiff = utilizationRate - _optimalUtilRate; // at most 1e18 - 1 < max(uint64)
                uint256 variableRate = (utilizationRateDiff * _slope2) / (1e18 - _optimalUtilRate); // at most uint128
                borrowRate = _baseRate + _slope1 + variableRate;
            }
            spread = _calcSpread(borrowRate);
        }
    }

    /// @dev return max leverage based on optimal utilization rate times 1000 (e.g. 1000 / (1 - optimalRate)
    function _calcMaxLeverage(uint256 _optimalUtilRate) internal virtual view returns(uint256) {
        return GSMath.min(1e21 / (1e18 - _optimalUtilRate), 100000); // capped at 100
    }

    /// @dev return spread to add to the CFMMFeeIndex as the borrow rate * 10
    function _calcSpread(uint256 borrowRate) internal virtual view returns(uint256) {
        return 1e18 + borrowRate * 10;
    }

    /// @dev Get interest rate model parameters
    /// @param paramsStore - address storing rate params
    /// @param pool - address of contract to get parameters for
    /// @return baseRate - baseRate parameter of model
    /// @return optimalUtilRate - target utilization rate of model
    /// @return slope1 - factor parameter of model
    /// @return slope2 - maxApy parameter of model
    function getRateModelParams(address paramsStore, address pool) public override virtual view returns(uint64, uint64, uint64, uint64) {
        IRateParamsStore.RateParams memory rateParams = IRateParamsStore(paramsStore).getRateParams(pool);
        if(!rateParams.active) {
            return (baseRate, optimalUtilRate, slope1, slope2);
        }
        ModelRateParams memory params = abi.decode(rateParams.data, (ModelRateParams));
        return (params.baseRate, params.optimalUtilRate, params.slope1, params.slope2);
    }

    /// @dev See {IRateModel-validateParameters}.
    function validateParameters(bytes calldata _data) external override virtual view returns(bool) {
        ModelRateParams memory params = abi.decode(_data, (ModelRateParams));
        _validateParameters(params.baseRate, params.optimalUtilRate, params.slope1, params.slope2);
        return true;
    }

    /// @dev Validate interest rate model parameters
    /// @param _baseRate - baseRate parameter of model
    /// @param _optimalUtilRate - target utilization rate of model
    /// @param _slope1 - factor parameter of model
    /// @param _slope2 - maxApy parameter of model
    /// @return bool - return true if model passed validation or error if it failed
    function _validateParameters(uint64 _baseRate, uint64 _optimalUtilRate, uint64 _slope1, uint64 _slope2) internal virtual view returns(bool) {
        if(!(_optimalUtilRate > 0 && _optimalUtilRate < 1e18)) revert OptimalUtilRate();
        if(_slope2 < _slope1) revert Slope2LtSlope1();
        return true;
    }
}
