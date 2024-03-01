// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../rates/LinearKinkedRateModel.sol";
import "../../rates/storage/AbstractRateParamsStore.sol";

contract TestLinearKinkedRateModel is LinearKinkedRateModel, AbstractRateParamsStore {

    address public owner;
    address private paramsStore;

    constructor(uint64 _baseRate, uint64 _optimalUtilRate, uint64 _slope1, uint64 _slope2)
        LinearKinkedRateModel(_baseRate, _optimalUtilRate, _slope1, _slope2){
    }

    function testCalcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) public virtual view returns(uint256 borrowRate) {
        (borrowRate,,,) = calcBorrowRate(lpInvariant, borrowedInvariant, paramsStore, address(this));
    }

    function _rateParamsStoreOwner() internal virtual override view returns(address) {
        return owner;
    }

    function setRateParamsStore(address _paramsStore) public virtual {
        paramsStore = _paramsStore;
    }

    function _rateParamsStore() internal override virtual view returns(address) {
        return paramsStore;
    }
}
