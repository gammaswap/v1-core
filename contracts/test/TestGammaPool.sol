// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/GammaPool.sol";

contract TestGammaPool is GammaPool {

    constructor(uint16 _protocolId, address _factory, address _longStrategy, address _shortStrategy, address _liquidationStrategy)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
    }

    function syncTokens() external virtual {
        address[] memory _tokens = s.tokens;
        for(uint256 i; i < _tokens.length;) {
            s.TOKEN_BALANCE[i] = uint128(IERC20(_tokens[i]).balanceOf(address(this)));
            unchecked {
                ++i;
            }
        }
        s.LP_TOKEN_BALANCE = uint128(IERC20(s.cfmm).balanceOf(address(this)));
    }

    function validateCFMM(address[] calldata _tokens, address) external virtual override view returns(address[] memory _tokensOrdered, uint8[] memory _decimals) {
        _tokensOrdered = _tokens;
        _decimals = new uint8[](_tokens.length);
        _decimals[0] = 18;
        _decimals[1] = 18;
    }
}
