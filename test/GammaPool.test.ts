import { ethers } from "hardhat";
import { expect } from "chai";

const PROTOCOL_ID = 1;

describe.skip("GammaPool", function () {
  let TestERC20: any;
  let TestAddressCalculator: any;
  let TestBorrowStrategy: any;
  let TestRepayStrategy: any;
  let TestRebalanceStrategy: any;
  let TestShortStrategy: any;
  let TestLiquidationStrategy: any;
  let GammaPool: any;
  let TestGammaPoolFactory: any;
  let factory: any;
  let addressCalculator: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let cfmm: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let borrowStrategy: any;
  let repayStrategy: any;
  let rebalanceStrategy: any;
  let shortStrategy: any;
  let liquidationStrategy: any;
  let batchLiquidationStrategy: any;
  let gammaPool: any;
  let implementation: any;
  let tokens: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestAddressCalculator = await ethers.getContractFactory(
      "TestAddressCalculator"
    );

    TestGammaPoolFactory = await ethers.getContractFactory(
      "TestGammaPoolFactory"
    );

    TestBorrowStrategy = await ethers.getContractFactory("TestBorrowStrategy2");
    TestRepayStrategy = await ethers.getContractFactory("TestRepayStrategy2");
    TestRebalanceStrategy = await ethers.getContractFactory(
      "TestRebalanceStrategy2"
    );
    TestShortStrategy = await ethers.getContractFactory("TestShortStrategy2");
    TestLiquidationStrategy = await ethers.getContractFactory(
      "TestLiquidationStrategy2"
    );

    GammaPool = await ethers.getContractFactory("TestGammaPool");
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");
    cfmm = await TestERC20.deploy("Test CFMM", "CFMM");
    borrowStrategy = await TestBorrowStrategy.deploy();
    repayStrategy = await TestRepayStrategy.deploy();
    rebalanceStrategy = await TestRebalanceStrategy.deploy();
    shortStrategy = await TestShortStrategy.deploy();
    liquidationStrategy = await TestLiquidationStrategy.deploy();
    batchLiquidationStrategy = await TestLiquidationStrategy.deploy();
    addressCalculator = await TestAddressCalculator.deploy();

    tokens = [tokenA.address, tokenB.address];

    factory = await TestGammaPoolFactory.deploy(
      cfmm.address,
      PROTOCOL_ID,
      tokens
    );

    implementation = await GammaPool.deploy(
      PROTOCOL_ID,
      factory.address,
      borrowStrategy.address,
      repayStrategy.address,
      rebalanceStrategy.address,
      shortStrategy.address,
      liquidationStrategy.address,
      batchLiquidationStrategy.address
    );

    await (await factory.addProtocol(implementation.address)).wait();

    await deployGammaPool();
  });

  async function deployGammaPool() {
    const data = ethers.utils.defaultAbiCoder.encode([], []);
    await (await factory.createPool2(data)).wait();
    const key = await addressCalculator.getGammaPoolKey(
      cfmm.address,
      PROTOCOL_ID
    );
    const pool = await factory.getPool(key);

    gammaPool = await GammaPool.attach(
      pool // The deployed contract address
    );
  }

  async function checkBalances(
    actBalA: number,
    actBalB: number,
    actBalC: number,
    actCfmmBal: number,
    balA: number,
    balB: number,
    cfmmBal: number
  ) {
    expect(await tokenA.balanceOf(gammaPool.address)).to.eq(actBalA);
    expect(await tokenB.balanceOf(gammaPool.address)).to.eq(actBalB);
    expect(await tokenC.balanceOf(gammaPool.address)).to.eq(actBalC);
    expect(await cfmm.balanceOf(gammaPool.address)).to.eq(actCfmmBal);

    const res0 = await gammaPool.getPoolBalances();
    expect(res0.tokenBalances.length).to.eq(2);
    expect(res0.tokenBalances[0]).to.eq(balA);
    expect(res0.tokenBalances[1]).to.eq(balB);
    expect(res0.lpTokenBalance).to.eq(cfmmBal);
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    // `it` is another Mocha function. This is the one you use to define your
    // tests. It receives the test name, and a callback function.

    it("Check Init Params", async function () {
      expect(await gammaPool.cfmm()).to.equal(cfmm.address);
      expect(await gammaPool.protocolId()).to.equal(PROTOCOL_ID);

      const tokens = await gammaPool.tokens();
      expect(tokens.length).to.equal(2);
      expect(tokens[0]).to.equal(tokenA.address);
      expect(tokens[1]).to.equal(tokenB.address);

      expect(await gammaPool.factory()).to.equal(factory.address);
      expect(await gammaPool.borrowStrategy()).to.equal(borrowStrategy.address);
      expect(await gammaPool.repayStrategy()).to.equal(repayStrategy.address);
      expect(await gammaPool.rebalanceStrategy()).to.equal(
        rebalanceStrategy.address
      );
      expect(await gammaPool.shortStrategy()).to.equal(shortStrategy.address);
      expect(await gammaPool.singleLiquidationStrategy()).to.equal(
        liquidationStrategy.address
      );
      expect(await gammaPool.batchLiquidationStrategy()).to.equal(
        batchLiquidationStrategy.address
      );

      const res = await gammaPool.getPoolBalances();
      const tokenBalances = res.tokenBalances;
      expect(tokenBalances.length).to.equal(2);
      expect(tokenBalances[0]).to.equal(0);
      expect(tokenBalances[1]).to.equal(0);

      expect(res.lpTokenBalance).to.equal(0);
      expect(res.lpTokenBorrowed).to.equal(0);
      expect(res.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(res.borrowedInvariant).to.equal(0);
      expect(res.lpInvariant).to.equal(0);

      const res1 = await gammaPool.getCFMMBalances();
      const cfmmReserves = res1.cfmmReserves;
      expect(cfmmReserves.length).to.equal(2);
      expect(cfmmReserves[0]).to.equal(0);
      expect(cfmmReserves[1]).to.equal(0);
      expect(res1.cfmmInvariant).to.equal(0);
      expect(res1.cfmmTotalSupply).to.equal(0);

      const res2 = await gammaPool.getRates();
      const ONE = ethers.BigNumber.from(10).pow(18);
      expect(res2.accFeeIndex).to.equal(ONE);
      expect(res2.lastCFMMFeeIndex).to.equal(ONE);
      expect(res2.lastBlockNumber).to.gt(0);

      const res3 = await gammaPool.getPoolData();
      expect(res3.cfmm).to.equal(cfmm.address);
      expect(res3.protocolId).to.equal(PROTOCOL_ID);
      expect(res3.ltvThreshold).to.equal(await borrowStrategy.ltvThreshold());
      expect(res3.liquidationFee).to.equal(
        await liquidationStrategy.liquidationFee()
      );
      const _tokens = res3.tokens;
      expect(_tokens.length).to.equal(2);
      expect(_tokens[0]).to.equal(tokenA.address);
      expect(_tokens[1]).to.equal(tokenB.address);
      const _decimals = res3.decimals;
      expect(_decimals.length).to.equal(2);
      expect(_decimals[0]).to.equal(await tokenA.decimals());
      expect(_decimals[1]).to.equal(await tokenB.decimals());

      expect(res3.factory).to.equal(factory.address);
      expect(res3.borrowStrategy).to.equal(borrowStrategy.address);
      expect(res3.repayStrategy).to.equal(repayStrategy.address);
      expect(res3.rebalanceStrategy).to.equal(rebalanceStrategy.address);
      expect(res3.shortStrategy).to.equal(shortStrategy.address);
      expect(res3.singleLiquidationStrategy).to.equal(
        liquidationStrategy.address
      );
      expect(res3.batchLiquidationStrategy).to.equal(
        batchLiquidationStrategy.address
      );
      const _tokenBalances = res3.TOKEN_BALANCE;
      expect(_tokenBalances.length).to.equal(2);
      expect(_tokenBalances[0]).to.equal(0);
      expect(_tokenBalances[1]).to.equal(0);

      expect(res3.accFeeIndex).to.equal(ONE);
      expect(res3.LAST_BLOCK_NUMBER).to.gt(0);
      expect(res3.LP_TOKEN_BALANCE).to.equal(0);
      expect(res3.LP_TOKEN_BORROWED).to.equal(0);
      expect(res3.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(0);
      expect(res3.BORROWED_INVARIANT).to.equal(0);
      expect(res3.LP_INVARIANT).to.equal(0);

      const _cfmmReserves = res3.CFMM_RESERVES;
      expect(_cfmmReserves.length).to.equal(2);
      expect(_cfmmReserves[0]).to.equal(0);
      expect(_cfmmReserves[1]).to.equal(0);
      expect(res3.lastCFMMFeeIndex).to.equal(res2.lastCFMMFeeIndex);
      expect(res3.lastCFMMInvariant).to.equal(res1.cfmmInvariant);
      expect(res3.lastCFMMTotalSupply).to.equal(res1.cfmmTotalSupply);
      expect(res3.totalSupply).to.equal(await gammaPool.totalSupply());
      expect(res3.lastPrice).to.equal(0);
      expect(res3.lastCFMMFeeIndex).to.equal(ONE);
      expect(res3.lastFeeIndex).to.equal(0);
      expect(res3.borrowRate).to.equal(0);

      const latestBlock = await ethers.provider.getBlock("latest");
      const res4 = await gammaPool.getConstantPoolData();
      expect(res4.currBlockNumber).to.equal(latestBlock.number);
      expect(res4.cfmm).to.equal(cfmm.address);
      expect(res4.protocolId).to.equal(PROTOCOL_ID);
      expect(res4.ltvThreshold).to.equal(res3.ltvThreshold);
      expect(res4.liquidationFee).to.equal(res3.liquidationFee);
      const _toks = res4.tokens;
      expect(_toks.length).to.equal(2);
      expect(_toks[0]).to.equal(tokenA.address);
      expect(_toks[1]).to.equal(tokenB.address);
      const _decs = res4.decimals;
      expect(_decs.length).to.equal(2);
      expect(_decs[0]).to.equal(await tokenA.decimals());
      expect(_decs[1]).to.equal(await tokenB.decimals());

      expect(res4.factory).to.equal(factory.address);
      expect(res4.borrowStrategy).to.equal(borrowStrategy.address);
      expect(res4.repayStrategy).to.equal(repayStrategy.address);
      expect(res4.rebalanceStrategy).to.equal(rebalanceStrategy.address);
      expect(res4.shortStrategy).to.equal(shortStrategy.address);
      expect(res4.singleLiquidationStrategy).to.equal(
        liquidationStrategy.address
      );
      expect(res4.batchLiquidationStrategy).to.equal(
        batchLiquidationStrategy.address
      );
      const _tokBalances = res4.TOKEN_BALANCE;
      expect(_tokBalances.length).to.equal(2);
      expect(_tokBalances[0]).to.equal(0);
      expect(_tokBalances[1]).to.equal(0);

      expect(res4.accFeeIndex).to.equal(0);
      expect(res4.LAST_BLOCK_NUMBER).to.gt(0);
      expect(res4.LP_TOKEN_BALANCE).to.equal(0);
      expect(res4.LP_TOKEN_BORROWED).to.equal(0);
      expect(res4.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(0);
      expect(res4.BORROWED_INVARIANT).to.equal(0);
      expect(res4.LP_INVARIANT).to.equal(0);

      const _cfmmReserv = res4.CFMM_RESERVES;
      expect(_cfmmReserv.length).to.equal(0);
      expect(res4.lastCFMMFeeIndex).to.equal(0);
      expect(res4.lastCFMMInvariant).to.equal(0);
      expect(res4.lastCFMMTotalSupply).to.equal(0);
      expect(res4.totalSupply).to.equal(await gammaPool.totalSupply());
      expect(res4.lastPrice).to.equal(0);
      expect(res4.lastCFMMFeeIndex).to.equal(0);
      expect(res4.lastFeeIndex).to.equal(0);
      expect(res4.borrowRate).to.equal(0);

      await (await cfmm.mint(addr1.address, ONE.mul(100))).wait();

      const res5 = await gammaPool.getLatestPoolData();
      expect(res5.utilizationRate).to.equal(44);
      expect(res5.cfmm).to.equal(cfmm.address);
      expect(res5.protocolId).to.equal(PROTOCOL_ID);
      expect(res5.ltvThreshold).to.equal(res3.ltvThreshold);
      expect(res5.liquidationFee).to.equal(res3.liquidationFee);
      const _tokss = res5.tokens;
      expect(_tokss.length).to.equal(2);
      expect(_tokss[0]).to.equal(tokenA.address);
      expect(_tokss[1]).to.equal(tokenB.address);
      const _decss = res5.decimals;
      expect(_decss.length).to.equal(2);
      expect(_decss[0]).to.equal(await tokenA.decimals());
      expect(_decss[1]).to.equal(await tokenB.decimals());

      expect(res5.factory).to.equal(factory.address);
      expect(res5.borrowStrategy).to.equal(borrowStrategy.address);
      expect(res5.repayStrategy).to.equal(repayStrategy.address);
      expect(res5.rebalanceStrategy).to.equal(rebalanceStrategy.address);
      expect(res5.shortStrategy).to.equal(shortStrategy.address);
      expect(res5.singleLiquidationStrategy).to.equal(
        liquidationStrategy.address
      );
      expect(res5.batchLiquidationStrategy).to.equal(
        batchLiquidationStrategy.address
      );
      const _toksBalances = res5.TOKEN_BALANCE;
      expect(_toksBalances.length).to.equal(2);
      expect(_toksBalances[0]).to.equal(0);
      expect(_toksBalances[1]).to.equal(0);
      expect(res5.lastCFMMTotalSupply).to.equal(await cfmm.totalSupply());
      expect(res5.lastCFMMInvariant).to.equal(100);
      expect(res5.lastPrice).to.equal(1);

      const _cfmmReser = res5.CFMM_RESERVES;
      expect(_cfmmReser.length).to.equal(2);
      expect(_cfmmReser[0]).to.equal(1);
      expect(_cfmmReser[1]).to.equal(2);

      expect(res5.lastCFMMFeeIndex).to.equal(1);
      expect(res5.lastFeeIndex).to.equal(2);
      expect(res5.borrowRate).to.equal(3);
      expect(res5.supplyRate).to.equal(0);

      expect(res5.LP_TOKEN_BALANCE).to.equal(0);
      expect(res5.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(5);
      expect(res5.BORROWED_INVARIANT).to.equal(6);

      const res6 = await gammaPool.getLatestRates();
      expect(res6.lastPrice).to.equal(res5.lastPrice);
      expect(res6.utilizationRate).to.equal(res5.utilizationRate);
      expect(res6.accFeeIndex).to.eq(res5.accFeeIndex);
      expect(res6.lastCFMMFeeIndex).to.eq(res5.lastCFMMFeeIndex);
      expect(res6.lastFeeIndex).to.eq(res5.lastFeeIndex);
      expect(res6.borrowRate).to.eq(res5.borrowRate);
      expect(res6.supplyRate).to.equal(res5.supplyRate);
      expect(res6.lastBlockNumber).to.eq(res5.LAST_BLOCK_NUMBER);
    });

    it("Custom Fields Set & Get", async function () {
      await (await gammaPool.setUint256(1, 253146)).wait();
      expect(await gammaPool.getUint256(1)).to.equal(253146);

      await (await gammaPool.setUint256(1, 253147)).wait();
      expect(await gammaPool.getUint256(1)).to.not.equal(253146);
      expect(await gammaPool.getUint256(1)).to.equal(253147);

      expect(await gammaPool.getUint256(2)).to.equal(0);
      await (await gammaPool.setUint256(2, 253246)).wait();
      expect(await gammaPool.getUint256(2)).to.equal(253246);
      await (await gammaPool.setUint256(2, 0)).wait();
      expect(await gammaPool.getUint256(1)).to.not.equal(253146);
      expect(await gammaPool.getUint256(2)).to.equal(0);

      await (await gammaPool.setInt256(1, -253146)).wait();
      expect(await gammaPool.getInt256(1)).to.equal(-253146);

      await (await gammaPool.setInt256(1, 253147)).wait();
      expect(await gammaPool.getInt256(1)).to.not.equal(253146);
      expect(await gammaPool.getInt256(1)).to.equal(253147);

      expect(await gammaPool.getInt256(2)).to.equal(0);
      await (await gammaPool.setInt256(2, -253246)).wait();
      expect(await gammaPool.getInt256(2)).to.equal(-253246);
      await (await gammaPool.setInt256(2, 0)).wait();
      expect(await gammaPool.getInt256(1)).to.not.equal(253146);
      expect(await gammaPool.getInt256(2)).to.equal(0);

      const abi = ethers.utils.defaultAbiCoder;
      const data0 = abi.encode(
        ["address"], // encode as address array
        [addr3.address]
      );
      await (await gammaPool.setBytes32(1, data0)).wait();
      expect(await gammaPool.getBytes32(1)).to.equal(data0);

      const data1 = abi.encode(
        ["uint8"], // encode as address array
        [123]
      );
      await (await gammaPool.setBytes32(1, data1)).wait();
      expect(await gammaPool.getBytes32(1)).to.not.equal(data0);
      expect(await gammaPool.getBytes32(1)).to.equal(data1);

      const data2 = abi.encode(
        ["int16"], // encode as address array
        [122]
      );
      const empty =
        "0x0000000000000000000000000000000000000000000000000000000000000000";
      expect(await gammaPool.getBytes32(2)).to.equal(empty);
      await (await gammaPool.setBytes32(2, data2)).wait();
      expect(await gammaPool.getBytes32(2)).to.equal(data2);
      await (await gammaPool.setBytes32(2, empty)).wait();
      expect(await gammaPool.getBytes32(1)).to.not.equal(data2);
      expect(await gammaPool.getBytes32(2)).to.equal(empty);

      await (await gammaPool.setAddress(1, addr1.address)).wait();
      expect(await gammaPool.getAddress(1)).to.equal(addr1.address);

      await (await gammaPool.setAddress(1, addr2.address)).wait();
      expect(await gammaPool.getAddress(1)).to.not.equal(addr1.address);
      expect(await gammaPool.getAddress(1)).to.equal(addr2.address);

      expect(await gammaPool.getAddress(2)).to.equal(
        ethers.constants.AddressZero
      );
      await (await gammaPool.setAddress(2, addr3.address)).wait();
      expect(await gammaPool.getAddress(2)).to.equal(addr3.address);
      await (
        await gammaPool.setAddress(2, ethers.constants.AddressZero)
      ).wait();
      expect(await gammaPool.getAddress(1)).to.not.equal(addr1.address);
      expect(await gammaPool.getAddress(2)).to.equal(
        ethers.constants.AddressZero
      );
    });

    it("Custom Struct Set & Get", async function () {
      const _obj = await gammaPool.getObj();
      expect(_obj.protocolId).to.equal(0);
      expect(_obj.cfmm).to.equal(ethers.constants.AddressZero);
      const params = {
        protocolId: 1,
        cfmm: addr3.address,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        ["tuple(uint16 protocolId, address cfmm)"],
        [params]
      );
      await (await gammaPool.setObjData(data)).wait();
      const _obj1 = await gammaPool.getObj();
      expect(_obj1.protocolId).to.equal(1);
      expect(_obj1.cfmm).to.equal(addr3.address);

      await (await gammaPool.setObj(2, addr2.address)).wait();
      const _obj2 = await gammaPool.getObj();
      expect(_obj2.protocolId).to.equal(2);
      expect(_obj2.cfmm).to.equal(addr2.address);

      await (await gammaPool.setObj(0, ethers.constants.AddressZero)).wait();
      const _obj3 = await gammaPool.getObj();
      expect(_obj3.protocolId).to.equal(0);
      expect(_obj3.cfmm).to.equal(ethers.constants.AddressZero);

      await (await gammaPool.setObj(4, addr1.address)).wait();
      const _obj4 = await gammaPool.getObj();
      expect(_obj4.protocolId).to.equal(4);
      expect(_obj4.cfmm).to.equal(addr1.address);

      const empty = ethers.utils.defaultAbiCoder.encode([], []);
      await (await gammaPool.setObjData(empty)).wait();
      const _obj5 = await gammaPool.getObj();
      expect(_obj5.protocolId).to.equal(0);
      expect(_obj5.cfmm).to.equal(ethers.constants.AddressZero);
    });
  });

  // You can nest describe calls to create subsections.
  describe("Short Gamma", function () {
    it("Get Latest CFMM Reserves", async function () {
      const cfmmReserves = await gammaPool.getLatestCFMMReserves();
      expect(cfmmReserves.length).to.eq(2);
      expect(cfmmReserves[0]).to.eq(1);
      expect(cfmmReserves[1]).to.eq(2);
    });

    it("Deposit & Withdraw Liquidity", async function () {
      const res0 = await (await gammaPool.depositNoPull(addr1.address)).wait();
      expect(res0.events[0].args.caller).to.eq(owner.address);
      expect(res0.events[0].args.to).to.eq(addr1.address);
      expect(res0.events[0].args.assets).to.eq(3);
      expect(res0.events[0].args.shares).to.eq(2);

      const abi = ethers.utils.defaultAbiCoder;
      const data = abi.encode(
        ["address"], // encode as address array
        [addr3.address]
      );
      const res1 = await (
        await gammaPool.depositReserves(addr2.address, [2, 20], [1, 10], data)
      ).wait();
      expect(res1.events[0].args.caller).to.eq(addr3.address);
      expect(res1.events[0].args.to).to.eq(addr2.address);
      expect(res1.events[0].args.assets).to.eq(11);
      expect(res1.events[0].args.shares).to.eq(22);

      const res2 = await (await gammaPool.withdrawNoPull(addr3.address)).wait();
      expect(res2.events[0].args.caller).to.eq(owner.address);
      expect(res2.events[0].args.to).to.eq(addr3.address);
      expect(res2.events[0].args.from).to.eq(owner.address);
      expect(res2.events[0].args.assets).to.eq(7);
      expect(res2.events[0].args.shares).to.eq(14);

      const res3 = await (
        await gammaPool.withdrawReserves(addr1.address)
      ).wait();
      expect(res3.events[0].args.caller).to.eq(owner.address);
      expect(res3.events[0].args.to).to.eq(addr1.address);
      expect(res3.events[0].args.from).to.eq(owner.address);
      expect(res3.events[0].args.assets).to.eq(5);
      expect(res3.events[0].args.shares).to.eq(9);
    });
  });

  // You can nest describe calls to create subsections.
  describe("Long Gamma", function () {
    it("Create & View Loan", async function () {
      const res = await (await gammaPool.createLoan()).wait();
      expect(res.events[0].args.caller).to.eq(owner.address);
      const abi = ethers.utils.defaultAbiCoder;
      const data = abi.encode(
        ["address", "address", "uint256"], // encode as address array
        [owner.address, gammaPool.address, 1]
      );
      const tokenId = ethers.BigNumber.from(ethers.utils.keccak256(data));
      expect(res.events[0].args.tokenId).to.eq(tokenId);

      const loan = await gammaPool.loan(tokenId);
      expect(loan.id).to.eq(1);
      expect(loan.poolId).to.eq(gammaPool.address);
      expect(loan.tokensHeld.length).to.eq(tokens.length);
      expect(loan.tokensHeld[0]).to.eq(0);
      expect(loan.tokensHeld[1]).to.eq(0);
      expect(loan.initLiquidity).to.eq(0);
      expect(loan.liquidity).to.eq(0);
      expect(loan.rateIndex).to.eq(ethers.BigNumber.from(10).pow(18));
      expect(await gammaPool.getLoanCount()).to.equal(1);
    });

    it("Increase Loan Count", async function () {
      await (await gammaPool.createLoan()).wait();
      await (await gammaPool.createLoan()).wait();
      await (await gammaPool.createLoan()).wait();
      await (await gammaPool.createLoan()).wait();
      await (await gammaPool.createLoan()).wait();
      expect(await gammaPool.getLoanCount()).to.equal(5);
      await (await gammaPool.createLoan()).wait();
      await (await gammaPool.createLoan()).wait();
      await (await gammaPool.createLoan()).wait();
      expect(await gammaPool.getLoanCount()).to.equal(8);
      await (await gammaPool.connect(addr1).createLoan()).wait();
      await (await gammaPool.connect(addr1).createLoan()).wait();
      expect(await gammaPool.getLoanCount()).to.equal(10);
    });

    function checkLoan(loan: any, id: number, tokenId: any) {
      expect(loan.id).to.eq(id);
      expect(loan.tokenId).to.eq(tokenId);
      expect(loan.poolId).to.eq(gammaPool.address);
      expect(loan.rateIndex).to.eq(ethers.BigNumber.from(10).pow(18));
      expect(loan.initLiquidity).to.eq(0);
      expect(loan.liquidity).to.eq(0);
      expect(loan.lpTokens).to.eq(0);
      expect(loan.px).to.eq(0);
    }

    it("Get List of Loans", async function () {
      const res0 = await (await gammaPool.createLoan()).wait();
      const tokenId0 = res0.events[0].args.tokenId;
      const res1 = await (await gammaPool.createLoan()).wait();
      const tokenId1 = res1.events[0].args.tokenId;
      const res2 = await (await gammaPool.createLoan()).wait();
      const tokenId2 = res2.events[0].args.tokenId;
      const res3 = await (await gammaPool.createLoan()).wait();
      const tokenId3 = res3.events[0].args.tokenId;
      const res4 = await (await gammaPool.createLoan()).wait();
      const tokenId4 = res4.events[0].args.tokenId;
      const res5 = await (await gammaPool.createLoan()).wait();
      const tokenId5 = res5.events[0].args.tokenId;
      const res6 = await (await gammaPool.createLoan()).wait();
      const tokenId6 = res6.events[0].args.tokenId;
      const res7 = await (await gammaPool.createLoan()).wait();
      const tokenId7 = res7.events[0].args.tokenId;
      const res8 = await (await gammaPool.createLoan()).wait();
      const tokenId8 = res8.events[0].args.tokenId;
      const res9 = await (await gammaPool.createLoan()).wait();
      const tokenId9 = res9.events[0].args.tokenId;
      const res10 = await (await gammaPool.createLoan()).wait();
      const tokenId10 = res10.events[0].args.tokenId;

      const _loans = await gammaPool.getLoans(1, 10, false);
      expect(_loans.length).to.eq(10);
      expect(_loans[0].tokenId).to.eq(tokenId1);
      expect(_loans[3].tokenId).to.eq(tokenId4);
      expect(_loans[9].tokenId).to.eq(tokenId10);

      const _loans1 = await gammaPool.getLoans(5, 6, false);
      expect(_loans1.length).to.eq(2);
      checkLoan(_loans1[0], 6, tokenId5);
      checkLoan(_loans1[1], 7, tokenId6);

      const _loans2 = await gammaPool.getLoans(7, 7, false);
      expect(_loans2.length).to.eq(1);
      checkLoan(_loans2[0], 8, tokenId7);

      const _loans3 = await gammaPool.getLoans(7, 100, false);
      expect(_loans3.length).to.eq(4);
      checkLoan(_loans3[0], 8, tokenId7);
      checkLoan(_loans3[1], 9, tokenId8);
      checkLoan(_loans3[2], 10, tokenId9);
      checkLoan(_loans3[3], 11, tokenId10);

      const _loans4 = await gammaPool.getLoans(0, 100, false);
      expect(_loans4.length).to.eq(11);
      expect(_loans4[0].tokenId).to.eq(tokenId0);
      expect(_loans4[1].tokenId).to.eq(tokenId1);
      expect(_loans4[2].tokenId).to.eq(tokenId2);
      expect(_loans4[3].tokenId).to.eq(tokenId3);
      expect(_loans4[4].tokenId).to.eq(tokenId4);
      expect(_loans4[5].tokenId).to.eq(tokenId5);
      expect(_loans4[6].tokenId).to.eq(tokenId6);
      expect(_loans4[7].tokenId).to.eq(tokenId7);
      expect(_loans4[8].tokenId).to.eq(tokenId8);
      expect(_loans4[9].tokenId).to.eq(tokenId9);
      expect(_loans4[10].tokenId).to.eq(tokenId10);

      const _loans4a = await gammaPool.getLoans(0, 100, true);
      expect(_loans4a.length).to.eq(11);
      expect(_loans4a[0].tokenId).to.eq(0);
      expect(_loans4a[1].tokenId).to.eq(0);
      expect(_loans4a[2].tokenId).to.eq(0);
      expect(_loans4a[3].tokenId).to.eq(0);
      expect(_loans4a[4].tokenId).to.eq(0);
      expect(_loans4a[5].tokenId).to.eq(0);
      expect(_loans4a[6].tokenId).to.eq(0);
      expect(_loans4a[7].tokenId).to.eq(0);
      expect(_loans4a[8].tokenId).to.eq(0);
      expect(_loans4a[9].tokenId).to.eq(0);
      expect(_loans4a[10].tokenId).to.eq(0);

      const _loans4b = await gammaPool.getLoansById(
        [tokenId2, tokenId6, tokenId8],
        false
      );
      expect(_loans4b.length).to.eq(3);
      expect(_loans4b[0].tokenId).to.eq(tokenId2);
      expect(_loans4b[1].tokenId).to.eq(tokenId6);
      expect(_loans4b[2].tokenId).to.eq(tokenId8);

      const _loans4c = await gammaPool.getLoansById(
        [tokenId2, tokenId6, tokenId8],
        true
      );
      expect(_loans4c.length).to.eq(3);
      expect(_loans4c[0].tokenId).to.eq(0);
      expect(_loans4c[1].tokenId).to.eq(0);
      expect(_loans4c[2].tokenId).to.eq(0);

      const _loans5 = await gammaPool.getLoans(0, 10, false);
      expect(_loans5.length).to.eq(11);
      checkLoan(_loans5[0], 1, tokenId0);
      checkLoan(_loans5[1], 2, tokenId1);
      checkLoan(_loans5[2], 3, tokenId2);
      checkLoan(_loans5[3], 4, tokenId3);
      checkLoan(_loans5[4], 5, tokenId4);
      checkLoan(_loans5[5], 6, tokenId5);
      checkLoan(_loans5[6], 7, tokenId6);
      checkLoan(_loans5[7], 8, tokenId7);
      checkLoan(_loans5[8], 9, tokenId8);
      checkLoan(_loans5[9], 10, tokenId9);
      checkLoan(_loans5[10], 11, tokenId10);

      const _loans6 = await gammaPool.getLoans(10, 11, false);
      expect(_loans6.length).to.eq(1);
      checkLoan(_loans6[0], 11, tokenId10);

      const _loans7 = await gammaPool.getLoans(11, 11, false);
      expect(_loans7.length).to.eq(0);

      const _loans8 = await gammaPool.getLoans(11, 110, false);
      expect(_loans8.length).to.eq(0);

      const _loans9 = await gammaPool.getLoans(2, 1, false);
      expect(_loans9.length).to.eq(0);

      const _loans10 = await gammaPool.getLoans(8, 4, false);
      expect(_loans10.length).to.eq(0);
    });

    it("Update Loan", async function () {
      const abi = ethers.utils.defaultAbiCoder;
      const data = abi.encode(
        ["address", "address", "uint256"], // encode as address array
        [owner.address, gammaPool.address, 1]
      );
      const tokenId = ethers.BigNumber.from(ethers.utils.keccak256(data));

      const res0 = await (
        await gammaPool.increaseCollateral(tokenId, [])
      ).wait();
      expect(res0.events[0].args.tokenId).to.eq(tokenId);
      expect(res0.events[0].args.tokensHeld.length).to.eq(2);
      expect(res0.events[0].args.tokensHeld[0]).to.eq(1);
      expect(res0.events[0].args.tokensHeld[1]).to.eq(2);
      expect(res0.events[0].args.liquidity).to.eq(11);
      expect(res0.events[0].args.initLiquidity).to.eq(12);
      expect(res0.events[0].args.lpTokens).to.eq(13);
      expect(res0.events[0].args.rateIndex).to.eq(14);
      expect(res0.events[0].args.txType).to.eq(4);

      const res1 = await (
        await gammaPool.decreaseCollateral(
          tokenId,
          [100, 200],
          addr1.address,
          []
        )
      ).wait();
      expect(res1.events[0].args.tokenId).to.eq(tokenId);
      expect(res1.events[0].args.tokensHeld.length).to.eq(2);
      expect(res1.events[0].args.tokensHeld[0]).to.eq(100);
      expect(res1.events[0].args.tokensHeld[1]).to.eq(200);
      expect(res1.events[0].args.liquidity).to.eq(21);
      expect(res1.events[0].args.initLiquidity).to.eq(22);
      expect(res1.events[0].args.lpTokens).to.eq(23);
      expect(res1.events[0].args.rateIndex).to.eq(24);
      expect(res1.events[0].args.txType).to.eq(5);

      const res2 = await (
        await gammaPool.borrowLiquidity(tokenId, 300, [])
      ).wait();
      expect(res2.events[0].args.tokenId).to.eq(tokenId);
      expect(res2.events[0].args.tokensHeld.length).to.eq(2);
      expect(res2.events[0].args.tokensHeld[0]).to.eq(600);
      expect(res2.events[0].args.tokensHeld[1]).to.eq(300);
      expect(res2.events[0].args.liquidity).to.eq(31);
      expect(res2.events[0].args.initLiquidity).to.eq(32);
      expect(res2.events[0].args.lpTokens).to.eq(33);
      expect(res2.events[0].args.rateIndex).to.eq(34);
      expect(res2.events[0].args.txType).to.eq(7);

      const res3 = await (
        await gammaPool.repayLiquidity(
          tokenId,
          400,
          [43, 44],
          0,
          ethers.constants.AddressZero
        )
      ).wait();
      expect(res3.events[0].args.tokenId).to.eq(tokenId);
      expect(res3.events[0].args.tokensHeld.length).to.eq(2);
      expect(res3.events[0].args.tokensHeld[0]).to.eq(9);
      expect(res3.events[0].args.tokensHeld[1]).to.eq(10);
      expect(res3.events[0].args.liquidity).to.eq(400);
      expect(res3.events[0].args.initLiquidity).to.eq(42);
      expect(res3.events[0].args.lpTokens).to.eq(43);
      expect(res3.events[0].args.rateIndex).to.eq(44);
      expect(res3.events[0].args.txType).to.eq(8);

      const res4 = await (
        await gammaPool.repayLiquidityWithLP(
          tokenId,
          400,
          1,
          ethers.constants.AddressZero
        )
      ).wait();
      expect(res4.events[0].args.tokenId).to.eq(tokenId);
      expect(res4.events[0].args.tokensHeld.length).to.eq(2);
      expect(res4.events[0].args.tokensHeld[0]).to.eq(11);
      expect(res4.events[0].args.tokensHeld[1]).to.eq(12);
      expect(res4.events[0].args.liquidity).to.eq(400);
      expect(res4.events[0].args.initLiquidity).to.eq(40);
      expect(res4.events[0].args.lpTokens).to.eq(1);
      expect(res4.events[0].args.rateIndex).to.eq(20);
      expect(res4.events[0].args.txType).to.eq(9);

      const res5 = await (
        await gammaPool.rebalanceCollateral(tokenId, [500, 600], [])
      ).wait();
      expect(res5.events[0].args.tokenId).to.eq(tokenId);
      expect(res5.events[0].args.tokensHeld.length).to.eq(2);
      expect(res5.events[0].args.tokensHeld[0]).to.eq(500);
      expect(res5.events[0].args.tokensHeld[1]).to.eq(600);
      expect(res5.events[0].args.liquidity).to.eq(51);
      expect(res5.events[0].args.initLiquidity).to.eq(52);
      expect(res5.events[0].args.lpTokens).to.eq(53);
      expect(res5.events[0].args.rateIndex).to.eq(54);
      expect(res5.events[0].args.txType).to.eq(6);
    });
  });

  // You can nest describe calls to create subsections.
  describe("Liquidations", function () {
    it("batch liquidations", async function () {
      const abi = ethers.utils.defaultAbiCoder;
      const data1 = abi.encode(
        ["address", "address", "uint256"], // encode as address array
        [owner.address, gammaPool.address, 1]
      );
      const data2 = abi.encode(
        ["address", "address", "uint256"], // encode as address array
        [addr1.address, gammaPool.address, 1]
      );
      const tokenId1 = ethers.BigNumber.from(ethers.utils.keccak256(data1));
      const tokenId2 = ethers.BigNumber.from(ethers.utils.keccak256(data2));
      const res0 = await (
        await gammaPool.batchLiquidations([tokenId1, tokenId2])
      ).wait();
      expect(res0.events[0].event).to.eq("Liquidation");
      expect(res0.events[0].args.tokenId).to.eq(0);
      expect(res0.events[0].args.collateral).to.eq(11);
      expect(res0.events[0].args.liquidity).to.eq(12);
      expect(res0.events[0].args.writeDownAmt).to.eq(15);
      expect(res0.events[0].args.txType).to.eq(12);
      expect(res0.events[0].args.tokenIds.length).to.eq(2);
      expect(res0.events[0].args.tokenIds[0]).to.eq(tokenId1);
      expect(res0.events[0].args.tokenIds[1]).to.eq(tokenId2);
      expect(res0.events[1].event).to.eq("PoolUpdated");
      expect(res0.events[1].args.lpTokenBalance).to.eq(16);
      expect(res0.events[1].args.lpTokenBorrowed).to.eq(13);
      expect(res0.events[1].args.lastBlockNumber).to.eq(14);
      expect(res0.events[1].args.accFeeIndex).to.eq(700);
      expect(res0.events[1].args.lpTokenBorrowedPlusInterest).to.eq(800);
      expect(res0.events[1].args.lpInvariant).to.eq(900);
      expect(res0.events[1].args.borrowedInvariant).to.eq(1000);
      expect(res0.events[1].args.cfmmReserves.length).to.eq(2);
      expect(res0.events[1].args.cfmmReserves[0]).to.eq(15);
      expect(res0.events[1].args.cfmmReserves[1]).to.eq(16);
      expect(res0.events[1].args.txType).to.eq(12);
    });

    it("Liquidate with LP", async function () {
      const abi = ethers.utils.defaultAbiCoder;
      const data = abi.encode(
        ["address", "address", "uint256"], // encode as address array
        [owner.address, gammaPool.address, 1]
      );
      const tokenId = ethers.BigNumber.from(ethers.utils.keccak256(data));
      const res0 = await (await gammaPool.liquidateWithLP(tokenId)).wait();
      expect(res0.events[0].event).to.eq("LoanUpdated");
      expect(res0.events[0].args.tokenId).to.eq(tokenId);
      expect(res0.events[0].args.tokensHeld.length).to.eq(2);
      expect(res0.events[0].args.tokensHeld[0]).to.eq(6);
      expect(res0.events[0].args.tokensHeld[1]).to.eq(7);
      expect(res0.events[0].args.liquidity).to.eq(8);
      expect(res0.events[0].args.initLiquidity).to.eq(9);
      expect(res0.events[0].args.lpTokens).to.eq(10);
      expect(res0.events[0].args.rateIndex).to.eq(11);
      expect(res0.events[0].args.txType).to.eq(11);
      expect(res0.events[1].event).to.eq("Liquidation");
      expect(res0.events[1].args.tokenId).to.eq(tokenId);
      expect(res0.events[1].args.collateral).to.eq(400);
      expect(res0.events[1].args.liquidity).to.eq(500);
      expect(res0.events[1].args.writeDownAmt).to.eq(600);
      expect(res0.events[1].args.txType).to.eq(11);
      expect(res0.events[1].args.tokenIds.length).to.eq(0);
    });

    it("Liquidate", async function () {
      const abi = ethers.utils.defaultAbiCoder;
      const data = abi.encode(
        ["address", "address", "uint256"], // encode as address array
        [owner.address, gammaPool.address, 1]
      );
      const tokenId = ethers.BigNumber.from(ethers.utils.keccak256(data));
      const res0 = await (await gammaPool.liquidate(tokenId, [], [])).wait();
      expect(res0.events[0].event).to.eq("LoanUpdated");
      expect(res0.events[0].args.tokenId).to.eq(tokenId);
      expect(res0.events[0].args.tokensHeld.length).to.eq(2);
      expect(res0.events[0].args.tokensHeld[0]).to.eq(1);
      expect(res0.events[0].args.tokensHeld[1]).to.eq(3);
      expect(res0.events[0].args.liquidity).to.eq(777);
      expect(res0.events[0].args.initLiquidity).to.eq(888);
      expect(res0.events[0].args.lpTokens).to.eq(4);
      expect(res0.events[0].args.rateIndex).to.eq(5);
      expect(res0.events[0].args.txType).to.eq(10);
      expect(res0.events[1].event).to.eq("Liquidation");
      expect(res0.events[1].args.tokenId).to.eq(tokenId);
      expect(res0.events[1].args.collateral).to.eq(100);
      expect(res0.events[1].args.liquidity).to.eq(200);
      expect(res0.events[1].args.writeDownAmt).to.eq(300);
      expect(res0.events[1].args.txType).to.eq(10);
      expect(res0.events[1].args.tokenIds.length).to.eq(0);

      const res1 = await (
        await gammaPool.liquidate(tokenId, [999, 1111], [1, 2])
      ).wait();
      expect(res1.events[0].args.tokenId).to.eq(tokenId);
      expect(res1.events[0].args.tokensHeld.length).to.eq(2);
      expect(res1.events[0].args.tokensHeld[0]).to.eq(1);
      expect(res1.events[0].args.tokensHeld[1]).to.eq(2);
      expect(res1.events[0].args.liquidity).to.eq(999);
      expect(res1.events[0].args.initLiquidity).to.eq(1111);
      expect(res1.events[0].args.lpTokens).to.eq(4);
      expect(res1.events[0].args.rateIndex).to.eq(5);
      expect(res1.events[0].args.txType).to.eq(10);
      expect(res1.events[1].event).to.eq("Liquidation");
      expect(res1.events[1].args.tokenId).to.eq(tokenId);
      expect(res1.events[1].args.collateral).to.eq(100);
      expect(res1.events[1].args.liquidity).to.eq(201);
      expect(res1.events[1].args.writeDownAmt).to.eq(302);
      expect(res1.events[1].args.txType).to.eq(10);
    });
  });

  describe("Refunds", function () {
    it("Does not receive ETH", async function () {
      const tx = {
        from: owner.address,
        to: gammaPool.address,
        value: ethers.utils.parseEther("1"),
        nonce: await ethers.provider.getTransactionCount(
          owner.address,
          "latest"
        ),
        gasLimit: ethers.utils.hexlify("0x100000"),
        gasPrice: await ethers.provider.getGasPrice(),
      };
      await expect(owner.sendTransaction(tx)).to.be.revertedWithoutReason();
    });

    it("Clear Restricted Tokens, Fail", async function () {
      for (let i = 0; i < tokens.length; i++) {
        await expect(
          gammaPool.clearToken(tokens[i], owner.address, 0)
        ).to.be.revertedWithCustomError(gammaPool, "RestrictedToken");
      }
      await expect(
        gammaPool.clearToken(cfmm.address, owner.address, 0)
      ).to.be.revertedWithCustomError(gammaPool, "RestrictedToken");
    });

    it("Clear Restricted Tokens, Success", async function () {
      const balance0 = await tokenC.balanceOf(gammaPool.address);
      expect(balance0).to.eq(0);
      await (await tokenC.transfer(gammaPool.address, 100)).wait();
      const balance1 = await tokenC.balanceOf(gammaPool.address);
      expect(balance1).to.eq(100);
      const addr1Balance0 = await tokenC.balanceOf(addr1.address);
      expect(addr1Balance0).to.eq(0);
      await (
        await gammaPool.clearToken(tokenC.address, addr1.address, 0)
      ).wait();
      const addr1Balance1 = await tokenC.balanceOf(addr1.address);
      expect(addr1Balance1).to.eq(100);
      const balance2 = await tokenC.balanceOf(gammaPool.address);
      expect(balance2).to.eq(0);

      await (
        await gammaPool.clearToken(tokenC.address, addr1.address, 0)
      ).wait();
      const addr1Balance2 = await tokenC.balanceOf(addr1.address);
      expect(addr1Balance2).to.eq(100);
      const balance3 = await tokenC.balanceOf(gammaPool.address);
      expect(balance3).to.eq(0);
    });

    it("Check Token Threshold Balance Before Clearing", async function () {
      const balance0 = await tokenC.balanceOf(gammaPool.address);
      expect(balance0).to.eq(0);
      await (await tokenC.transfer(gammaPool.address, 100)).wait();
      const balance1 = await tokenC.balanceOf(gammaPool.address);
      expect(balance1).to.eq(100);

      await expect(
        gammaPool.clearToken(tokenC.address, owner.address, 101)
      ).to.be.revertedWithCustomError(gammaPool, "NotEnoughTokens");
    });

    it("Skimming nothing off the top", async function () {
      await checkBalances(0, 0, 0, 0, 0, 0, 0);

      await (await tokenA.transfer(gammaPool.address, 1000)).wait();
      await (await tokenB.transfer(gammaPool.address, 2000)).wait();
      await (await tokenC.transfer(gammaPool.address, 3000)).wait();
      await (await cfmm.transfer(gammaPool.address, 4000)).wait();

      await checkBalances(1000, 2000, 3000, 4000, 0, 0, 0);

      await (await gammaPool.syncTokens()).wait();

      await checkBalances(1000, 2000, 3000, 4000, 1000, 2000, 4000);

      const balanceA0 = await tokenA.balanceOf(owner.address);
      const balanceB0 = await tokenB.balanceOf(owner.address);
      const balanceC0 = await tokenC.balanceOf(owner.address);
      const balanceCfmm0 = await cfmm.balanceOf(owner.address);

      await (await gammaPool.skim(owner.address)).wait();

      await checkBalances(1000, 2000, 3000, 4000, 1000, 2000, 4000);

      expect(await tokenA.balanceOf(owner.address)).to.eq(balanceA0);
      expect(await tokenB.balanceOf(owner.address)).to.eq(balanceB0);
      expect(await tokenC.balanceOf(owner.address)).to.eq(balanceC0);
      expect(await cfmm.balanceOf(owner.address)).to.eq(balanceCfmm0);
    });

    it("Skimming off the top", async function () {
      await checkBalances(0, 0, 0, 0, 0, 0, 0);

      await (await tokenA.transfer(gammaPool.address, 1000)).wait();
      await (await tokenB.transfer(gammaPool.address, 2000)).wait();
      await (await tokenC.transfer(gammaPool.address, 3000)).wait();
      await (await cfmm.transfer(gammaPool.address, 4000)).wait();

      await checkBalances(1000, 2000, 3000, 4000, 0, 0, 0);

      await (await gammaPool.syncTokens()).wait();

      await checkBalances(1000, 2000, 3000, 4000, 1000, 2000, 4000);

      await (await tokenA.transfer(gammaPool.address, 1000)).wait();
      await (await tokenB.transfer(gammaPool.address, 2000)).wait();
      await (await tokenC.transfer(gammaPool.address, 3000)).wait();
      await (await cfmm.transfer(gammaPool.address, 4000)).wait();

      await checkBalances(2000, 4000, 6000, 8000, 1000, 2000, 4000);

      const balanceA0 = await tokenA.balanceOf(owner.address);
      const balanceB0 = await tokenB.balanceOf(owner.address);
      const balanceC0 = await tokenC.balanceOf(owner.address);
      const balanceCfmm0 = await cfmm.balanceOf(owner.address);

      await (await gammaPool.skim(owner.address)).wait();

      await checkBalances(1000, 2000, 6000, 4000, 1000, 2000, 4000);

      expect(await tokenA.balanceOf(owner.address)).to.eq(balanceA0.add(1000));
      expect(await tokenB.balanceOf(owner.address)).to.eq(balanceB0.add(2000));
      expect(await tokenC.balanceOf(owner.address)).to.eq(balanceC0);
      expect(await cfmm.balanceOf(owner.address)).to.eq(balanceCfmm0.add(4000));
    });

    it("Syncing already synced", async function () {
      const res = await (await gammaPool.sync()).wait();
      expect(res.events[0].event).to.eq("PoolUpdated");
      expect(res.events[0].args.lpTokenBalance).to.eq(1);
      expect(res.events[0].args.lpTokenBorrowed).to.eq(2);
      expect(res.events[0].args.lastBlockNumber).to.eq(3);
      expect(res.events[0].args.accFeeIndex).to.eq(4);
      expect(res.events[0].args.lpTokenBorrowedPlusInterest).to.eq(5);
      expect(res.events[0].args.lpInvariant).to.eq(6);
      expect(res.events[0].args.borrowedInvariant).to.eq(7);
      expect(res.events[0].args.cfmmReserves.length).to.eq(2);
      expect(res.events[0].args.cfmmReserves[0]).to.eq(8);
      expect(res.events[0].args.cfmmReserves[1]).to.eq(9);
      expect(res.events[0].args.txType).to.eq(13);
    });
  });
});
