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
} from "../../../common";

export interface BorrowStrategyInterface extends utils.Interface {
  functions: {
    "_borrowLiquidity(uint256,uint256,uint256[])": FunctionFragment;
    "_decreaseCollateral(uint256,uint128[],address,uint256[])": FunctionFragment;
    "_increaseCollateral(uint256,uint256[])": FunctionFragment;
    "calcDynamicOriginationFee(uint256,uint256,uint256,uint256,uint256,uint256)": FunctionFragment;
    "ltvThreshold()": FunctionFragment;
    "rateParamsStore()": FunctionFragment;
    "validateParameters(bytes)": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "_borrowLiquidity"
      | "_decreaseCollateral"
      | "_increaseCollateral"
      | "calcDynamicOriginationFee"
      | "ltvThreshold"
      | "rateParamsStore"
      | "validateParameters"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "_borrowLiquidity",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>[]
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "_decreaseCollateral",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>[],
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>[]
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "_increaseCollateral",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<BigNumberish>[]]
  ): string;
  encodeFunctionData(
    functionFragment: "calcDynamicOriginationFee",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "ltvThreshold",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "rateParamsStore",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "validateParameters",
    values: [PromiseOrValue<BytesLike>]
  ): string;

  decodeFunctionResult(
    functionFragment: "_borrowLiquidity",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "_decreaseCollateral",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "_increaseCollateral",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "calcDynamicOriginationFee",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "ltvThreshold",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "rateParamsStore",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "validateParameters",
    data: BytesLike
  ): Result;

  events: {
    "LoanUpdated(uint256,uint128[],uint128,uint128,uint256,uint96,uint8)": EventFragment;
    "PoolUpdated(uint256,uint256,uint40,uint80,uint256,uint128,uint128,uint128[],uint8)": EventFragment;
    "Transfer(address,address,uint256)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "LoanUpdated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "PoolUpdated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Transfer"): EventFragment;
}

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

export interface BorrowStrategy extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: BorrowStrategyInterface;

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
    _borrowLiquidity(
      tokenId: PromiseOrValue<BigNumberish>,
      lpTokens: PromiseOrValue<BigNumberish>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    _decreaseCollateral(
      tokenId: PromiseOrValue<BigNumberish>,
      amounts: PromiseOrValue<BigNumberish>[],
      to: PromiseOrValue<string>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    _increaseCollateral(
      tokenId: PromiseOrValue<BigNumberish>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    calcDynamicOriginationFee(
      baseOrigFee: PromiseOrValue<BigNumberish>,
      utilRate: PromiseOrValue<BigNumberish>,
      lowUtilRate: PromiseOrValue<BigNumberish>,
      minUtilRate1: PromiseOrValue<BigNumberish>,
      minUtilRate2: PromiseOrValue<BigNumberish>,
      feeDivisor: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { origFee: BigNumber }>;

    ltvThreshold(overrides?: CallOverrides): Promise<[BigNumber]>;

    rateParamsStore(overrides?: CallOverrides): Promise<[string]>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<[boolean]>;
  };

  _borrowLiquidity(
    tokenId: PromiseOrValue<BigNumberish>,
    lpTokens: PromiseOrValue<BigNumberish>,
    ratio: PromiseOrValue<BigNumberish>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  _decreaseCollateral(
    tokenId: PromiseOrValue<BigNumberish>,
    amounts: PromiseOrValue<BigNumberish>[],
    to: PromiseOrValue<string>,
    ratio: PromiseOrValue<BigNumberish>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  _increaseCollateral(
    tokenId: PromiseOrValue<BigNumberish>,
    ratio: PromiseOrValue<BigNumberish>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  calcDynamicOriginationFee(
    baseOrigFee: PromiseOrValue<BigNumberish>,
    utilRate: PromiseOrValue<BigNumberish>,
    lowUtilRate: PromiseOrValue<BigNumberish>,
    minUtilRate1: PromiseOrValue<BigNumberish>,
    minUtilRate2: PromiseOrValue<BigNumberish>,
    feeDivisor: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  ltvThreshold(overrides?: CallOverrides): Promise<BigNumber>;

  rateParamsStore(overrides?: CallOverrides): Promise<string>;

  validateParameters(
    _data: PromiseOrValue<BytesLike>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  callStatic: {
    _borrowLiquidity(
      tokenId: PromiseOrValue<BigNumberish>,
      lpTokens: PromiseOrValue<BigNumberish>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber[]] & {
        liquidityBorrowed: BigNumber;
        amounts: BigNumber[];
      }
    >;

    _decreaseCollateral(
      tokenId: PromiseOrValue<BigNumberish>,
      amounts: PromiseOrValue<BigNumberish>[],
      to: PromiseOrValue<string>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: CallOverrides
    ): Promise<BigNumber[]>;

    _increaseCollateral(
      tokenId: PromiseOrValue<BigNumberish>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: CallOverrides
    ): Promise<BigNumber[]>;

    calcDynamicOriginationFee(
      baseOrigFee: PromiseOrValue<BigNumberish>,
      utilRate: PromiseOrValue<BigNumberish>,
      lowUtilRate: PromiseOrValue<BigNumberish>,
      minUtilRate1: PromiseOrValue<BigNumberish>,
      minUtilRate2: PromiseOrValue<BigNumberish>,
      feeDivisor: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    ltvThreshold(overrides?: CallOverrides): Promise<BigNumber>;

    rateParamsStore(overrides?: CallOverrides): Promise<string>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<boolean>;
  };

  filters: {
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
    _borrowLiquidity(
      tokenId: PromiseOrValue<BigNumberish>,
      lpTokens: PromiseOrValue<BigNumberish>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    _decreaseCollateral(
      tokenId: PromiseOrValue<BigNumberish>,
      amounts: PromiseOrValue<BigNumberish>[],
      to: PromiseOrValue<string>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    _increaseCollateral(
      tokenId: PromiseOrValue<BigNumberish>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    calcDynamicOriginationFee(
      baseOrigFee: PromiseOrValue<BigNumberish>,
      utilRate: PromiseOrValue<BigNumberish>,
      lowUtilRate: PromiseOrValue<BigNumberish>,
      minUtilRate1: PromiseOrValue<BigNumberish>,
      minUtilRate2: PromiseOrValue<BigNumberish>,
      feeDivisor: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    ltvThreshold(overrides?: CallOverrides): Promise<BigNumber>;

    rateParamsStore(overrides?: CallOverrides): Promise<BigNumber>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    _borrowLiquidity(
      tokenId: PromiseOrValue<BigNumberish>,
      lpTokens: PromiseOrValue<BigNumberish>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    _decreaseCollateral(
      tokenId: PromiseOrValue<BigNumberish>,
      amounts: PromiseOrValue<BigNumberish>[],
      to: PromiseOrValue<string>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    _increaseCollateral(
      tokenId: PromiseOrValue<BigNumberish>,
      ratio: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    calcDynamicOriginationFee(
      baseOrigFee: PromiseOrValue<BigNumberish>,
      utilRate: PromiseOrValue<BigNumberish>,
      lowUtilRate: PromiseOrValue<BigNumberish>,
      minUtilRate1: PromiseOrValue<BigNumberish>,
      minUtilRate2: PromiseOrValue<BigNumberish>,
      feeDivisor: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    ltvThreshold(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    rateParamsStore(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}
