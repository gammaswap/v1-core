// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../libraries/LibStorage.sol";

/// @title Contract that implements App Storage pattern in GammaPool contracts
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice This pattern is based on Nick Mudge's App Storage implementation (https://dev.to/mudgen/appstorage-pattern-for-state-variables-in-solidity-3lki)
/// @dev This contract has to be inherited as the root contract in an inheritance hierarchy
abstract contract AppStorage {

    /// @notice Global storage variables of GammaPool according to App Storage pattern
    /// @dev No other state variable should be defined before this state variable
    LibStorage.Storage internal s;

    error Locked();

    /// @dev Mutex implementation to prevent a contract from calling itself, directly or indirectly.
    modifier lock() {
        _lock();
        _;
        _unlock();
    }

    function _lock() internal {
        if(s.unlocked != 1) revert Locked();
        s.unlocked = 0;
    }

    function _unlock() internal {
        s.unlocked = 1;
    }
}
