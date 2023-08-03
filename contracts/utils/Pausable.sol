// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../interfaces/IPausable.sol";

/// @title Abstract Pausable contract.
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Abstract implementation of IPausable interface.
/// @dev Pauses individual functions in inherited contract through bit manipulation of a 256 bit number
/// @dev The 256 bit number means there are at most 255 functions that can be paused by turning on the respective bit index that identifies that function
/// @dev If the 256 bit number is set to 0, that means no function is paused. If it's not zero at least one function is paused
abstract contract Pausable is IPausable {

    error Paused(uint8 _functionId);
    error NotPaused(uint8 _functionId);

    /// @dev Emitted when the pause is triggered by `account`.
    event Pause(address account, uint8 _functionId);

    /// @dev Emitted when the unpause is triggered by `account`.
    event Unpause(address account, uint8 _functionId);

    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier whenNotPaused(uint8 _functionId) {
        _requireNotPaused(_functionId);
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused. The contract must be paused.
    modifier whenPaused(uint8 _functionId) {
        _requirePaused(_functionId);
        _;
    }

    /// @dev address allowed to pause functions
    function _pauser() internal virtual view returns(address);

    /// @dev 256 bit number whose indices represent the ids of pausable functions
    function _functionIds() internal virtual view returns(uint256);

    /// @dev Update 256 bit number whose indices represent the ids of pausable functions
    function _setFunctionIds(uint256 _funcIds) internal virtual;

    // @dev Throws if the contract is paused.
    function _requireNotPaused(uint8 _functionId) internal view virtual {
        if(isPaused(_functionId)) revert Paused(_functionId);
    }

    /// @dev Throws if the contract is not paused.
    function _requirePaused(uint8 _functionId) internal view virtual {
        if(!isPaused(_functionId)) revert NotPaused(_functionId);
    }

    /// @dev Returns true if the contract is paused, and false otherwise.
    function isPaused(uint8 _functionId) public override virtual view returns (bool) {
        require(_functionId < 256, "_functionId must be less than 256");

        uint256 mask = uint256(1) << _functionId;
        return (_functionIds() & mask) != 0;
    }

    /// @dev Triggers stopped state. The contract must not be paused.
    function pause(uint8 _functionId) external override virtual returns (uint256) {
        require(msg.sender == _pauser(), "FORBIDDEN");
        require(_functionId < 256, "_functionId must be less than 256");

        uint256 mask = uint256(1) << _functionId;
        uint256 functionIds = _functionIds() | mask;

        _setFunctionIds(functionIds);

        emit Pause(msg.sender, _functionId);

        return functionIds;
    }

    /// @dev Returns to normal state. The contract must be paused.
    function unpause(uint8 _functionId) external override virtual returns (uint256) {
        require(msg.sender == _pauser(), "FORBIDDEN");
        require(_functionId < 256, "_functionId must be less than 256");

        uint256 mask = ~(uint256(1) << _functionId);
        uint256 functionIds = _functionIds() & mask;

        _setFunctionIds(functionIds);

        emit Unpause(msg.sender, _functionId);

        return functionIds;
    }
}
