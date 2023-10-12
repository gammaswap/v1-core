/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "../../../../common";

export interface TestExternalRebalanceStrategyInterface
  extends utils.Interface {
  functions: {
    "_borrowRate()": FunctionFragment;
    "_origFee()": FunctionFragment;
    "_rebalanceExternally(uint256,uint128[],uint256,address,bytes)": FunctionFragment;
    "createLoan(uint128)": FunctionFragment;
    "getLoan(uint256)": FunctionFragment;
    "getParameters()": FunctionFragment;
    "getPoolBalances()": FunctionFragment;
    "initialize(address,address,uint16,address[],uint8[])": FunctionFragment;
    "ltvThreshold()": FunctionFragment;
    "protocolId()": FunctionFragment;
    "rateParamsStore()": FunctionFragment;
    "setExternalSwapFee(uint256)": FunctionFragment;
    "swapFee()": FunctionFragment;
    "updatePoolBalances()": FunctionFragment;
    "validateParameters(bytes)": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "_borrowRate"
      | "_origFee"
      | "_rebalanceExternally"
      | "createLoan"
      | "getLoan"
      | "getParameters"
      | "getPoolBalances"
      | "initialize"
      | "ltvThreshold"
      | "protocolId"
      | "rateParamsStore"
      | "setExternalSwapFee"
      | "swapFee"
      | "updatePoolBalances"
      | "validateParameters"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "_borrowRate",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "_origFee", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "_rebalanceExternally",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>[],
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>,
      PromiseOrValue<BytesLike>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "createLoan",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "getLoan",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "getParameters",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getPoolBalances",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "initialize",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>[],
      PromiseOrValue<BigNumberish>[]
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "ltvThreshold",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "protocolId",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "rateParamsStore",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "setExternalSwapFee",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(functionFragment: "swapFee", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "updatePoolBalances",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "validateParameters",
    values: [PromiseOrValue<BytesLike>]
  ): string;

  decodeFunctionResult(
    functionFragment: "_borrowRate",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "_origFee", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "_rebalanceExternally",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "createLoan", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "getLoan", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getParameters",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getPoolBalances",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "initialize", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "ltvThreshold",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "protocolId", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "rateParamsStore",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setExternalSwapFee",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "swapFee", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "updatePoolBalances",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "validateParameters",
    data: BytesLike
  ): Result;

  events: {
    "ExternalSwap(uint256,uint128[],uint256,uint128,uint8)": EventFragment;
    "LoanCreated(address,uint256)": EventFragment;
    "LoanUpdated(uint256,uint128[],uint128,uint128,uint256,uint96,uint8)": EventFragment;
    "PoolUpdated(uint256,uint256,uint40,uint80,uint256,uint128,uint128,uint128[],uint8)": EventFragment;
    "Transfer(address,address,uint256)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "ExternalSwap"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "LoanCreated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "LoanUpdated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "PoolUpdated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Transfer"): EventFragment;
}

export interface ExternalSwapEventObject {
  tokenId: BigNumber;
  amounts: BigNumber[];
  lpTokens: BigNumber;
  liquidity: BigNumber;
  txType: number;
}
export type ExternalSwapEvent = TypedEvent<
  [BigNumber, BigNumber[], BigNumber, BigNumber, number],
  ExternalSwapEventObject
>;

export type ExternalSwapEventFilter = TypedEventFilter<ExternalSwapEvent>;

export interface LoanCreatedEventObject {
  caller: string;
  tokenId: BigNumber;
}
export type LoanCreatedEvent = TypedEvent<
  [string, BigNumber],
  LoanCreatedEventObject
>;

export type LoanCreatedEventFilter = TypedEventFilter<LoanCreatedEvent>;

export interface LoanUpdatedEventObject {
  tokenId: BigNumber;
  tokensHeld: BigNumber[];
  liquidity: BigNumber;
  initLiquidity: BigNumber;
  lpTokens: BigNumber;
  rateIndex: BigNumber;
  txType: number;
}
export type LoanUpdatedEvent = TypedEvent<
  [BigNumber, BigNumber[], BigNumber, BigNumber, BigNumber, BigNumber, number],
  LoanUpdatedEventObject
>;

export type LoanUpdatedEventFilter = TypedEventFilter<LoanUpdatedEvent>;

export interface PoolUpdatedEventObject {
  lpTokenBalance: BigNumber;
  lpTokenBorrowed: BigNumber;
  lastBlockNumber: number;
  accFeeIndex: BigNumber;
  lpTokenBorrowedPlusInterest: BigNumber;
  lpInvariant: BigNumber;
  borrowedInvariant: BigNumber;
  cfmmReserves: BigNumber[];
  txType: number;
}
export type PoolUpdatedEvent = TypedEvent<
  [
    BigNumber,
    BigNumber,
    number,
    BigNumber,
    BigNumber,
    BigNumber,
    BigNumber,
    BigNumber[],
    number
  ],
  PoolUpdatedEventObject
>;

export type PoolUpdatedEventFilter = TypedEventFilter<PoolUpdatedEvent>;

export interface TransferEventObject {
  from: string;
  to: string;
  amount: BigNumber;
}
export type TransferEvent = TypedEvent<
  [string, string, BigNumber],
  TransferEventObject
>;

export type TransferEventFilter = TypedEventFilter<TransferEvent>;

export interface TestExternalRebalanceStrategy extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: TestExternalRebalanceStrategyInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    _borrowRate(overrides?: CallOverrides): Promise<[BigNumber]>;

    _origFee(overrides?: CallOverrides): Promise<[number]>;

    _rebalanceExternally(
      tokenId: PromiseOrValue<BigNumberish>,
      amounts: PromiseOrValue<BigNumberish>[],
      lpTokens: PromiseOrValue<BigNumberish>,
      to: PromiseOrValue<string>,
      data: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    createLoan(
      liquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    getLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<
      [
        BigNumber,
        string,
        BigNumber[],
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber
      ] & {
        id: BigNumber;
        poolId: string;
        tokensHeld: BigNumber[];
        heldLiquidity: BigNumber;
        initLiquidity: BigNumber;
        liquidity: BigNumber;
        lpTokens: BigNumber;
        rateIndex: BigNumber;
      }
    >;

    getParameters(
      overrides?: CallOverrides
    ): Promise<
      [number, string, string, string[], number[]] & {
        _protocolId: number;
        cfmm: string;
        factory: string;
        tokens: string[];
        decimals: number[];
      }
    >;

    getPoolBalances(
      overrides?: CallOverrides
    ): Promise<
      [BigNumber[], BigNumber[], BigNumber, BigNumber, BigNumber, BigNumber] & {
        tokenBalances: BigNumber[];
        cfmmReserves: BigNumber[];
        lastCFMMTotalSupply: BigNumber;
        lastCFMMInvariant: BigNumber;
        lpTokenBalance: BigNumber;
        lpInvariant: BigNumber;
      }
    >;

    initialize(
      factory: PromiseOrValue<string>,
      _cfmm: PromiseOrValue<string>,
      _protocolId: PromiseOrValue<BigNumberish>,
      _tokens: PromiseOrValue<string>[],
      _decimals: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    ltvThreshold(overrides?: CallOverrides): Promise<[BigNumber]>;

    protocolId(overrides?: CallOverrides): Promise<[number]>;

    rateParamsStore(overrides?: CallOverrides): Promise<[string]>;

    setExternalSwapFee(
      _swapFee: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    swapFee(overrides?: CallOverrides): Promise<[BigNumber]>;

    updatePoolBalances(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<[boolean]>;
  };

  _borrowRate(overrides?: CallOverrides): Promise<BigNumber>;

  _origFee(overrides?: CallOverrides): Promise<number>;

  _rebalanceExternally(
    tokenId: PromiseOrValue<BigNumberish>,
    amounts: PromiseOrValue<BigNumberish>[],
    lpTokens: PromiseOrValue<BigNumberish>,
    to: PromiseOrValue<string>,
    data: PromiseOrValue<BytesLike>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  createLoan(
    liquidity: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  getLoan(
    tokenId: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<
    [
      BigNumber,
      string,
      BigNumber[],
      BigNumber,
      BigNumber,
      BigNumber,
      BigNumber,
      BigNumber
    ] & {
      id: BigNumber;
      poolId: string;
      tokensHeld: BigNumber[];
      heldLiquidity: BigNumber;
      initLiquidity: BigNumber;
      liquidity: BigNumber;
      lpTokens: BigNumber;
      rateIndex: BigNumber;
    }
  >;

  getParameters(
    overrides?: CallOverrides
  ): Promise<
    [number, string, string, string[], number[]] & {
      _protocolId: number;
      cfmm: string;
      factory: string;
      tokens: string[];
      decimals: number[];
    }
  >;

  getPoolBalances(
    overrides?: CallOverrides
  ): Promise<
    [BigNumber[], BigNumber[], BigNumber, BigNumber, BigNumber, BigNumber] & {
      tokenBalances: BigNumber[];
      cfmmReserves: BigNumber[];
      lastCFMMTotalSupply: BigNumber;
      lastCFMMInvariant: BigNumber;
      lpTokenBalance: BigNumber;
      lpInvariant: BigNumber;
    }
  >;

  initialize(
    factory: PromiseOrValue<string>,
    _cfmm: PromiseOrValue<string>,
    _protocolId: PromiseOrValue<BigNumberish>,
    _tokens: PromiseOrValue<string>[],
    _decimals: PromiseOrValue<BigNumberish>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  ltvThreshold(overrides?: CallOverrides): Promise<BigNumber>;

  protocolId(overrides?: CallOverrides): Promise<number>;

  rateParamsStore(overrides?: CallOverrides): Promise<string>;

  setExternalSwapFee(
    _swapFee: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  swapFee(overrides?: CallOverrides): Promise<BigNumber>;

  updatePoolBalances(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  validateParameters(
    _data: PromiseOrValue<BytesLike>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  callStatic: {
    _borrowRate(overrides?: CallOverrides): Promise<BigNumber>;

    _origFee(overrides?: CallOverrides): Promise<number>;

    _rebalanceExternally(
      tokenId: PromiseOrValue<BigNumberish>,
      amounts: PromiseOrValue<BigNumberish>[],
      lpTokens: PromiseOrValue<BigNumberish>,
      to: PromiseOrValue<string>,
      data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber[]] & {
        loanLiquidity: BigNumber;
        tokensHeld: BigNumber[];
      }
    >;

    createLoan(
      liquidity: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<
      [
        BigNumber,
        string,
        BigNumber[],
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber
      ] & {
        id: BigNumber;
        poolId: string;
        tokensHeld: BigNumber[];
        heldLiquidity: BigNumber;
        initLiquidity: BigNumber;
        liquidity: BigNumber;
        lpTokens: BigNumber;
        rateIndex: BigNumber;
      }
    >;

    getParameters(
      overrides?: CallOverrides
    ): Promise<
      [number, string, string, string[], number[]] & {
        _protocolId: number;
        cfmm: string;
        factory: string;
        tokens: string[];
        decimals: number[];
      }
    >;

    getPoolBalances(
      overrides?: CallOverrides
    ): Promise<
      [BigNumber[], BigNumber[], BigNumber, BigNumber, BigNumber, BigNumber] & {
        tokenBalances: BigNumber[];
        cfmmReserves: BigNumber[];
        lastCFMMTotalSupply: BigNumber;
        lastCFMMInvariant: BigNumber;
        lpTokenBalance: BigNumber;
        lpInvariant: BigNumber;
      }
    >;

    initialize(
      factory: PromiseOrValue<string>,
      _cfmm: PromiseOrValue<string>,
      _protocolId: PromiseOrValue<BigNumberish>,
      _tokens: PromiseOrValue<string>[],
      _decimals: PromiseOrValue<BigNumberish>[],
      overrides?: CallOverrides
    ): Promise<void>;

    ltvThreshold(overrides?: CallOverrides): Promise<BigNumber>;

    protocolId(overrides?: CallOverrides): Promise<number>;

    rateParamsStore(overrides?: CallOverrides): Promise<string>;

    setExternalSwapFee(
      _swapFee: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    swapFee(overrides?: CallOverrides): Promise<BigNumber>;

    updatePoolBalances(overrides?: CallOverrides): Promise<void>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<boolean>;
  };

  filters: {
    "ExternalSwap(uint256,uint128[],uint256,uint128,uint8)"(
      tokenId?: PromiseOrValue<BigNumberish> | null,
      amounts?: null,
      lpTokens?: null,
      liquidity?: null,
      txType?: PromiseOrValue<BigNumberish> | null
    ): ExternalSwapEventFilter;
    ExternalSwap(
      tokenId?: PromiseOrValue<BigNumberish> | null,
      amounts?: null,
      lpTokens?: null,
      liquidity?: null,
      txType?: PromiseOrValue<BigNumberish> | null
    ): ExternalSwapEventFilter;

    "LoanCreated(address,uint256)"(
      caller?: PromiseOrValue<string> | null,
      tokenId?: null
    ): LoanCreatedEventFilter;
    LoanCreated(
      caller?: PromiseOrValue<string> | null,
      tokenId?: null
    ): LoanCreatedEventFilter;

    "LoanUpdated(uint256,uint128[],uint128,uint128,uint256,uint96,uint8)"(
      tokenId?: PromiseOrValue<BigNumberish> | null,
      tokensHeld?: null,
      liquidity?: null,
      initLiquidity?: null,
      lpTokens?: null,
      rateIndex?: null,
      txType?: PromiseOrValue<BigNumberish> | null
    ): LoanUpdatedEventFilter;
    LoanUpdated(
      tokenId?: PromiseOrValue<BigNumberish> | null,
      tokensHeld?: null,
      liquidity?: null,
      initLiquidity?: null,
      lpTokens?: null,
      rateIndex?: null,
      txType?: PromiseOrValue<BigNumberish> | null
    ): LoanUpdatedEventFilter;

    "PoolUpdated(uint256,uint256,uint40,uint80,uint256,uint128,uint128,uint128[],uint8)"(
      lpTokenBalance?: null,
      lpTokenBorrowed?: null,
      lastBlockNumber?: null,
      accFeeIndex?: null,
      lpTokenBorrowedPlusInterest?: null,
      lpInvariant?: null,
      borrowedInvariant?: null,
      cfmmReserves?: null,
      txType?: PromiseOrValue<BigNumberish> | null
    ): PoolUpdatedEventFilter;
    PoolUpdated(
      lpTokenBalance?: null,
      lpTokenBorrowed?: null,
      lastBlockNumber?: null,
      accFeeIndex?: null,
      lpTokenBorrowedPlusInterest?: null,
      lpInvariant?: null,
      borrowedInvariant?: null,
      cfmmReserves?: null,
      txType?: PromiseOrValue<BigNumberish> | null
    ): PoolUpdatedEventFilter;

    "Transfer(address,address,uint256)"(
      from?: PromiseOrValue<string> | null,
      to?: PromiseOrValue<string> | null,
      amount?: null
    ): TransferEventFilter;
    Transfer(
      from?: PromiseOrValue<string> | null,
      to?: PromiseOrValue<string> | null,
      amount?: null
    ): TransferEventFilter;
  };

  estimateGas: {
    _borrowRate(overrides?: CallOverrides): Promise<BigNumber>;

    _origFee(overrides?: CallOverrides): Promise<BigNumber>;

    _rebalanceExternally(
      tokenId: PromiseOrValue<BigNumberish>,
      amounts: PromiseOrValue<BigNumberish>[],
      lpTokens: PromiseOrValue<BigNumberish>,
      to: PromiseOrValue<string>,
      data: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    createLoan(
      liquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    getLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getParameters(overrides?: CallOverrides): Promise<BigNumber>;

    getPoolBalances(overrides?: CallOverrides): Promise<BigNumber>;

    initialize(
      factory: PromiseOrValue<string>,
      _cfmm: PromiseOrValue<string>,
      _protocolId: PromiseOrValue<BigNumberish>,
      _tokens: PromiseOrValue<string>[],
      _decimals: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    ltvThreshold(overrides?: CallOverrides): Promise<BigNumber>;

    protocolId(overrides?: CallOverrides): Promise<BigNumber>;

    rateParamsStore(overrides?: CallOverrides): Promise<BigNumber>;

    setExternalSwapFee(
      _swapFee: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    swapFee(overrides?: CallOverrides): Promise<BigNumber>;

    updatePoolBalances(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    _borrowRate(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    _origFee(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    _rebalanceExternally(
      tokenId: PromiseOrValue<BigNumberish>,
      amounts: PromiseOrValue<BigNumberish>[],
      lpTokens: PromiseOrValue<BigNumberish>,
      to: PromiseOrValue<string>,
      data: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    createLoan(
      liquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    getLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getParameters(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    getPoolBalances(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    initialize(
      factory: PromiseOrValue<string>,
      _cfmm: PromiseOrValue<string>,
      _protocolId: PromiseOrValue<BigNumberish>,
      _tokens: PromiseOrValue<string>[],
      _decimals: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    ltvThreshold(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    protocolId(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    rateParamsStore(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    setExternalSwapFee(
      _swapFee: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    swapFee(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    updatePoolBalances(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}
