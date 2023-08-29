// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../interfaces/rates/storage/IRateParamsStore.sol";
import "../rates/storage/AbstractRateParamsStore.sol";

contract TestRateParamsStore is AbstractRateParamsStore {

    address storeOwner;

    constructor(address _storeOwner) {
        storeOwner = _storeOwner;
    }

    function _rateParamsStoreOwner() internal override virtual view returns(address) {
        return storeOwner;
    }
}
