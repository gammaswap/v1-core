// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/GammaPool.sol";

contract TestGammaPool is GammaPool {

    constructor(uint16 _protocolId, address _factory, address _longStrategy, address _shortStrategy, address _liquidationStrategy)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
    }

    function syncTokens() external virtual {
        address[] memory _tokens = s.tokens;
        for(uint256 i = 0; i < _tokens.length; i++) {
            s.TOKEN_BALANCE[i] = uint128(IERC20(_tokens[i]).balanceOf(address(this)));
        }
        s.LP_TOKEN_BALANCE = uint128(IERC20(s.cfmm).balanceOf(address(this)));
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens, uint8[] memory decimals) {
        tokens = _tokens;
        decimals = new uint8[](_tokens.length);
        decimals[0] = 18;
        decimals[1] = 18;
    }
}
