// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

library AddressCalculator {
    // update this value if GammaPool gets updated
    bytes32 internal constant GAMMA_POOL_INIT_CODE_HASH = 0xc701aa6ce9b9b1cc9d7d57bdffeb9935e635e2e37da96f50f37302d1e92c13b6;

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