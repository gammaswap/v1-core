// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Two Step Ownership Contract implementation
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Transfers ownership of contract to another address using a two step method
contract TwoStepOwnable {
    /// @dev Event emitted when ownership of GammaPoolFactory contract is transferred to a new address
    /// @param previousOwner - previous address that owned factory contract
    /// @param newOwner - new address that owns factory contract
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev Event emitted when change of ownership of GammaPoolFactory contract is started
    /// @param currentOwner - current address that owns factory contract
    /// @param newOwner - new address that will own factory contract
    event OwnershipTransferStarted(address indexed currentOwner, address indexed newOwner);

    /// @dev Owner of contract
    address public owner;

    /// @dev Pending owner to implement transfer of ownership in two steps
    address public pendingOwner;

    /// @dev Initialize `owner` of smart contract
    constructor(address _owner) {
        owner = _owner;
    }

    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /// @dev Throws if the sender is not the owner.
    function _checkOwner() internal view virtual {
        require(owner == msg.sender, "Forbidden");
    }

    /// @dev Starts ownership transfer to new account. Replaces the pending transfer if there is one. Can only be called by the current owner.
    /// @param newOwner - new address that will have the owner privileges over the factory contract
    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "ZeroAddress");// not allow to transfer ownership to zero address (renounce ownership forever)
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @notice The new owner accepts the ownership transfer.
    /// @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
    function acceptOwnership() external virtual {
        address newOwner = msg.sender;
        require(pendingOwner == newOwner, "NotNewOwner");
        address oldOwner = owner;
        owner = newOwner;
        delete pendingOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

}