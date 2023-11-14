// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/IPausable.sol";

/// @title Abstract Pausable contract.
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Abstract implementation of IPausable interface.
/// @dev Pauses individual functions in inherited contract through bit manipulation of a 256 bit number
/// @dev The 256 bit number means there are at most 255 functions that can be paused by turning on the respective bit index that identifies that function
/// @dev If the zeroth bit is turned on, then all pausable functions are paused
abstract contract Pausable is IPausable {

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

    /// @dev See {IPausable-functionIds}
    function functionIds() external override virtual view returns(uint256) {
        return _functionIds();
    }

    // @dev Throws if the contract is paused.
    function _requireNotPaused(uint8 _functionId) internal view virtual {
        if(isPaused(_functionId)) revert Paused(_functionId);
    }

    /// @dev Throws if the contract is not paused.
    function _requirePaused(uint8 _functionId) internal view virtual {
        if(!isPaused(_functionId)) revert NotPaused(_functionId);
    }

    /// @dev See {IPausable-isPaused}
    function isPaused(uint8 _functionId) public override virtual view returns (bool) {
        uint256 funcIds = _functionIds();
        uint256 mask = uint256(1) << _functionId;
        return funcIds == 1 || (funcIds & mask) != 0;
    }

    /// @dev See {IPausable-pause}
    function pause(uint8 _functionId) external override virtual returns (uint256) {
        if(msg.sender != _pauser()) revert ForbiddenPauser();

        uint256 mask = uint256(1) << _functionId;
        uint256 funcIds = _functionIds() | mask;

        _setFunctionIds(funcIds);

        emit Pause(msg.sender, _functionId);

        return funcIds;
    }

    /// @dev See {IPausable-unpause}
    function unpause(uint8 _functionId) external override virtual returns (uint256) {
        if(msg.sender != _pauser()) revert ForbiddenPauser();

        uint256 mask = ~(uint256(1) << _functionId);
        uint256 funcIds = _functionIds() & mask;

        _setFunctionIds(funcIds);

        emit Unpause(msg.sender, _functionId);

        return funcIds;
    }
}
