// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../libraries/LibStorage.sol";

/// @title Contract that implements App Storage pattern in GammaPool contracts
/// @author Daniel D. Alcarraz
/// @notice This pattern is based on Nick Mudge's App Storage implementation (https://dev.to/mudgen/appstorage-pattern-for-state-variables-in-solidity-3lki)
/// @dev This contract has to be inherited as the root contract in an inheritance hierarchy
contract AppStorage {

    /// @notice Global storage variables of GammaPool according to App Storage pattern
    /// @dev No other state variable should be defined before this state variable
    LibStorage.Storage internal s;

    error Locked();

    /// @dev Mutex implementation to prevent a contract from calling itself, directly or indirectly.
    modifier lock() {
        if(s.unlocked != 1)
            revert Locked();
        s.unlocked = 0;
        _;
        s.unlocked = 1;
    }
}
