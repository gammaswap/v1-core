// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @title Interface for Pausable contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev All instantiated Pausable contracts must implement this interface so that they can pause individual functions
interface IPausable {

    /// @dev Pause a GammaPool's function identified by a `_functionId`
    /// @param _functionId - id of function in GammaPool we want to pause
    /// @return isPaused - true if function identified by `_functionId` is paused
    function isPaused(uint8 _functionId) external view returns (bool);

    /// @dev Pause a GammaPool's function identified by a `_functionId`
    /// @param _functionId - id of function in GammaPool we want to pause
    /// @return _functionIds - uint256 number containing all turned on (paused) function ids
    function pause(uint8 _functionId) external returns (uint256);

    /// @dev Unpause a GammaPool's function identified by a `_functionId`
    /// @param _functionId - id of function in GammaPool we want to unpause
    /// @return _functionIds - uint256 number containing all turned on (paused) function ids
    function unpause(uint8 _functionId) external returns (uint256);
}
