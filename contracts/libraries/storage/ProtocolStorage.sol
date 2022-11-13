// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

library ProtocolStorage {
    error StoreInitialized();

    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.protocol");

    struct Store {
        uint24 protocolId;
        address longStrategy;
        address shortStrategy;
    }

    function store() internal pure returns (Store storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function init(uint24 protocolId, address longStrategy, address shortStrategy) internal {
        Store storage _store = store();
        if(_store.protocolId > 0) {
            revert StoreInitialized();
        }
        _store.protocolId = protocolId;
        _store.longStrategy = longStrategy;
        _store.shortStrategy = shortStrategy;
    }
}