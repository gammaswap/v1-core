// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../interfaces/periphery/IExternalCallee.sol";
import "../../../libraries/GammaSwapLibrary.sol";

contract TestExternalCallee is IExternalCallee {
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
        if(lpTokens > 0) GammaSwapLibrary.safeTransfer(decoded.cfmm, decoded.strategy, lpTokens);
        if(amounts.length > 0) GammaSwapLibrary.safeTransfer(decoded.token0, decoded.strategy, amounts[0]);
        if(amounts.length > 1) GammaSwapLibrary.safeTransfer(decoded.token1, decoded.strategy, amounts[1]);
    }
}
