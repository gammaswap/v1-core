// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library ProtocolStorage {
    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.protocol");

    struct Store {
        uint24 protocol;
        address owner;
        address longStrategy;
        address shortStrategy;
        bool isSet;
    }

    function store() internal pure returns (Store storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function init(uint24 protocol, address longStrategy, address shortStrategy, address owner) internal {
        Store storage _store = store();
        require(_store.isSet == false, "SET");
        _store.isSet = true;
        _store.protocol = protocol;
        _store.longStrategy = longStrategy;
        _store.shortStrategy = shortStrategy;
        _store.owner = owner;
    }
}