// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../rates/LogDerivativeRateModel.sol";
import "../../rates/storage/AbstractRateParamsStore.sol";

contract TestLogDerivativeRateModel is LogDerivativeRateModel, AbstractRateParamsStore {

    address public owner;

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        LogDerivativeRateModel(_baseRate, _factor, _maxApy){
        owner = msg.sender;
    }

    function testCalcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) public virtual view returns(uint256 borrowRate) {
        (borrowRate,) = calcBorrowRate(lpInvariant, borrowedInvariant);
    }

    function _rateParamsStoreOwner() internal virtual override view returns(address) {
        return owner;
    }

    function rateParamsStore() public override(AbstractRateModel, IRateModel) virtual view returns(address) {
        return address(this);
    }
}
