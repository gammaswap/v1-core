// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/GammaPool.sol";
import "../libraries/AddressCalculator.sol";

/// @title GammaPool implementation for Constant Product Market Maker
/// @author Daniel D. Alcarraz
/// @dev This implementation is specifically for validating UniswapV2Pair and clone contracts
contract CPMMGammaPool is GammaPool{

    error NotContract();
    error BadProtocol();

    using LibStorage for LibStorage.Storage;

    /// @dev selector of decimals function in ERC20 implementation
    bytes4 private constant DECIMALS = bytes4(keccak256(bytes('decimals()')));

    /// @return tokenCount - number of tokens expected in CFMM
    uint8 constant public tokenCount = 2;

    /// @return cfmmFactory - factory contract that created CFMM
    address immutable public cfmmFactory;

    /// @return cfmmInitCodeHash - init code hash of CFMM
    bytes32 immutable public cfmmInitCodeHash;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `longStrategy`, `shortStrategy`, `liquidationStrategy`, `cfmmFactory`, and `cfmmInitCodeHash`.
    constructor(uint16 _protocolId, address _factory, address _longStrategy, address _shortStrategy, address _liquidationStrategy, address _cfmmFactory, bytes32 _cfmmInitCodeHash)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
        cfmmFactory = _cfmmFactory;
        cfmmInitCodeHash = _cfmmInitCodeHash;
    }

    /// @dev See {IGammaPool-createLoan}
    function createLoan() external lock virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(tokenCount); // save gas using constant variable tokenCount
        emit LoanCreated(msg.sender, tokenId);
    }

    /// @dev See {IGammaPool-validateCFMM}
    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory _tokensOrdered, uint8[] memory _decimals) {
        if(!isContract(_cfmm)) { // not a smart contract (hence not a CFMM) or not instantiated yet
            revert NotContract();
        }

        // order tokens to match order of tokens in CFMM
        _tokensOrdered = new address[](2);
        (_tokensOrdered[0], _tokensOrdered[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);

        // verify CFMM was created by CFMM's factory contract
        if(_cfmm != AddressCalculator.calcAddress(cfmmFactory,keccak256(abi.encodePacked(_tokensOrdered[0], _tokensOrdered[1])),cfmmInitCodeHash)) {
            revert BadProtocol();
        }

        // get CFMM's tokens' decimals
        _decimals = new uint8[](2);
        _decimals[0] = tokenDecimals(_tokensOrdered[0]);
        _decimals[1] = tokenDecimals(_tokensOrdered[1]);
    }

    /// @dev Get decimals of ERC20 token
    /// @param token - address of ERC20 token we are getting the decimal information from
    /// @return decimal - decimals of ERC20 token
    function tokenDecimals(address token) internal view returns (uint8) {
        (bool success, bytes memory data) =
        token.staticcall(abi.encodeWithSelector(DECIMALS)); // requesting via ERC20 decimals implementation
        require(success && data.length >= 1);
        return abi.decode(data, (uint8));
    }

    /// @dev Check if `account` is a smart contract's address and it has been instantiated (has code)
    /// @param account - Ethereum address to check if it's a smart contract address
    /// @return bool - true if it is a smart contract address
    function isContract(address account) internal virtual view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. keccak256('')
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }
}
