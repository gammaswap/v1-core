// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../rates/LinearKinkedRateModel.sol";

contract TestLinearKinkedRateModel is LinearKinkedRateModel {

    constructor(uint64 _baseRate, uint64 _optimalUtilRate, uint64 _slope1, uint64 _slope2)
        LinearKinkedRateModel(_baseRate, _optimalUtilRate, _slope1, _slope2){
    }

    function testCalcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) public virtual view returns(uint256) {
        return calcBorrowRate(lpInvariant, borrowedInvariant);
    }
}
