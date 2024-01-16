// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract MinimalBeacon {
    address immutable public factory;
    uint16 immutable public protocolId;

    constructor(address _factory, uint16 _protocolId) {
        factory = _factory;
        protocolId = _protocolId;
    }

    function implementation() external view returns (address impl) {
        address _factory = factory;
        uint16 _protocolId = protocolId;
        assembly {
            let p := mload(0x40)
            // Call GammaPoolFactory -> getProtocol(uint16)
            mstore(p, 0xd2c7c2a400000000000000000000000000000000000000000000000000000000)
            mstore(add(p, 4), _protocolId)
            let result := staticcall(gas(), _factory, p, 0x24, 0x80, 0x20)
            if iszero(result) {
                revert(0, returndatasize())
            }
            impl := mload(0x80)
        }
    }
}
