// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface for Protocol
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used to add protocols and initialize them in GammaPoolFactory
interface IProtocol {
    /// @dev Protocol id of the implementation contract for this GammaPool
    function protocolId() external view returns(uint16);

    /// @dev Check GammaPool for CFMM and tokens can be created with this implementation
    /// @param _tokens - assumed tokens of CFMM, validate function should check CFMM is indeed for these tokens
    /// @param _cfmm - address of CFMM GammaPool will be for
    /// @param _data - custom struct containing additional information used to verify the `_cfmm`
    /// @return _tokensOrdered - tokens ordered to match the same order as in CFMM
    function validateCFMM(address[] calldata _tokens, address _cfmm, bytes calldata _data) external view returns(address[] memory _tokensOrdered);

    /// @dev Function to initialize state variables GammaPool, called usually from GammaPoolFactory contract right after GammaPool instantiation
    /// @param _cfmm - address of CFMM GammaPool is for
    /// @param _tokens - ERC20 tokens of CFMM
    /// @param _decimals - decimals of CFMM tokens, indices must match _tokens[] array
    /// @param _data - custom struct containing additional information used to verify the `_cfmm`
    /// @param _minBorrow - minimum amount of liquidity that can be borrowed or left unpaid in a loan
    function initialize(address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals, uint72 _minBorrow, bytes calldata _data) external;
}
