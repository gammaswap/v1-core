// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../interfaces/IGammaPoolFactory.sol";

abstract contract AbstractGammaPoolFactory is IGammaPoolFactory {

    error Forbidden();
    error ZeroProtocol();
    error ProtocolNotSet();
    error ProtocolExists();
    error ProtocolRestricted();
    error PoolExists();
    error DeployFailed();

    mapping(bytes32 => address) public override getPool;//all GS Pools addresses can be predetermined

    address public override feeToSetter;
    address public override owner;
    address public override feeTo;
    uint256 public override fee = 5 * (10**16); //5% of borrowed interest gains by default

    function isForbidden(address _owner) internal virtual view {
        if(msg.sender != _owner) {
            revert Forbidden();
        }
    }

    function hasPool(bytes32 key) internal virtual view {
        if(getPool[key] != address(0)) {
            revert PoolExists();
        }
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
        // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
        // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
        // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(0, 0x09, 0x37, salt)
        }
        //require(instance != address(0), "ERC1167: create2 failed");
        if(instance == address(0)) {
            revert DeployFailed();
        }
    }
}
