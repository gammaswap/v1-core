// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../libraries/AddressCalculator.sol";

contract TestAddressCalculator {

    function getGammaPoolKey(address cfmm, uint16 protocolId) external pure returns(bytes32) {
        return AddressCalculator.getGammaPoolKey(cfmm, protocolId);
    }

    function calcAddress(address factory, uint16 protocolId, bytes32 key) external view returns(address pool){
        pool = AddressCalculator.calcAddress(factory, protocolId, key);
    }

    function getPoolAddress(address factory, address tokenA, address tokenB, uint24 protocol) external pure returns(address pool){
    }
}
