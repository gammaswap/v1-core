// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../base/GammaPool.sol";

contract TestGammaPool4626 is GammaPool {

    using LibStorage for LibStorage.Storage;

    struct params {
        uint16 protocolId;
        address cfmm;
    }

    constructor(uint16 _protocolId, address _factory, address _borrowStrategy, address _repayStrategy, address _rebalanceStrategy,
        address _shortStrategy, address _singleLiquidationStrategy, address _batchLiquidationStrategy, address _viewer)
        GammaPool(_protocolId, _factory, _borrowStrategy, _repayStrategy, _rebalanceStrategy, _shortStrategy,
        _singleLiquidationStrategy, _batchLiquidationStrategy, _viewer) {
    }

    function setAccFeeIndex(uint80 _accFeeIndex) external virtual {
        s.accFeeIndex = _accFeeIndex;
    }

    function _getLastCFMMPrice() internal virtual override view returns(uint256) {
        return 1;
    }

    function _calcInvariant(uint128[] memory tokensHeld) internal virtual override view returns(uint256) {
        return tokensHeld[0] * 100;
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

    function validateCFMM(address[] calldata _tokens, address _cfmm, bytes calldata _data) external virtual override view returns(address[] memory _tokensOrdered) {
        params memory decoded = abi.decode(_data, (params));
        require(decoded.cfmm == _cfmm, "Validation");
        _tokensOrdered = _tokens;
    }

    function _totalAssetsAndSupply() internal view override returns (uint256 assets, uint256 supply) {
        (assets, ) = super._totalAssetsAndSupply();
        supply = s.totalSupply;
    }
}
