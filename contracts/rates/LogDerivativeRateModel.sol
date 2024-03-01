// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/rates/storage/IRateParamsStore.sol";
import "../interfaces/rates/ILogDerivativeRateModel.sol";
import "../libraries/GSMath.sol";
import "./AbstractRateModel.sol";

/// @title Logarithmic Derivative Rate Model used to calculate the yearly rate charged to liquidity borrowers according to the current utilization rate of the pool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Function that is defined here is the calcBorrowRate
/// @dev This contract is abstract and therefore supposed to be inherited by BaseStrategy
abstract contract LogDerivativeRateModel is AbstractRateModel, ILogDerivativeRateModel {

    /// @dev Error thrown when fixed borrow rate > ceiling borrow rate
    error BaseRateGtMaxAPY();
    /// @dev Error thrown when fixed borrow rate >= 100% or is zero
    error BaseRate();
    /// @dev Error thrown when Factor >= 10 or is zero
    error Factor();

    /// @dev struct containing model rate parameters, used in validation
    struct ModelRateParams {
        /// @dev baseRate - minimum rate charged to all loans
        uint64 baseRate;
        /// @dev factor - number that determines convexity of interest rate model
        uint80 factor;
        /// @dev maxApy - maximum interest rate charged
        uint80 maxApy;
    }

    /// @dev See {ILogDerivativeRateModel-baseRate}.
    uint64 immutable public override baseRate;

    /// @dev See {ILogDerivativeRateModel-factor}.
    uint80 immutable public override factor;

    /// @dev See {ILogDerivativeRateModel-maxApy}.
    uint80 immutable public override maxApy;

    /// @dev Initializes the contract by setting `baseRate`, `factor`, and `maxApy`. the fixed borrow rate (baseRate) cannot be greater than  the borrow rate ceiling (maxApy)
    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy) {
        _validateParameters(_baseRate, _factor, _maxApy);
        baseRate = _baseRate;
        factor = _factor;
        maxApy = _maxApy;
    }

    /// @notice formula is as follows: max{ baseRate + factor * (utilRate^2)/(1 - utilRate^2), maxApy }
    /// @dev See {AbstractRateModel-calcBorrowRate}.
    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant, address paramsStore, address pool) public virtual override view returns(uint256 borrowRate, uint256 utilizationRate, uint256 maxLeverage, uint256 spread) {
        utilizationRate = calcUtilizationRate(lpInvariant, borrowedInvariant);
        maxLeverage = _calcMaxLeverage();
        if(utilizationRate == 0) { // if utilization rate is zero, the borrow rate is zero
            return (0, 0, maxLeverage, 1e18);
        }
        uint256 utilizationRateSquare = GSMath.min(utilizationRate**2, 1e36); // since utilizationRate is a fraction, this lowers its value in a non linear way
        uint256 denominator = 1 + 1e36 - utilizationRateSquare; // add 1 so that it never becomes 0
        (uint64 _baseRate, uint80 _factor, uint80 _maxApy) = getRateModelParams(paramsStore, pool);
        borrowRate = GSMath.min(_baseRate + _factor * utilizationRateSquare / denominator, _maxApy); // division by an ever non linear decreasing denominator creates an exponential looking curve as util. rate increases
        spread = _calcSpread();
    }

    /// @dev max leverage hardcoded at 5 with 3 decimal precision
    function _calcMaxLeverage() internal virtual view returns(uint256) {
        return 5000;
    }

    /// @dev spread is always 0%
    function _calcSpread() internal virtual view returns(uint256) {
        return 1e18;
    }

    /// @dev Get parameters for itnerest rate model
    /// @param paramsStore - address of contract storing overriding rate parameters
    /// @param pool - address to get rate parameters for
    /// @return baseRate - minimum rate charged to all loans
    /// @return factor - number that determines convexity of interest rate model
    /// @return maxApy - maximum interest rate charged
    function getRateModelParams(address paramsStore, address pool) public override virtual view returns(uint64, uint80, uint80) {
        IRateParamsStore.RateParams memory rateParams = IRateParamsStore(paramsStore).getRateParams(pool);
        if(!rateParams.active) {
            return (baseRate, factor, maxApy);
        }
        ModelRateParams memory params = abi.decode(rateParams.data, (ModelRateParams));
        return (params.baseRate, params.factor, params.maxApy);
    }

    /// @dev See {IRateModel-validateParameters}.
    function validateParameters(bytes calldata _data) external override virtual view returns(bool) {
        ModelRateParams memory params = abi.decode(_data, (ModelRateParams));
        _validateParameters(params.baseRate, params.factor, params.maxApy);
        return true;
    }

    /// @dev Validate interest rate model parameters
    /// @param _baseRate - minimum rate charged to all loans
    /// @param _factor - number that determines convexity of interest rate model
    /// @param _maxApy - maximum interest rate charged
    /// @return bool - return true if model passed validation or error if it failed
    function _validateParameters(uint64 _baseRate, uint80 _factor, uint80 _maxApy) internal virtual view returns(bool) {
        if(_baseRate > _maxApy ) revert BaseRateGtMaxAPY(); // revert if fixed borrow rate is greater than maximum allowed borrow rate
        if(_baseRate > 1e18 || _baseRate == 0) revert BaseRate(); // revert if base rate is greater than 100% or is zero
        if(_factor > 1e19 || _factor == 0) revert Factor(); // revert if factor is greater than 10 or is zero
        return true;
    }
}