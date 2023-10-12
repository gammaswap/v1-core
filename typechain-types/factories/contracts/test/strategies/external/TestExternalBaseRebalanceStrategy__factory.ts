/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  TestExternalBaseRebalanceStrategy,
  TestExternalBaseRebalanceStrategyInterface,
} from "../../../../../contracts/test/strategies/external/TestExternalBaseRebalanceStrategy";

const _abi = [
  {
    inputs: [],
    name: "ExcessiveBurn",
    type: "error",
  },
  {
    inputs: [],
    name: "ExternalCollateralRef",
    type: "error",
  },
  {
    inputs: [],
    name: "Forbidden",
    type: "error",
  },
  {
    inputs: [],
    name: "Initialized",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidAmountsLength",
    type: "error",
  },
  {
    inputs: [],
    name: "LoanDoesNotExist",
    type: "error",
  },
  {
    inputs: [],
    name: "Locked",
    type: "error",
  },
  {
    inputs: [],
    name: "Margin",
    type: "error",
  },
  {
    inputs: [],
    name: "MinBorrow",
    type: "error",
  },
  {
    inputs: [],
    name: "NotEnoughBalance",
    type: "error",
  },
  {
    inputs: [],
    name: "NotEnoughCollateral",
    type: "error",
  },
  {
    inputs: [],
    name: "NotEnoughLPDeposit",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongLPTokenBalance",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddress",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAmount",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "caller",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "LoanCreated",
    type: "event",
  },
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
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [],
    name: "_borrowRate",
    outputs: [
      {
        internalType: "uint80",
        name: "",
        type: "uint80",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "_origFee",
    outputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint128",
        name: "liquidity",
        type: "uint128",
      },
    ],
    name: "createLoan",
    outputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
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
    ],
    name: "getLoan",
    outputs: [
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "poolId",
        type: "address",
      },
      {
        internalType: "uint128[]",
        name: "tokensHeld",
        type: "uint128[]",
      },
      {
        internalType: "uint256",
        name: "heldLiquidity",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "initLiquidity",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "liquidity",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "lpTokens",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "rateIndex",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getParameters",
    outputs: [
      {
        internalType: "uint16",
        name: "_protocolId",
        type: "uint16",
      },
      {
        internalType: "address",
        name: "cfmm",
        type: "address",
      },
      {
        internalType: "address",
        name: "factory",
        type: "address",
      },
      {
        internalType: "address[]",
        name: "tokens",
        type: "address[]",
      },
      {
        internalType: "uint8[]",
        name: "decimals",
        type: "uint8[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getPoolBalances",
    outputs: [
      {
        internalType: "uint128[]",
        name: "tokenBalances",
        type: "uint128[]",
      },
      {
        internalType: "uint128[]",
        name: "cfmmReserves",
        type: "uint128[]",
      },
      {
        internalType: "uint256",
        name: "lastCFMMTotalSupply",
        type: "uint256",
      },
      {
        internalType: "uint128",
        name: "lastCFMMInvariant",
        type: "uint128",
      },
      {
        internalType: "uint256",
        name: "lpTokenBalance",
        type: "uint256",
      },
      {
        internalType: "uint128",
        name: "lpInvariant",
        type: "uint128",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "factory",
        type: "address",
      },
      {
        internalType: "address",
        name: "_cfmm",
        type: "address",
      },
      {
        internalType: "uint16",
        name: "_protocolId",
        type: "uint16",
      },
      {
        internalType: "address[]",
        name: "_tokens",
        type: "address[]",
      },
      {
        internalType: "uint8[]",
        name: "_decimals",
        type: "uint8[]",
      },
    ],
    name: "initialize",
    outputs: [],
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
  {
    inputs: [],
    name: "protocolId",
    outputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "rateParamsStore",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_swapFee",
        type: "uint256",
      },
    ],
    name: "setExternalSwapFee",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "swapFee",
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
  {
    inputs: [],
    name: "updatePoolBalances",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes",
        name: "_data",
        type: "bytes",
      },
    ],
    name: "validateParameters",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

export class TestExternalBaseRebalanceStrategy__factory {
  static readonly abi = _abi;
  static createInterface(): TestExternalBaseRebalanceStrategyInterface {
    return new utils.Interface(
      _abi
    ) as TestExternalBaseRebalanceStrategyInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): TestExternalBaseRebalanceStrategy {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as TestExternalBaseRebalanceStrategy;
  }
}
