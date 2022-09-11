// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../libraries/AddressCalculator.sol";

contract TestAddressCalculator {
    function getInitCodeHash() external pure returns(bytes32 hash) {
        hash = AddressCalculator.GAMMA_POOL_INIT_CODE_HASH;
    }

    function getGammaPoolKey(address cfmm, uint24 protocol) external pure returns(bytes32) {
        return AddressCalculator.getGammaPoolKey(cfmm, protocol);
    }

    function calcAddress(address factory, bytes32 key) external pure returns(address pool){
        pool = AddressCalculator.calcAddress(factory, key);
    }

    function getPoolAddress(address factory, address tokenA, address tokenB, uint24 protocol) external pure returns(address pool){
    }
}
