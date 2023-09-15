<p align="center"><a href="https://gammaswap.com" target="_blank" rel="noopener noreferrer"><img width="100" src="https://app.gammaswap.com/logo.svg" alt="Gammaswap logo"></a></p>
  
<p align="center">
  <a href="https://github.com/gammaswap/v1-core/actions/workflows/main.yml">
    <img src="https://github.com/gammaswap/v1-core/actions/workflows/main.yml/badge.svg?branch=main" alt="Compile/Test/Publish">
  </a>
</p>

## Description
This is the repository for the core smart contracts of the GammaSwap V1 protocol. 

This repository does not contain implementations of GammaPools but rather abstract contracts that can be used to implement GammaPools for different types of CFMMs

The only implemented contract in this repository is the GammaPoolFactory which instantiates new GammaPools to enable the borrowing of liquidity from CFMMs and the PoolViewer which views storage data from GammaPools


## Steps to Run GammaSwap Tests Locally

1. Run `yarn` to install GammaSwap dependencies
2. Run `yarn test` to run hardhat tests
3. Run `yarn fuzz` to run foundry tests (Need foundry binaries installed locally)

To deploy contracts to local live network use v1-deployment repository

### Note
To install foundry locally go to [getfoundry.sh](https://getfoundry.sh/)

## Solidity Versions
Code is tested with solidity version 0.8.19.

Concrete contracts support only solidity version 0.8.19.

Abstract contracts support solidity version 0.8.4 and up.

Interfaces support solidity version 0.8.0 and up.

GammaPool.sol, GammaPoolERC4626, and GammaSwapLibrary.sol support solidity version 0.8.13 and up due to [abi.encodecall bug](https://soliditylang.org/blog/2022/03/16/encodecall-bug/).
