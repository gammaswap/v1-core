// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../interfaces/rates/storage/IRateParamsStore.sol";
import "../observer/AbstractLoanObserverStore.sol";

contract TestLoanObserverStore is AbstractLoanObserverStore {

    address storeOwner;

    constructor(address _storeOwner) {
        storeOwner = _storeOwner;
    }

    function _loanObserverStoreOwner() internal override virtual view returns(address) {
        return storeOwner;
    }
}
