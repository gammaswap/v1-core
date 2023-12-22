// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract MinimalBeaconProxy {
    fallback() external payable virtual {
        assembly {
            let p := mload(0x40)
            // Call GammaPoolFactory -> getProtocol(uint16)
            mstore(p, 0xd2c7c2a400000000000000000000000000000000000000000000000000000000)
            mstore(add(p, 4), 0xffff)
            let result := staticcall(gas(), 0xBEbeBeBEbeBebeBeBEBEbebEBeBeBebeBeBebebe, p, 0x24, 0x80, 0x20)
            if iszero(result) {
                revert(0, returndatasize())
            }
            let impl := mload(0x80)
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())
            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())
            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}