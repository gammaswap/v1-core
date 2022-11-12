// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../libraries/AddressCalculator.sol";

contract TestAddressCalculator {

    function getGammaPoolKey(address cfmm, uint24 protocol) external pure returns(bytes32) {
        return AddressCalculator.getGammaPoolKey(cfmm, protocol);
    }

    function calcAddress(address factory, bytes32 key) external view returns(address pool){
        pool = AddressCalculator.calcAddress(factory, key);
    }

    function getPoolAddress(address factory, address tokenA, address tokenB, uint24 protocol) external pure returns(address pool){
    }
}
