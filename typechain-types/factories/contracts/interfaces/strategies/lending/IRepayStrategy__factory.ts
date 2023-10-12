/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  IRepayStrategy,
  IRepayStrategyInterface,
} from "../../../../../contracts/interfaces/strategies/lending/IRepayStrategy";

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint128[]",
        name: "tokensHeld",
        type: "uint128[]",
      },
      {
        indexed: false,
        internalType: "uint128",
        name: "liquidity",
        type: "uint128",
      },
      {
        indexed: false,
        internalType: "uint128",
        name: "initLiquidity",
        type: "uint128",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "lpTokens",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint96",
        name: "rateIndex",
        type: "uint96",
      },
      {
        indexed: true,
        internalType: "enum IStrategyEvents.TX_TYPE",
        name: "txType",
        type: "uint8",
      },
    ],
    name: "LoanUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "lpTokenBalance",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "lpTokenBorrowed",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint40",
        name: "lastBlockNumber",
        type: "uint40",
      },
      {
        indexed: false,
        internalType: "uint80",
        name: "accFeeIndex",
        type: "uint80",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "lpTokenBorrowedPlusInterest",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint128",
        name: "lpInvariant",
        type: "uint128",
      },
      {
        indexed: false,
        internalType: "uint128",
        name: "borrowedInvariant",
        type: "uint128",
      },
      {
        indexed: false,
        internalType: "uint128[]",
        name: "cfmmReserves",
        type: "uint128[]",
      },
      {
        indexed: true,
        internalType: "enum IStrategyEvents.TX_TYPE",
        name: "txType",
        type: "uint8",
      },
    ],
    name: "PoolUpdated",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "liquidity",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "collateralId",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
    ],
    name: "_repayLiquidity",
    outputs: [
      {
        internalType: "uint256",
        name: "liquidityPaid",
        type: "uint256",
      },
      {
        internalType: "uint256[]",
        name: "amounts",
        type: "uint256[]",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "liquidity",
        type: "uint256",
      },
      {
        internalType: "uint256[]",
        name: "ratio",
        type: "uint256[]",
      },
    ],
    name: "_repayLiquiditySetRatio",
    outputs: [
      {
        internalType: "uint256",
        name: "liquidityPaid",
        type: "uint256",
      },
      {
        internalType: "uint256[]",
        name: "amounts",
        type: "uint256[]",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "collateralId",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
    ],
    name: "_repayLiquidityWithLP",
    outputs: [
      {
        internalType: "uint256",
        name: "liquidityPaid",
        type: "uint256",
      },
      {
        internalType: "uint128[]",
        name: "tokensHeld",
        type: "uint128[]",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "ltvThreshold",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

export class IRepayStrategy__factory {
  static readonly abi = _abi;
  static createInterface(): IRepayStrategyInterface {
    return new utils.Interface(_abi) as IRepayStrategyInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IRepayStrategy {
    return new Contract(address, _abi, signerOrProvider) as IRepayStrategy;
  }
}
