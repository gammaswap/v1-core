// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../rates/LogDerivativeRateModel.sol";
import "../../rates/storage/AbstractRateParamsStore.sol";

contract TestLogDerivativeRateModel is LogDerivativeRateModel, AbstractRateParamsStore {

    address public owner;
    address private paramsStore;

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        LogDerivativeRateModel(_baseRate, _factor, _maxApy){
        owner = msg.sender;
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
