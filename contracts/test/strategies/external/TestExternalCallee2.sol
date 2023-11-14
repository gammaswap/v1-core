// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../interfaces/periphery/IExternalCallee.sol";
import "../../../libraries/GammaSwapLibrary.sol";

contract TestExternalCallee2 is IExternalCallee {
    struct SwapData {
        address strategy;
        address cfmm;
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        uint256 lpTokens;
    }

    constructor() {
    }

    function externalCall(address sender, uint128[] calldata amounts, uint256 lpTokens, bytes calldata data) external {
        SwapData memory decoded = abi.decode(data, (SwapData));
        if(decoded.lpTokens > 0) GammaSwapLibrary.safeTransfer(decoded.cfmm, decoded.strategy, decoded.lpTokens);
        if(decoded.amount0 > 0) GammaSwapLibrary.safeTransfer(decoded.token0, decoded.strategy, decoded.amount0);
        if(decoded.amount1 > 0) GammaSwapLibrary.safeTransfer(decoded.token1, decoded.strategy, decoded.amount1);
    }
}
