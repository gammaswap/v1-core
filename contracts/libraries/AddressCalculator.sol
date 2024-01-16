// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../interfaces/IGammaPoolFactory.sol";

/// @title Library used calculate the deterministic addresses used to instantiate GammaPools
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev These algorithms are based on EIP-1014 (https://eips.ethereum.org/EIPS/eip-1014)
library AddressCalculator {

    /// @dev calculate salt used to create deterministic address, the salt is also used as unique key identifier for the GammaPool
    /// @param cfmm - address of CFMM the GammaPool is for
    /// @param protocolId - protocol id of instance address the GammaPool will use (version of GammaPool for this CFMM)
    /// @return key - key/salt used as unique identifier of GammaPool
    function getGammaPoolKey(address cfmm, uint16 protocolId) internal pure returns(bytes32) {
        return keccak256(abi.encode(cfmm, protocolId)); // key is hash of CFMM address and protocolId
    }

    /// @dev calculate deterministic address to instantiate GammaPool minimal beacon proxy or minimal proxy contract
    /// @param factory - address of factory that will instantiate GammaPool proxy contract
    /// @param protocolId - protocol id of instance address the GammaPool will use (version of this GammaPool)
    /// @param key - salt used in address generation to assure its uniqueness
    /// @return _address - address of GammaPool that maps to protocolId and key
    function calcAddress(address factory, uint16 protocolId, bytes32 key) internal view returns (address) {
        if (protocolId < 10000) {
            return predictDeterministicAddress(IGammaPoolFactory(factory).getProtocolBeacon(protocolId), protocolId, key, factory);
        } else {
            return predictDeterministicAddress2(IGammaPoolFactory(factory).getProtocol(protocolId), key, factory);
        }
    }

    /// @dev calculate a deterministic address based on init code hash
    /// @param factory - address of factory that instantiated or will instantiate this contract
    /// @param salt - salt used in address generation to assure its uniqueness
    /// @param initCodeHash - init code hash of template contract which will be used to instantiate contract with deterministic address
    /// @return _address - address of contract that maps to salt and init code hash that is created by factory contract
    function calcAddress(address factory, bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff",factory,salt,initCodeHash)))));
    }

    /// @dev Compute bytecode of a minimal beacon proxy contract, excluding bytecode metadata hash
    /// @param beacon - address of beacon of minimal beacon proxy
    /// @param protocolId - id of protocol
    /// @param factory - address of factory that instantiated or will instantiate this contract
    /// @return bytecode - the calculated bytecode for minimal beacon proxy contract
    function calcMinimalBeaconProxyBytecode(
        address beacon,
        uint16 protocolId,
        address factory
    ) internal pure returns(bytes memory) {
        return abi.encodePacked(
            hex"608060405234801561001057600080fd5b5073",
            beacon,
            hex"7f",
            hex"a3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
            hex"5560",
            protocolId < 256 ? hex"6c" : hex"6d",
            hex"806100566000396000f3fe",
            hex"608060408190526334b1f0a960e21b8152",
            protocolId < 256 ? hex"60" : hex"61",
            protocolId < 256 ? abi.encodePacked(uint8(protocolId)) : abi.encodePacked(protocolId),
            hex"60845260208160248173",
            factory,
            hex"5afa60",
            protocolId < 256 ? hex"3a" : hex"3b",
            hex"573d6000fd5b5060805160003681823780813683855af491503d81823e81801560",
            protocolId < 256 ? hex"5b" : hex"5c",
            hex"573d82f35b3d82fdfea164736f6c6343000815000a"
        );
    }

    /// @dev Computes the address of a minimal beacon proxy contract
    /// @param protocolId - id of protocol
    /// @param salt - salt used in address generation to assure its uniqueness
    /// @param factory - address of factory that instantiated or will instantiate this contract
    /// @return predicted - the calculated address
    function predictDeterministicAddress(
        address beacon,
        uint16 protocolId,
        bytes32 salt,
        address factory
    ) internal pure returns (address) {
        bytes memory bytecode = calcMinimalBeaconProxyBytecode(beacon, protocolId, factory);

        // Compute the hash of the initialization code.
        bytes32 bytecodeHash = keccak256(bytecode);

        // Compute the final CREATE2 address
        bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), factory, salt, bytecodeHash));
        return address(uint160(uint256(data)));
    }

    /// @dev Computes the address of a minimal proxy contract
    /// @param implementation - address of implementation contract of this minimal proxy contract
    /// @param salt - salt used in address generation to assure its uniqueness
    /// @param factory - address of factory that instantiated or will instantiate this contract
    /// @return predicted - the calculated address
    function predictDeterministicAddress2(
        address implementation,
        bytes32 salt,
        address factory
    ) internal pure returns (address predicted) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), factory)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := keccak256(add(ptr, 0x43), 0x55)
        }
    }
}