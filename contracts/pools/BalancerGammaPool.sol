// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/GammaPool.sol";
import "../libraries/AddressCalculator.sol";
import "../libraries/GammaSwapLibrary.sol";
import "../interfaces/balancer/IWeightedPool.sol";
import "../interfaces/balancer/IVault.sol";

/**
 * @title GammaPool implementation for Balancer Weighted Pool
 * @author JakeXBT (https://github.com/JakeXBT)
 * @dev This implementation is specifically for validating Balancer Weighted Pools
 */
contract BalancerGammaPool is GammaPool {

    error NotContract();
    error BadVaultAddress();
    error BadPoolId();
    error BadPoolAddress();
    error IncorrectTokenLength();
    error IncorrectTokens();

    using LibStorage for LibStorage.Storage;

    /// @return tokenCount - number of tokens expected in CFMM
    uint8 constant public tokenCount = 2;

    /**
     * @return balancerVault Vault contract corresponding to the Balancer weighted pool.
     */
    address immutable public balancerVault;

    /**
     * @return poolId Pool ID of the Balancer weighted pool.
     */
    bytes32 immutable public poolId;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `longStrategy`, `shortStrategy`, `liquidationStrategy`, `balancerVault`, and `poolId`.
    constructor(uint16 _protocolId, address _factory, address _longStrategy, address _shortStrategy, address _liquidationStrategy, address _balancerVault, bytes32 _poolId)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
        balancerVault = _balancerVault;
        poolId = _poolId;
    }

    /// @dev See {IGammaPool-createLoan}
    function createLoan() external lock virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(tokenCount); // save gas using constant variable tokenCount
        emit LoanCreated(msg.sender, tokenId);
    }

    /// @dev See {IGammaPool-validateCFMM}
    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory _tokensOrdered, uint8[] memory _decimals) {
        if(!GammaSwapLibrary.isContract(_cfmm)) { // Not a smart contract (hence not a CFMM) or not instantiated yet
            revert NotContract();
        }

        // Order tokens to match order of tokens in CFMM
        _tokensOrdered = new address[](2);
        (_tokensOrdered[0], _tokensOrdered[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);

        // Verify the CFMM address corresponds to a Balancer weighted pool with correct tokens and the correct Vault contract
        address poolVaultAddress = IWeightedPool(_cfmm).getVault();
        if(poolVaultAddress != balancerVault) {
            revert BadVaultAddress();
        }

        // Verify the pool ID implied from the WeightedPool contract matches the pool ID given in the constructor
        bytes32 vaultPoolId = IWeightedPool(_cfmm).getPoolId();
        if(vaultPoolId != poolId) {
            revert BadPoolId();
        }

        // Verify the pool address implied from the Vault at the pool ID matches the CFMM address
        address poolAddress = IVault(balancerVault).getPool(poolId);
        if(poolAddress != _cfmm) {
            revert BadPoolAddress();
        }

        uint256[] memory vaultTokens = IVault(balancerVault).getPoolTokens(poolId);
        if(vaultTokens.length != tokenCount) {
            revert IncorrectTokenLength();
        }

        // Verify the tokens in the CFMM match the tokens given in the constructor
        if(_tokensOrdered[0] != address(vaultTokens[0]) || _tokensOrdered[1] != address(vaultTokens[1])) {
            revert IncorrectTokens();
        }

        // Get CFMM's tokens' decimals
        _decimals = new uint8[](2);
        _decimals[0] = GammaSwapLibrary.decimals(_tokensOrdered[0]);
        _decimals[1] = GammaSwapLibrary.decimals(_tokensOrdered[1]);
    }

}
