// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library AddressCalculator {
    // update this value if GammaPool gets updated
    bytes32 internal constant GAMMA_POOL_INIT_CODE_HASH = 0x5b4e2ea5c335bf3eb17163d6c88bd2235be1e5d2e8323b1dbf2c022e2e12545c;

    function getGammaPoolKey(address cfmm, uint24 protocol) internal pure returns(bytes32) {
        return keccak256(abi.encode(cfmm, protocol));
    }

    function calcAddress(address factory, bytes32 key) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff",factory,key,GAMMA_POOL_INIT_CODE_HASH)))));
    }

    function calcAddress(address factory, bytes32 key, bytes32 initCodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff",factory,key,initCodeHash)))));
    }
}