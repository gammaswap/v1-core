// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library TestRateStorage {
    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.rates.test");

    struct Store {
        uint256 val;
        bool isSet;//flag to check that variables have been initialized through external function
    }

    function store() internal pure returns (Store storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function init(uint256 _val) internal {
        Store storage _store = store();
        require(_store.isSet == false, "SET");
        _store.isSet = true;
        _store.val = _val;
    }
}
