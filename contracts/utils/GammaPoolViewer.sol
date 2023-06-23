pragma solidity >=0.8.4;

import "../libraries/GammaSwapLibrary.sol";
import "../interfaces/IPoolViewer.sol";

contract GammaPoolViewer is IPoolViewer {
    constructor() {
    }

    /// dev See {IGammaPool-getTokensMetaData}
    function getTokensMetaData(address[] memory _tokens) public virtual view returns(string[] memory _symbols, string[] memory _names) {
        _symbols = new string[](_tokens.length);
        _names = new string[](_tokens.length);
        for(uint256 i = 0; i < _tokens.length;) {
            _symbols[i] = GammaSwapLibrary.symbol(_tokens[i]);
            _names[i] = GammaSwapLibrary.name(_tokens[i]);
            unchecked {
                i++;
            }
        }
    }
}
