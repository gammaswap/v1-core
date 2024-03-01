<p align="center"><a href="https://gammaswap.com" target="_blank" rel="noopener noreferrer"><img width="100" src="https://app.gammaswap.com/logo.svg" alt="Gammaswap logo"></a></p>
  
<p align="center">
  <a href="https://github.com/gammaswap/v1-core/actions/workflows/main.yml">
    <img src="https://github.com/gammaswap/v1-core/actions/workflows/main.yml/badge.svg?branch=main" alt="Compile/Test/Publish">
  </a>
</p>

<h1 align="center">V1-Core</h1>

## Description
This is the repository for the core smart contracts of the GammaSwap V1 protocol. 

This repository does not contain implementations of GammaPools but rather abstract contracts that can be used to implement GammaPools for different types of CFMMs

The only implemented contract in this repository is the GammaPoolFactory which instantiates new GammaPools to enable the borrowing of liquidity from CFMMs,
the PoolViewer which views storage data from GammaPools, and storage contracts to track loans and store price information.

The storage contracts to track loans and store price information are not necessary if a subgraph exists to do the same.

## Steps to Run GammaSwap Tests Locally

1. Run `yarn` to install GammaSwap dependencies
2. Run `yarn test` to run hardhat tests
3. Run `yarn fuzz` to run foundry tests (Need foundry binaries installed locally)

To deploy contracts to local live network use v1-deployment repository

### Note
To install foundry locally go to [getfoundry.sh](https://getfoundry.sh/)

## Solidity Versions
Code is built with solidity version 0.8.21. But the evm in hardhat is set to Paris for Arbitrum deployment.

Concrete contracts support only solidity version 0.8.21.

Abstract contracts support solidity version 0.8.4 and up.

Interfaces support solidity version 0.8.0 and up.

GammaPool.sol, GammaPoolERC4626, and GammaSwapLibrary.sol support solidity version 0.8.13 and up due to [abi.encodecall bug](https://soliditylang.org/blog/2022/03/16/encodecall-bug/).

We used solidity version 0.8.21 so that the code is ready to deploy to ethereum mainnet but set the evm in hardhat to Paris because at the time
arbitrum does not support push0 opcode (shanghai evm).

## Publishing NPM Packages

To publish an npm package follow the following steps 

1. Bump the package.json version to the next level (either major, minor, or patch version)
2. commit to the main branch adding 'publish package' in the comment section of the commit (e.g. when merging a pull request)

### Rules for updating package.json version

1. If change does not break interface, then it's a patch version update
2. If change breaks interface, then it's a minor version update
3. If change is for a new product release to public, it's a major version update

### How to Generate Minimal Beacon Proxy Bytecode

The source code for the Minimal Beacon Proxy is in /contracts/utils/MinimalBeaconProxy.sol

1. Disable bytecode metadata hash in hardhat config file
    solidity: { settings: { metadata: { bytecodeHash: "none" } } }
2. Run 'npx hardhat compile'
3. Retrieve bytecode from MinimalBeaconProxy.json file in artifacts

*The reason for the changes in the bytecode depending on protocolId > 256 is because if protocolId > 256 then it takes
2 bytes in the bytecode instead of 1 byte, which means the bytecode must allocate this space.