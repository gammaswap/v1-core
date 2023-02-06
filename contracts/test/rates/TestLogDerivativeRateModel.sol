// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../rates/LogDerivativeRateModel.sol";

contract TestLogDerivativeRateModel is LogDerivativeRateModel {

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        LogDerivativeRateModel(_baseRate, _factor, _maxApy){
    }

    function testCalcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) public virtual view returns(uint256) {
        return calcBorrowRate(lpInvariant, borrowedInvariant);
    }

}
