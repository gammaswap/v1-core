// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../interfaces/periphery/IExternalCallee.sol";

contract TestExternalCalleeEmpty is IExternalCallee {
    constructor(){
    }

    function externalCall(address sender, uint128[] calldata amounts, uint256 lpTokens, bytes calldata data) external {
    }
}
