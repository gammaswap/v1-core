// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./IGammaPool.sol";

/// @title Interface for TokenMetaData
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used to get ERC20 token metadata
interface ITokenMetaData {
    /// @dev Get CFMM token symbol
    /// @param _token - address of ERC20 token
    /// @return _symbol - symbol of ERC20 token
    function getTokenSymbol(address _token) external view returns(string memory _symbol);

    /// @dev Get CFMM token name
    /// @param _token - address of ERC20 token
    /// @return _name - name of ERC20 token
    function getTokenName(address _token) external view returns(string memory _name);

    /// @dev Get CFMM token name
    /// @param _token - address of ERC20 token
    /// @return _decimals - decimals of ERC20 token
    function getTokenDecimals(address _token) external view returns(uint8 _decimals);
}
