// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/rates/ILogDerivativeRateModel.sol";
import "../libraries/Math.sol";
import "./AbstractRateModel.sol";

/// @title Logarithmic Derivative Rate Model used to calculate the yearly rate charged to liquidity borrowers according to the current utilization rate of the pool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Function that is defined here is the calcBorrowRate
/// @dev This contract is abstract and therefore supposed to be inherited by BaseStrategy
abstract contract LogDerivativeRateModel is AbstractRateModel, ILogDerivativeRateModel {

    /// @dev Error thrown when fixed borrow rate > ceiling borrow rate
    error BaseRateGtMaxAPY();

    /// @dev See {ILogDerivativeRateModel-baseRate}.
    uint64 immutable public override baseRate;

    /// @dev See {ILogDerivativeRateModel-factor}.
    uint80 immutable public override factor;

    /// @dev See {ILogDerivativeRateModel-maxApy}.
    uint80 immutable public override maxApy;

    /// @dev Initializes the contract by setting `baseRate`, `factor`, and `maxApy`. the fixed borrow rate (baseRate) cannot be greater than  the borrow rate ceiling (maxApy)
    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy) {
        if(_baseRate > _maxApy ) {
            revert BaseRateGtMaxAPY(); // revert if fixed borrow rate is greater than maximum allowed borrow rate
        }
        baseRate = _baseRate;
        factor = _factor;
        maxApy = _maxApy;
    }

    /// @notice formula is as follows: max{ baseRate + factor * (utilRate^2)/(1 - utilRate^2), maxApy }
    /// @dev See {AbstractRateModel-calcBorrowRate}.
    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual override view returns(uint256) {
        uint256 utilizationRate = calcUtilizationRate(lpInvariant, borrowedInvariant);
        if(utilizationRate == 0) { // if utilization rate is zero, the borrow rate is zero
            return 0;
        }
        uint256 utilizationRateSquare = utilizationRate**2; // since utilizationRate is a fraction, this lowers its value in a non linear way
        uint256 denominator = 1e36 - utilizationRateSquare + 1; // add 1 so that it never becomes 0
        return Math.min(baseRate + factor * utilizationRateSquare / denominator, maxApy); // division by an ever non linear decreasing denominator creates an exponential looking curve as util. rate increases
    }
}