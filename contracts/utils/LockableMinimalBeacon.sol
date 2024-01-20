// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./MinimalBeacon.sol";

/// @title Lockable Minimal Beacon Contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Locks last protocol implementation from GammaPoolFactory for this protocolId
contract LockableMinimalBeacon is MinimalBeacon {
    address public protocol;

    constructor(address _factory, uint16 _protocolId) MinimalBeacon(_factory, _protocolId) {
    }

    function lock() external {
        require(msg.sender == factory, "FORBIDDEN");
        require(protocol == address(0), "LOCKED");

        protocol = _implementation();

        require(protocol != address(0), "ZERO_ADDRESS");
    }

    function implementation() external view override returns (address) {
        if(protocol == address(0)) {
            return _implementation();
        } else {
            return protocol;
        }
    }
}
