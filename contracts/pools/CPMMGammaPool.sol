// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/GammaPool.sol";
import "../libraries/AddressCalculator.sol";

contract CPMMGammaPool is GammaPool{

    error NotContract();
    error BadProtocol();

    using LibStorage for LibStorage.Storage;

    bytes4 private constant DECIMALS = bytes4(keccak256(bytes('decimals()')));

    uint8 constant public tokenCount = 2;
    address immutable public cfmmFactory;
    bytes32 immutable public cfmmInitCodeHash;

    constructor(uint16 _protocolId, address _factory, address _longStrategy, address _shortStrategy, address _liquidationStrategy,
        address _cfmmFactory, bytes32 _cfmmInitCodeHash)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
        cfmmFactory = _cfmmFactory;
        cfmmInitCodeHash = _cfmmInitCodeHash;
    }

    function createLoan() external virtual override lock returns(uint256 tokenId) {
        tokenId = s.createLoan(tokenCount);
        emit LoanCreated(msg.sender, tokenId);
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens, uint8[] memory decimals) {
        if(!isContract(_cfmm)) {
            revert NotContract();
        }

        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);//For Uniswap and its clones the user passes the parameters
        if(_cfmm != AddressCalculator.calcAddress(cfmmFactory,keccak256(abi.encodePacked(tokens[0], tokens[1])),cfmmInitCodeHash)) {
            revert BadProtocol();
        }
        decimals = new uint8[](2);
        decimals[0] = tokenDecimals(tokens[0]);
        decimals[1] = tokenDecimals(tokens[1]);
    }

    function tokenDecimals(address token) internal view returns (uint8) {
        (bool success, bytes memory data) =
        token.staticcall(abi.encodeWithSelector(DECIMALS));
        require(success && data.length >= 1);
        return abi.decode(data, (uint8));
    }

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
