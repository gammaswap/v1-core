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

    /// @dev calculate deterministic address to instantiate GammaPool minimal beacon proxy contract
    /// @param factory - address of factory that will instantiate GammaPool proxy contract
    /// @param protocolId - protocol id of instance address the GammaPool will use (version of this GammaPool)
    /// @param key - salt used in address generation to assure its uniqueness
    /// @return _address - address of GammaPool that maps to protocolId and key
    function calcAddress(address factory, uint16 protocolId, bytes32 key) internal view returns (address) {
        return predictDeterministicAddress(IGammaPoolFactory(factory).getProtocol(protocolId), key, factory);
    }

    /// @dev calculate deterministic address to instantiate GammaPool minimal proxy contract
    /// @param factory - address of factory that will instantiate GammaPool proxy contract
    /// @param protocolId - protocol id of instance address the GammaPool will use (version of this GammaPool)
    /// @param key - salt used in address generation to assure its uniqueness
    /// @return _address - address of GammaPool that maps to protocolId and key
    function calcAddress2(address factory, uint16 protocolId, bytes32 key) internal view returns (address) {
        return predictDeterministicAddress2(IGammaPoolFactory(factory).getProtocol(protocolId), key, factory);
    }

    /// @dev calculate a deterministic address based on init code hash
    /// @param factory - address of factory that instantiated or will instantiate this contract
    /// @param salt - salt used in address generation to assure its uniqueness
    /// @param initCodeHash - init code hash of template contract which will be used to instantiate contract with deterministic address
    /// @return _address - address of contract that maps to salt and init code hash that is created by factory contract
    function calcAddress(address factory, bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff",factory,salt,initCodeHash)))));
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

    // only used for proof of concept minimal proxy
    function predictDeterministicAddress3(
        address implementation,
        bytes32 salt,
        address factory
    ) public pure returns (address) {
        // Compute the hash of the initialization code.
        bytes memory bytecode = abi.encodePacked(
            hex"6080604052348015600f57600080fd5b50606d80601d6000396000f3fe608060",
            hex"40526000368182378081368373",
            implementation,
            hex"5af43d82833e8080156033573d83f35b3d83fdfea2646970667358221220464f",
            hex"28377c2fca72af73b668c7b0478422b822de2bef99b3e38362698c1544326473",
            hex"6f6c63430008150033"
        );
        bytes32 bytecodeHash = keccak256(bytecode);

        // Compute the final CREATE2 address
        bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), factory, salt, bytecodeHash));
        return address(uint160(uint256(data)));
    }

    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address factory
    ) public pure returns (address) {
        // Compute the hash of the initialization code.
        bytes memory bytecode = abi.encodePacked(
            hex"608060405234801561001057600080fd5b5060f68061001f6000396000f3fe60",
            hex"806040819052635c60da1b60e01b815260009073",
            implementation,
            hex"90635c60da1b90608490602090600481865afa158015604b573d6000803e3d60",
            hex"00fd5b505050506040513d601f19601f82011682018060405250810190606d91",
            hex"906092565b90503660008037600080366000845af43d6000803e808015608d57",
            hex"3d6000f35b3d6000fd5b60006020828403121560a357600080fd5b8151600160",
            hex"0160a01b038116811460b957600080fd5b939250505056fea264697066735822",
            hex"1220e00b97edf2feacc64cc08f7e5b1dc6fce1cb12cd365908bdd712927eb036",
            hex"ddb264736f6c63430008150033"
        );
        bytes32 bytecodeHash = keccak256(bytecode);

        // Compute the final CREATE2 address
        bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), factory, salt, bytecodeHash));
        return address(uint160(uint256(data)));
    }
}