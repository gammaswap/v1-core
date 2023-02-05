// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

// Interface for the Balancer WeightedPool contract
// E.g. https://etherscan.io/address/0xd1ec5e215e8148d76f4460e4097fd3d5ae0a3558#readContract

interface IWeightedPool {
    // Fetches the pool weights for both assets
    function getNormalizedWeights() external view returns (uint256[] memory);
    
    // Fetches the pool current invariant
    function getInvariant() external view returns (uint256 invariant);

    // Fetches the pool previous invariant
    function getLastInvariant() external view returns (uint256 invariant);

    // Fetches the swap fee percentage for the pool
    function getSwapFeePercentage() external view returns (uint256 swapFeePercentage);

    // Fetches the pool ID
    function getPoolId() external view returns (bytes32 poolId);

    // Fetches the vault address corresponding to the pool
    function getVault() external view returns (address);
}
