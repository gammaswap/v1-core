import { ethers } from "hardhat";
import { expect } from "chai";

const PROTOCOL_ID = 1;

describe("GammaPool", function () {
  let TestERC20: any;
  let TestAddressCalculator: any;
  let TestLongStrategy: any;
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
  let longStrategy: any;
  let shortStrategy: any;
  let liquidationStrategy: any;
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

    TestLongStrategy = await ethers.getContractFactory("TestLongStrategy2");
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
    longStrategy = await TestLongStrategy.deploy();
    shortStrategy = await TestShortStrategy.deploy();
    liquidationStrategy = await TestLiquidationStrategy.deploy();
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
      longStrategy.address,
      shortStrategy.address,
      liquidationStrategy.address
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
      expect(await gammaPool.longStrategy()).to.equal(longStrategy.address);
      expect(await gammaPool.shortStrategy()).to.equal(shortStrategy.address);
      expect(await gammaPool.liquidationStrategy()).to.equal(
        liquidationStrategy.address
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
      const _tokens = res3.tokens;
      expect(_tokens.length).to.equal(2);
      expect(_tokens[0]).to.equal(tokenA.address);
      expect(_tokens[1]).to.equal(tokenB.address);

      expect(res3.factory).to.equal(factory.address);
      expect(res3.longStrategy).to.equal(longStrategy.address);
      expect(res3.shortStrategy).to.equal(shortStrategy.address);
      expect(res3.liquidationStrategy).to.equal(liquidationStrategy.address);
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
    });

    it("Update Loan", async function () {
      const abi = ethers.utils.defaultAbiCoder;
      const data = abi.encode(
        ["address", "address", "uint256"], // encode as address array
        [owner.address, gammaPool.address, 1]
      );
      const tokenId = ethers.BigNumber.from(ethers.utils.keccak256(data));

      const res0 = await (await gammaPool.increaseCollateral(tokenId)).wait();
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
        await gammaPool.decreaseCollateral(tokenId, [100, 200], addr1.address)
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

      const res2 = await (await gammaPool.borrowLiquidity(tokenId, 300)).wait();
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
        await gammaPool.repayLiquidity(tokenId, 400, [43, 44])
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
        await gammaPool.rebalanceCollateral(tokenId, [500, 600])
      ).wait();
      expect(res4.events[0].args.tokenId).to.eq(tokenId);
      expect(res4.events[0].args.tokensHeld.length).to.eq(2);
      expect(res4.events[0].args.tokensHeld[0]).to.eq(500);
      expect(res4.events[0].args.tokensHeld[1]).to.eq(600);
      expect(res4.events[0].args.liquidity).to.eq(51);
      expect(res4.events[0].args.initLiquidity).to.eq(52);
      expect(res4.events[0].args.lpTokens).to.eq(53);
      expect(res4.events[0].args.rateIndex).to.eq(54);
      expect(res4.events[0].args.txType).to.eq(6);
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
      expect(res0.events[0].args.txType).to.eq(11);
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
      expect(res0.events[1].args.txType).to.eq(11);
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
      expect(res0.events[0].args.txType).to.eq(10);
      expect(res0.events[1].event).to.eq("Liquidation");
      expect(res0.events[1].args.tokenId).to.eq(tokenId);
      expect(res0.events[1].args.collateral).to.eq(400);
      expect(res0.events[1].args.liquidity).to.eq(500);
      expect(res0.events[1].args.writeDownAmt).to.eq(600);
      expect(res0.events[1].args.txType).to.eq(10);
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
      expect(res0.events[0].args.txType).to.eq(9);
      expect(res0.events[1].event).to.eq("Liquidation");
      expect(res0.events[1].args.tokenId).to.eq(tokenId);
      expect(res0.events[1].args.collateral).to.eq(100);
      expect(res0.events[1].args.liquidity).to.eq(200);
      expect(res0.events[1].args.writeDownAmt).to.eq(300);
      expect(res0.events[1].args.txType).to.eq(9);
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
      expect(res1.events[0].args.txType).to.eq(9);
      expect(res1.events[1].event).to.eq("Liquidation");
      expect(res1.events[1].args.tokenId).to.eq(tokenId);
      expect(res1.events[1].args.collateral).to.eq(100);
      expect(res1.events[1].args.liquidity).to.eq(201);
      expect(res1.events[1].args.writeDownAmt).to.eq(302);
      expect(res1.events[1].args.txType).to.eq(9);
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
      await expect(owner.sendTransaction(tx)).to.be.revertedWith(
        "Transaction reverted"
      );
    });

    it("Clear Restricted Tokens, Fail", async function () {
      for (let i = 0; i < tokens.length; i++) {
        await expect(
          gammaPool.clearToken(tokens[i], owner.address, 0)
        ).to.be.revertedWith("RestrictedToken");
      }
      await expect(
        gammaPool.clearToken(cfmm.address, owner.address, 0)
      ).to.be.revertedWith("RestrictedToken");
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
      ).to.be.revertedWith("NotEnoughTokens");
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
      expect(res.events[0].args.txType).to.eq(12);
    });
  });
});
