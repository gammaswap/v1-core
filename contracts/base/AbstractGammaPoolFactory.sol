// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/IGammaPoolFactory.sol";

/// @title Abstract factory contract to create more GammaPool contracts.
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev If another GammaPoolFactory contract is created it is recommended to inherit from this contract
abstract contract AbstractGammaPoolFactory is IGammaPoolFactory {

    error Forbidden();
    error NotNewOwner();
    error ZeroProtocol();
    error ProtocolNotSet();
    error ProtocolExists();
    error ProtocolRestricted();
    error PoolExists();
    error DeployFailed();
    error ZeroAddress();

    /// @dev Event emitted when ownership of GammaPoolFactory contract is transferred to a new address
    /// @param previousOwner - previous address that owned factory contract
    /// @param newOwner - new address that owns factory contract
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev Event emitted when change of ownership of GammaPoolFactory contract is started
    /// @param currentOwner - current address that owns factory contract
    /// @param newOwner - new address that will own factory contract
    event OwnershipTransferStarted(address indexed currentOwner, address indexed newOwner);

    /// @dev See {IGammaPoolFactory-getPool}
    mapping(bytes32 => address) public override getPool; // all GS Pools addresses can be predetermined

    /// @dev See {IGammaPoolFactory-origMin}
    uint24 public override origMin = 10000;

    /// @dev See {IGammaPoolFactory-origMax}
    uint24 public override origMax = 10000;

    /// @dev See {IGammaPoolFactory-fee}
    uint16 public override fee = 10000; // Default value is 10,000 basis points or 10%

    /// @dev See {IGammaPoolFactory-feeTo}
    address public override feeTo;

    /// @dev See {IGammaPoolFactory-feeToSetter}
    address public override feeToSetter;

    /// @dev See {IGammaPoolFactory-owner}
    address public override owner;

    /// @dev Pending owner to implement transfer of ownership in two steps
    address public pendingOwner;

    /// @dev Revert if sender is not the required address in parameter (e.g. sender not owner or feeToSetter)
    /// @param _address - address transaction sender must be in order to not revert
    function isForbidden(address _address) internal virtual view {
        if(msg.sender != _address) {
            revert Forbidden();
        }
    }

    /// @dev Revert if address parameter is zero address. This is used transaction that are changing an address state variable
    /// @param _address - address that must not be zero
    function isZeroAddress(address _address) internal virtual view {
        if(_address == address(0)) {
            revert ZeroAddress();
        }
    }

    /// @dev Revert if key already maps to a GammaPool. This is used to avoid duplicating GammaPool instances
    /// @param key - unique key used to identify GammaPool instance (e.g. salt)
    function hasPool(bytes32 key) internal virtual view {
        if(getPool[key] != address(0)) {
            revert PoolExists();
        }
    }

    /// @dev Starts ownership transfer to new account. Replaces the pending transfer if there is one. Can only be called by the current owner.
    /// @param newOwner - new address that will have the owner privileges over the factory contract
    function transferOwnership(address newOwner) external virtual {
        isForbidden(owner); // only owner of the factory contract can call this function
        isZeroAddress(newOwner); // not allow to transfer ownership to zero address (renounce ownership forever)
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @notice The new owner accepts the ownership transfer.
    /// @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
    function acceptOwnership() external virtual {
        address newOwner = msg.sender;
        if(pendingOwner != newOwner) {
            revert NotNewOwner();
        }
        address oldOwner = owner;
        owner = newOwner;
        delete pendingOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     *
     * @param implementation - implementation address of GammaPool. Because all GammaPools are created as proxy contracts
     * @param salt - the bytes32 key that is unique to the GammaPool and therefore also used as a unique identifier of the GammaPool
     * @return instance - address of GammaPool that was created
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
        if(instance == address(0)) {
            revert DeployFailed(); // revert if failed to instantiate GammaPool
        }
    }
}
