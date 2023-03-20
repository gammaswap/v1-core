// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../base/GammaPool.sol";

contract TestGammaPool is GammaPool {

    using LibStorage for LibStorage.Storage;

    struct params {
        uint16 protocolId;
        address cfmm;
    }

    constructor(uint16 _protocolId, address _factory, address _longStrategy, address _shortStrategy, address _liquidationStrategy)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
    }

    function getRebalanceDeltas(uint256 tokenId) external view returns(int256[] memory deltas) {
        return (new int256[](2));
    }

    function _getLastCFMMPrice() internal virtual override view returns(uint256) {
        return 1;
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

    function setUint256(uint256 idx, uint256 val) external virtual {
        s.setUint256(idx, val);
    }

    function getUint256(uint256 idx) external virtual view returns(uint256) {
        return s.getUint256(idx);
    }

    function setInt256(uint256 idx, int256 val) external virtual {
        s.setInt256(idx, val);
    }

    function getInt256(uint256 idx) external virtual view returns(int256) {
        return s.getInt256(idx);
    }

    function setBytes32(uint256 idx, bytes32 val) external virtual {
        s.setBytes32(idx, val);
    }

    function getBytes32(uint256 idx) external virtual view returns(bytes32) {
        return s.getBytes32(idx);
    }

    function setAddress(uint256 idx, address val) external virtual {
        s.setAddress(idx, val);
    }

    function getAddress(uint256 idx) external virtual view returns(address) {
        return s.getAddress(idx);
    }

    function setObj(uint16 _protocolId, address _cfmm) external virtual {
        bytes memory _params = abi.encode(params({cfmm: _cfmm, protocolId: _protocolId}));
        s.obj = _params;
    }

    function setObjData(bytes calldata _data) external virtual {
        s.obj = _data;
    }

    function getObj() external virtual view returns(params memory _params) {
        if(s.obj.length > 0) {
            _params = abi.decode(s.obj, (params));
        } else {
            _params = params({protocolId: 0, cfmm: address(0)});
        }
    }
}
