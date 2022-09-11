// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library TestRateStorage {
    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.rates.test");

    struct Store {
        uint8 val;
    }

    function store() internal pure returns (Store storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function init(uint8 _val) internal {
        Store storage _store = store();
        _store.val = _val;
    }
}
