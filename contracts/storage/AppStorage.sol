// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../libraries/LibStorage.sol";

contract AppStorage {

    LibStorage.Storage internal s;

    error Locked();

    modifier lock() {
        if(s.unlocked != 1)
            revert Locked();
        s.unlocked = 0;
        _;
        s.unlocked = 1;
    }
}
