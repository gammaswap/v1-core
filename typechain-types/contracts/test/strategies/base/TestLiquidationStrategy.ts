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

export declare namespace TestLiquidationStrategy {
  export type PoolBalancesStruct = {
    LP_TOKEN_BALANCE: PromiseOrValue<BigNumberish>;
    LP_TOKEN_BORROWED: PromiseOrValue<BigNumberish>;
    LP_TOKEN_BORROWED_PLUS_INTEREST: PromiseOrValue<BigNumberish>;
    BORROWED_INVARIANT: PromiseOrValue<BigNumberish>;
    LP_INVARIANT: PromiseOrValue<BigNumberish>;
    lastCFMMInvariant: PromiseOrValue<BigNumberish>;
    lastCFMMTotalSupply: PromiseOrValue<BigNumberish>;
  };

  export type PoolBalancesStructOutput = [
    BigNumber,
    BigNumber,
    BigNumber,
    BigNumber,
    BigNumber,
    BigNumber,
    BigNumber
  ] & {
    LP_TOKEN_BALANCE: BigNumber;
    LP_TOKEN_BORROWED: BigNumber;
    LP_TOKEN_BORROWED_PLUS_INTEREST: BigNumber;
    BORROWED_INVARIANT: BigNumber;
    LP_INVARIANT: BigNumber;
    lastCFMMInvariant: BigNumber;
    lastCFMMTotalSupply: BigNumber;
  };
}

export interface TestLiquidationStrategyInterface extends utils.Interface {
  functions: {
    "_batchLiquidations(uint256[])": FunctionFragment;
    "_liquidate(uint256)": FunctionFragment;
    "_liquidateWithLP(uint256)": FunctionFragment;
    "canLiquidate(uint256,uint256)": FunctionFragment;
    "createLoan(uint256)": FunctionFragment;
    "getLoan(uint256)": FunctionFragment;
    "getPoolBalances()": FunctionFragment;
    "getStaticParams()": FunctionFragment;
    "incBorrowedInvariant(uint256)": FunctionFragment;
    "initialize(address,address,address[],uint8[])": FunctionFragment;
    "liquidationFee()": FunctionFragment;
    "ltvThreshold()": FunctionFragment;
    "rateParamsStore()": FunctionFragment;
    "testCanLiquidate(uint256,uint256)": FunctionFragment;
    "testPayBatchLoanAndRefundLiquidator(uint256[])": FunctionFragment;
    "testPayBatchLoans(uint256,uint256)": FunctionFragment;
    "testRefundLiquidator(uint256,uint256,uint256)": FunctionFragment;
    "testRefundOverPayment(uint256,uint256,bool)": FunctionFragment;
    "testSumLiquidity(uint256[])": FunctionFragment;
    "testUpdateLoan(uint256)": FunctionFragment;
    "testWriteDown(uint256,uint256)": FunctionFragment;
    "updatePoolBalances()": FunctionFragment;
    "validateParameters(bytes)": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "_batchLiquidations"
      | "_liquidate"
      | "_liquidateWithLP"
      | "canLiquidate"
      | "createLoan"
      | "getLoan"
      | "getPoolBalances"
      | "getStaticParams"
      | "incBorrowedInvariant"
      | "initialize"
      | "liquidationFee"
      | "ltvThreshold"
      | "rateParamsStore"
      | "testCanLiquidate"
      | "testPayBatchLoanAndRefundLiquidator"
      | "testPayBatchLoans"
      | "testRefundLiquidator"
      | "testRefundOverPayment"
      | "testSumLiquidity"
      | "testUpdateLoan"
      | "testWriteDown"
      | "updatePoolBalances"
      | "validateParameters"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "_batchLiquidations",
    values: [PromiseOrValue<BigNumberish>[]]
  ): string;
  encodeFunctionData(
    functionFragment: "_liquidate",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "_liquidateWithLP",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "canLiquidate",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<BigNumberish>]
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
    functionFragment: "getPoolBalances",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getStaticParams",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "incBorrowedInvariant",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "initialize",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<string>[],
      PromiseOrValue<BigNumberish>[]
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "liquidationFee",
    values?: undefined
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
    functionFragment: "testCanLiquidate",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "testPayBatchLoanAndRefundLiquidator",
    values: [PromiseOrValue<BigNumberish>[]]
  ): string;
  encodeFunctionData(
    functionFragment: "testPayBatchLoans",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "testRefundLiquidator",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "testRefundOverPayment",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<boolean>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "testSumLiquidity",
    values: [PromiseOrValue<BigNumberish>[]]
  ): string;
  encodeFunctionData(
    functionFragment: "testUpdateLoan",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "testWriteDown",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "updatePoolBalances",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "validateParameters",
    values: [PromiseOrValue<BytesLike>]
  ): string;

  decodeFunctionResult(
    functionFragment: "_batchLiquidations",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "_liquidate", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "_liquidateWithLP",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "canLiquidate",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "createLoan", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "getLoan", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getPoolBalances",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getStaticParams",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "incBorrowedInvariant",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "initialize", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "liquidationFee",
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
    functionFragment: "testCanLiquidate",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "testPayBatchLoanAndRefundLiquidator",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "testPayBatchLoans",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "testRefundLiquidator",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "testRefundOverPayment",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "testSumLiquidity",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "testUpdateLoan",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "testWriteDown",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "updatePoolBalances",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "validateParameters",
    data: BytesLike
  ): Result;

  events: {
    "BatchLiquidations(uint256,uint256,uint256,uint128[],uint256[])": EventFragment;
    "Liquidation(uint256,uint128,uint128,uint128,uint128,uint8)": EventFragment;
    "LoanCreated(address,uint256)": EventFragment;
    "LoanUpdated(uint256,uint128[],uint128,uint128,uint256,uint96,uint8)": EventFragment;
    "PoolUpdated(uint256,uint256,uint40,uint80,uint256,uint128,uint128,uint128[],uint8)": EventFragment;
    "Refund(uint128[],uint256[])": EventFragment;
    "RefundLiquidator(uint128[],uint128[])": EventFragment;
    "RefundOverPayment(uint256,uint256)": EventFragment;
    "Transfer(address,address,uint256)": EventFragment;
    "WriteDown2(uint256,uint256)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "BatchLiquidations"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Liquidation"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "LoanCreated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "LoanUpdated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "PoolUpdated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Refund"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "RefundLiquidator"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "RefundOverPayment"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Transfer"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "WriteDown2"): EventFragment;
}

export interface BatchLiquidationsEventObject {
  liquidityTotal: BigNumber;
  collateralTotal: BigNumber;
  lpTokensPrincipalTotal: BigNumber;
  tokensHeldTotal: BigNumber[];
  tokenIds: BigNumber[];
}
export type BatchLiquidationsEvent = TypedEvent<
  [BigNumber, BigNumber, BigNumber, BigNumber[], BigNumber[]],
  BatchLiquidationsEventObject
>;

export type BatchLiquidationsEventFilter =
  TypedEventFilter<BatchLiquidationsEvent>;

export interface LiquidationEventObject {
  tokenId: BigNumber;
  collateral: BigNumber;
  liquidity: BigNumber;
  writeDownAmt: BigNumber;
  fee: BigNumber;
  txType: number;
}
export type LiquidationEvent = TypedEvent<
  [BigNumber, BigNumber, BigNumber, BigNumber, BigNumber, number],
  LiquidationEventObject
>;

export type LiquidationEventFilter = TypedEventFilter<LiquidationEvent>;

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

export interface RefundEventObject {
  tokensHeld: BigNumber[];
  tokenIds: BigNumber[];
}
export type RefundEvent = TypedEvent<
  [BigNumber[], BigNumber[]],
  RefundEventObject
>;

export type RefundEventFilter = TypedEventFilter<RefundEvent>;

export interface RefundLiquidatorEventObject {
  tokensHeld: BigNumber[];
  refund: BigNumber[];
}
export type RefundLiquidatorEvent = TypedEvent<
  [BigNumber[], BigNumber[]],
  RefundLiquidatorEventObject
>;

export type RefundLiquidatorEventFilter =
  TypedEventFilter<RefundLiquidatorEvent>;

export interface RefundOverPaymentEventObject {
  loanLiquidity: BigNumber;
  lpDeposit: BigNumber;
}
export type RefundOverPaymentEvent = TypedEvent<
  [BigNumber, BigNumber],
  RefundOverPaymentEventObject
>;

export type RefundOverPaymentEventFilter =
  TypedEventFilter<RefundOverPaymentEvent>;

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

export interface WriteDown2EventObject {
  writeDownAmt: BigNumber;
  loanLiquidity: BigNumber;
}
export type WriteDown2Event = TypedEvent<
  [BigNumber, BigNumber],
  WriteDown2EventObject
>;

export type WriteDown2EventFilter = TypedEventFilter<WriteDown2Event>;

export interface TestLiquidationStrategy extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: TestLiquidationStrategyInterface;

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
    _batchLiquidations(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    _liquidate(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    _liquidateWithLP(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    canLiquidate(
      liquidity: PromiseOrValue<BigNumberish>,
      collateral: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    createLoan(
      lpTokens: PromiseOrValue<BigNumberish>,
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

    getPoolBalances(
      overrides?: CallOverrides
    ): Promise<
      [
        TestLiquidationStrategy.PoolBalancesStructOutput,
        BigNumber[],
        BigNumber
      ] & {
        bal: TestLiquidationStrategy.PoolBalancesStructOutput;
        tokenBalances: BigNumber[];
        accFeeIndex: BigNumber;
      }
    >;

    getStaticParams(
      overrides?: CallOverrides
    ): Promise<
      [string, string, string[], BigNumber[]] & {
        factory: string;
        cfmm: string;
        tokens: string[];
        tokenBalances: BigNumber[];
      }
    >;

    incBorrowedInvariant(
      invariant: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    initialize(
      _factory: PromiseOrValue<string>,
      cfmm: PromiseOrValue<string>,
      tokens: PromiseOrValue<string>[],
      decimals: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    liquidationFee(overrides?: CallOverrides): Promise<[BigNumber]>;

    ltvThreshold(overrides?: CallOverrides): Promise<[BigNumber]>;

    rateParamsStore(overrides?: CallOverrides): Promise<[string]>;

    testCanLiquidate(
      collateral: PromiseOrValue<BigNumberish>,
      liquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    testPayBatchLoanAndRefundLiquidator(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    testPayBatchLoans(
      liquidity: PromiseOrValue<BigNumberish>,
      lpTokenPrincipal: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    testRefundLiquidator(
      tokenId: PromiseOrValue<BigNumberish>,
      payLiquidity: PromiseOrValue<BigNumberish>,
      loanLiquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    testRefundOverPayment(
      loanLiquidity: PromiseOrValue<BigNumberish>,
      lpDeposit: PromiseOrValue<BigNumberish>,
      fullPayment: PromiseOrValue<boolean>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    testSumLiquidity(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    testUpdateLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    testWriteDown(
      payableLiquidity: PromiseOrValue<BigNumberish>,
      loanLiquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    updatePoolBalances(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<[boolean]>;
  };

  _batchLiquidations(
    tokenIds: PromiseOrValue<BigNumberish>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  _liquidate(
    tokenId: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  _liquidateWithLP(
    tokenId: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  canLiquidate(
    liquidity: PromiseOrValue<BigNumberish>,
    collateral: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  createLoan(
    lpTokens: PromiseOrValue<BigNumberish>,
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

  getPoolBalances(
    overrides?: CallOverrides
  ): Promise<
    [
      TestLiquidationStrategy.PoolBalancesStructOutput,
      BigNumber[],
      BigNumber
    ] & {
      bal: TestLiquidationStrategy.PoolBalancesStructOutput;
      tokenBalances: BigNumber[];
      accFeeIndex: BigNumber;
    }
  >;

  getStaticParams(
    overrides?: CallOverrides
  ): Promise<
    [string, string, string[], BigNumber[]] & {
      factory: string;
      cfmm: string;
      tokens: string[];
      tokenBalances: BigNumber[];
    }
  >;

  incBorrowedInvariant(
    invariant: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  initialize(
    _factory: PromiseOrValue<string>,
    cfmm: PromiseOrValue<string>,
    tokens: PromiseOrValue<string>[],
    decimals: PromiseOrValue<BigNumberish>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  liquidationFee(overrides?: CallOverrides): Promise<BigNumber>;

  ltvThreshold(overrides?: CallOverrides): Promise<BigNumber>;

  rateParamsStore(overrides?: CallOverrides): Promise<string>;

  testCanLiquidate(
    collateral: PromiseOrValue<BigNumberish>,
    liquidity: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  testPayBatchLoanAndRefundLiquidator(
    tokenIds: PromiseOrValue<BigNumberish>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  testPayBatchLoans(
    liquidity: PromiseOrValue<BigNumberish>,
    lpTokenPrincipal: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  testRefundLiquidator(
    tokenId: PromiseOrValue<BigNumberish>,
    payLiquidity: PromiseOrValue<BigNumberish>,
    loanLiquidity: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  testRefundOverPayment(
    loanLiquidity: PromiseOrValue<BigNumberish>,
    lpDeposit: PromiseOrValue<BigNumberish>,
    fullPayment: PromiseOrValue<boolean>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  testSumLiquidity(
    tokenIds: PromiseOrValue<BigNumberish>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  testUpdateLoan(
    tokenId: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  testWriteDown(
    payableLiquidity: PromiseOrValue<BigNumberish>,
    loanLiquidity: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  updatePoolBalances(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  validateParameters(
    _data: PromiseOrValue<BytesLike>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  callStatic: {
    _batchLiquidations(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber[]] & {
        totalLoanLiquidity: BigNumber;
        refund: BigNumber[];
      }
    >;

    _liquidate(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber] & { loanLiquidity: BigNumber; refund: BigNumber }
    >;

    _liquidateWithLP(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber[]] & {
        loanLiquidity: BigNumber;
        refund: BigNumber[];
      }
    >;

    canLiquidate(
      liquidity: PromiseOrValue<BigNumberish>,
      collateral: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    createLoan(
      lpTokens: PromiseOrValue<BigNumberish>,
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

    getPoolBalances(
      overrides?: CallOverrides
    ): Promise<
      [
        TestLiquidationStrategy.PoolBalancesStructOutput,
        BigNumber[],
        BigNumber
      ] & {
        bal: TestLiquidationStrategy.PoolBalancesStructOutput;
        tokenBalances: BigNumber[];
        accFeeIndex: BigNumber;
      }
    >;

    getStaticParams(
      overrides?: CallOverrides
    ): Promise<
      [string, string, string[], BigNumber[]] & {
        factory: string;
        cfmm: string;
        tokens: string[];
        tokenBalances: BigNumber[];
      }
    >;

    incBorrowedInvariant(
      invariant: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    initialize(
      _factory: PromiseOrValue<string>,
      cfmm: PromiseOrValue<string>,
      tokens: PromiseOrValue<string>[],
      decimals: PromiseOrValue<BigNumberish>[],
      overrides?: CallOverrides
    ): Promise<void>;

    liquidationFee(overrides?: CallOverrides): Promise<BigNumber>;

    ltvThreshold(overrides?: CallOverrides): Promise<BigNumber>;

    rateParamsStore(overrides?: CallOverrides): Promise<string>;

    testCanLiquidate(
      collateral: PromiseOrValue<BigNumberish>,
      liquidity: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    testPayBatchLoanAndRefundLiquidator(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: CallOverrides
    ): Promise<void>;

    testPayBatchLoans(
      liquidity: PromiseOrValue<BigNumberish>,
      lpTokenPrincipal: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    testRefundLiquidator(
      tokenId: PromiseOrValue<BigNumberish>,
      payLiquidity: PromiseOrValue<BigNumberish>,
      loanLiquidity: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    testRefundOverPayment(
      loanLiquidity: PromiseOrValue<BigNumberish>,
      lpDeposit: PromiseOrValue<BigNumberish>,
      fullPayment: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<void>;

    testSumLiquidity(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: CallOverrides
    ): Promise<void>;

    testUpdateLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    testWriteDown(
      payableLiquidity: PromiseOrValue<BigNumberish>,
      loanLiquidity: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    updatePoolBalances(overrides?: CallOverrides): Promise<void>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<boolean>;
  };

  filters: {
    "BatchLiquidations(uint256,uint256,uint256,uint128[],uint256[])"(
      liquidityTotal?: null,
      collateralTotal?: null,
      lpTokensPrincipalTotal?: null,
      tokensHeldTotal?: null,
      tokenIds?: null
    ): BatchLiquidationsEventFilter;
    BatchLiquidations(
      liquidityTotal?: null,
      collateralTotal?: null,
      lpTokensPrincipalTotal?: null,
      tokensHeldTotal?: null,
      tokenIds?: null
    ): BatchLiquidationsEventFilter;

    "Liquidation(uint256,uint128,uint128,uint128,uint128,uint8)"(
      tokenId?: PromiseOrValue<BigNumberish> | null,
      collateral?: null,
      liquidity?: null,
      writeDownAmt?: null,
      fee?: null,
      txType?: null
    ): LiquidationEventFilter;
    Liquidation(
      tokenId?: PromiseOrValue<BigNumberish> | null,
      collateral?: null,
      liquidity?: null,
      writeDownAmt?: null,
      fee?: null,
      txType?: null
    ): LiquidationEventFilter;

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

    "Refund(uint128[],uint256[])"(
      tokensHeld?: null,
      tokenIds?: null
    ): RefundEventFilter;
    Refund(tokensHeld?: null, tokenIds?: null): RefundEventFilter;

    "RefundLiquidator(uint128[],uint128[])"(
      tokensHeld?: null,
      refund?: null
    ): RefundLiquidatorEventFilter;
    RefundLiquidator(
      tokensHeld?: null,
      refund?: null
    ): RefundLiquidatorEventFilter;

    "RefundOverPayment(uint256,uint256)"(
      loanLiquidity?: null,
      lpDeposit?: null
    ): RefundOverPaymentEventFilter;
    RefundOverPayment(
      loanLiquidity?: null,
      lpDeposit?: null
    ): RefundOverPaymentEventFilter;

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

    "WriteDown2(uint256,uint256)"(
      writeDownAmt?: null,
      loanLiquidity?: null
    ): WriteDown2EventFilter;
    WriteDown2(
      writeDownAmt?: null,
      loanLiquidity?: null
    ): WriteDown2EventFilter;
  };

  estimateGas: {
    _batchLiquidations(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    _liquidate(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    _liquidateWithLP(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    canLiquidate(
      liquidity: PromiseOrValue<BigNumberish>,
      collateral: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    createLoan(
      lpTokens: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    getLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getPoolBalances(overrides?: CallOverrides): Promise<BigNumber>;

    getStaticParams(overrides?: CallOverrides): Promise<BigNumber>;

    incBorrowedInvariant(
      invariant: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    initialize(
      _factory: PromiseOrValue<string>,
      cfmm: PromiseOrValue<string>,
      tokens: PromiseOrValue<string>[],
      decimals: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    liquidationFee(overrides?: CallOverrides): Promise<BigNumber>;

    ltvThreshold(overrides?: CallOverrides): Promise<BigNumber>;

    rateParamsStore(overrides?: CallOverrides): Promise<BigNumber>;

    testCanLiquidate(
      collateral: PromiseOrValue<BigNumberish>,
      liquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    testPayBatchLoanAndRefundLiquidator(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    testPayBatchLoans(
      liquidity: PromiseOrValue<BigNumberish>,
      lpTokenPrincipal: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    testRefundLiquidator(
      tokenId: PromiseOrValue<BigNumberish>,
      payLiquidity: PromiseOrValue<BigNumberish>,
      loanLiquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    testRefundOverPayment(
      loanLiquidity: PromiseOrValue<BigNumberish>,
      lpDeposit: PromiseOrValue<BigNumberish>,
      fullPayment: PromiseOrValue<boolean>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    testSumLiquidity(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    testUpdateLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    testWriteDown(
      payableLiquidity: PromiseOrValue<BigNumberish>,
      loanLiquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    updatePoolBalances(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    _batchLiquidations(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    _liquidate(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    _liquidateWithLP(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    canLiquidate(
      liquidity: PromiseOrValue<BigNumberish>,
      collateral: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    createLoan(
      lpTokens: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    getLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getPoolBalances(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    getStaticParams(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    incBorrowedInvariant(
      invariant: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    initialize(
      _factory: PromiseOrValue<string>,
      cfmm: PromiseOrValue<string>,
      tokens: PromiseOrValue<string>[],
      decimals: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    liquidationFee(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    ltvThreshold(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    rateParamsStore(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    testCanLiquidate(
      collateral: PromiseOrValue<BigNumberish>,
      liquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    testPayBatchLoanAndRefundLiquidator(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    testPayBatchLoans(
      liquidity: PromiseOrValue<BigNumberish>,
      lpTokenPrincipal: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    testRefundLiquidator(
      tokenId: PromiseOrValue<BigNumberish>,
      payLiquidity: PromiseOrValue<BigNumberish>,
      loanLiquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    testRefundOverPayment(
      loanLiquidity: PromiseOrValue<BigNumberish>,
      lpDeposit: PromiseOrValue<BigNumberish>,
      fullPayment: PromiseOrValue<boolean>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    testSumLiquidity(
      tokenIds: PromiseOrValue<BigNumberish>[],
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    testUpdateLoan(
      tokenId: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    testWriteDown(
      payableLiquidity: PromiseOrValue<BigNumberish>,
      loanLiquidity: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    updatePoolBalances(
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    validateParameters(
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}
