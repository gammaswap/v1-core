// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable {

    error Paused(uint8 _functionId);

    error NotPaused(uint8 _functionId);

    /// @dev Emitted when the pause is triggered by `account`.
    event Pause(address account, uint8 _functionId);

    /// @dev Emitted when the unpause is triggered by `account`.
    event Unpause(address account, uint8 _functionId);

    /// @dev Initializes the contract in unpaused state.
    constructor() {
    }

    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier whenNotPaused(uint8 bitIndex) {
        _requireNotPaused(bitIndex);
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused. The contract must be paused.
    modifier whenPaused(uint8 bitIndex) {
        _requirePaused(bitIndex);
        _;
    }

    /// @dev address allowed to pause functions
    function _pauser() internal virtual view returns(address);

    /// @dev ids of paused functions
    function _functionIds() internal virtual view returns(uint256);

    /// @dev ids of paused functions
    function _setFunctionIds(uint256 _funcIds) internal virtual;

    // @dev Throws if the contract is paused.
    function _requireNotPaused(uint8 bitIndex) internal view virtual {
        if(isPaused(bitIndex)) revert Paused(bitIndex);
    }

    /// @dev Throws if the contract is not paused.
    function _requirePaused(uint8 bitIndex) internal view virtual {
        if(!isPaused(bitIndex)) revert NotPaused(bitIndex);
    }

    /// @dev Returns true if the contract is paused, and false otherwise.
    function isPaused(uint8 bitIndex) public view returns (bool) {
        require(bitIndex < 256, "bitIndex must be less than 256");

        uint256 mask = uint256(1) << bitIndex;
        return (_functionIds() & mask) != 0;
    }

    /// @dev Triggers stopped state. The contract must not be paused.
    function pause(uint8 bitIndex) external returns (uint256) {
        require(msg.sender == _pauser(), "FORBIDDEN");
        require(bitIndex < 256, "bitIndex must be less than 256");

        uint256 mask = uint256(1) << bitIndex;
        uint256 functionIds = _functionIds() | mask;

        _setFunctionIds(functionIds);

        emit Pause(msg.sender, bitIndex);

        return functionIds;
    }

    /// @dev Returns to normal state. The contract must be paused.
    function unpause(uint8 bitIndex) external returns (uint256) {
        require(msg.sender == _pauser(), "FORBIDDEN");
        require(bitIndex < 256, "bitIndex must be less than 256");

        uint256 mask = ~(uint256(1) << bitIndex);
        uint256 functionIds = _functionIds() & mask;

        _setFunctionIds(functionIds);

        emit Unpause(msg.sender, bitIndex);

        return functionIds;
    }
}
