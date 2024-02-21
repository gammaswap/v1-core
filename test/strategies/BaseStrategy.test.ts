import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe("BaseStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let strategy: any;
  let owner: any;
  let addr1: any;
  let GammaPoolFactory: any;
  let factory: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCFMM = await ethers.getContractFactory("TestCFMM");
    TestStrategy = await ethers.getContractFactory("TestBaseStrategy");
    [owner, addr1] = await ethers.getSigners();

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    cfmm = await TestCFMM.deploy(
      tokenA.address,
      tokenB.address,
      "Test CFMM",
      "TCFMM"
    );

    GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");

    factory = await GammaPoolFactory.deploy(owner.address);
    await factory.setFee(0);

    strategy = await TestStrategy.deploy(factory.address, PROTOCOL_ID);
    await (
      await strategy.initialize(
        cfmm.address,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();
  });

  async function depositInCFMM(amount0: any, amount1: any) {
    const balanceA = await tokenA.balanceOf(cfmm.address);
    const balanceB = await tokenB.balanceOf(cfmm.address);

    await (await tokenA.transfer(cfmm.address, amount0)).wait();
    await (await tokenB.transfer(cfmm.address, amount1)).wait();
    expect(await cfmm.reserves0()).to.equal(balanceA);
    expect(await cfmm.reserves1()).to.equal(balanceB);

    await (await cfmm.sync()).wait();
    expect(await cfmm.reserves0()).to.equal(balanceA.add(amount0));
    expect(await cfmm.reserves1()).to.equal(balanceB.add(amount1));
  }

  function getCFMMIndex(
    lastCFMMInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber,
    prevCFMMInvariant: BigNumber,
    prevCFMMTotalSupply: BigNumber
  ): BigNumber {
    const ONE = ethers.BigNumber.from(10).pow(18);
    const denominator = prevCFMMInvariant.mul(lastCFMMTotalSupply).div(ONE);
    return lastCFMMInvariant.mul(prevCFMMTotalSupply).div(denominator);
  }

  async function checkCFMMData(
    strategy: any,
    CFMMFeeIndex: BigNumber,
    CFMMInvariant: BigNumber,
    CFMMTotalSupply: BigNumber
  ) {
    await (await strategy.testUpdateCFMMIndex()).wait();
    const cfmmData = await strategy.getCFMMData();
    expect(cfmmData.lastCFMMFeeIndex).to.equal(CFMMFeeIndex);
    expect(cfmmData.lastCFMMInvariant).to.equal(CFMMInvariant);
    expect(cfmmData.lastCFMMTotalSupply).to.equal(CFMMTotalSupply);
  }

  function calcFeeIndex(
    blockNumber: BigNumber,
    lastBlockNumber: BigNumber,
    borrowRate: BigNumber,
    cfmmFeeIndex: BigNumber
  ): BigNumber {
    const blockDiff = blockNumber.sub(lastBlockNumber);
    const adjBorrowRate = blockDiff.mul(borrowRate).div(2252571);
    const ONE = BigNumber.from(10).pow(18);
    const adj1kApy = ONE.add(blockDiff.mul(ONE.mul(10)).div(2252571));
    const poolYield = cfmmFeeIndex.add(adjBorrowRate);
    if (adj1kApy.lt(poolYield)) {
      return adj1kApy;
    } else {
      return poolYield;
    }
  }

  async function testFeeIndex(cfmmIndex: BigNumber, borrowRate: BigNumber) {
    await (await strategy.setBorrowRate(borrowRate)).wait();
    await (await strategy.setCFMMIndex(cfmmIndex)).wait();
    await (await strategy.testUpdateFeeIndex()).wait();
    const lastFeeIndex = await strategy.getLastFeeIndex();
    const lastBlockNumber = await strategy.getLastBlockNumber();
    const latestBlock = await ethers.provider.getBlock("latest");
    const expFeeIndex = calcFeeIndex(
      BigNumber.from(latestBlock.number),
      lastBlockNumber,
      borrowRate,
      cfmmIndex
    );
    expect(lastFeeIndex).to.equal(expFeeIndex);
  }
  async function testFeeIndexCases(num: BigNumber) {
    await testFeeIndex(num, num);
    await testFeeIndex(num, num.mul(2));
    await testFeeIndex(num.mul(2), num);
    await testFeeIndex(num.mul(2), num.mul(3));
  }

  function updateBorrowedInvariant(
    borrowedInvariant: BigNumber,
    lastFeeIndex: BigNumber
  ): BigNumber {
    const ONE = ethers.BigNumber.from(10).pow(18);
    return borrowedInvariant.mul(lastFeeIndex).div(ONE);
  }

  function calcLPTokenBorrowedPlusInterest(
    borrowedInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber,
    lastCFMMInvariant: BigNumber
  ): BigNumber {
    if (lastCFMMInvariant.eq(0)) {
      return BigNumber.from(0);
    }
    return borrowedInvariant.mul(lastCFMMTotalSupply).div(lastCFMMInvariant);
  }

  function calcLPInvariant(
    lpTokenBalance: BigNumber,
    lastCFMMInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber
  ): BigNumber {
    if (lastCFMMTotalSupply.eq(0)) {
      return BigNumber.from(0);
    }
    return lpTokenBalance.mul(lastCFMMInvariant).div(lastCFMMTotalSupply);
  }

  function calcLPTokenTotal(
    lpTokenBalance: BigNumber,
    lpTokenBorrowedPlusInterest: BigNumber
  ): BigNumber {
    return lpTokenBalance.add(lpTokenBorrowedPlusInterest);
  }

  function calcTotalInvariant(
    lpInvariant: BigNumber,
    borrowedInvariant: BigNumber
  ): BigNumber {
    return lpInvariant.add(borrowedInvariant);
  }

  function updateAccFeeIndex(
    accFeeIndex: BigNumber,
    lastFeeIndex: BigNumber
  ): BigNumber {
    const ONE = ethers.BigNumber.from(10).pow(18);
    return accFeeIndex.mul(lastFeeIndex).div(ONE);
  }

  async function checkUpdateStore(
    strategy: any,
    accFeeIndex: BigNumber,
    lastFeeIndex: BigNumber,
    lpTokenBalance: BigNumber,
    borrowedInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber,
    lastCFMMInvariant: BigNumber
  ) {
    const expBorrowedInvariant = updateBorrowedInvariant(
      borrowedInvariant,
      lastFeeIndex
    );
    const expLpTokenBorrowedPlusInterest = calcLPTokenBorrowedPlusInterest(
      expBorrowedInvariant,
      lastCFMMTotalSupply,
      lastCFMMInvariant
    );
    const expLPInvariant = calcLPInvariant(
      lpTokenBalance,
      lastCFMMInvariant,
      lastCFMMTotalSupply
    );
    const expLPTokenTotal = calcLPTokenTotal(
      lpTokenBalance,
      expLpTokenBorrowedPlusInterest
    );
    const expTotalInvariant = calcTotalInvariant(
      expLPInvariant,
      expBorrowedInvariant
    );
    const expAccFeeIndex = updateAccFeeIndex(accFeeIndex, lastFeeIndex);
    const latestBlock = await ethers.provider.getBlock("latest");
    const expBlockNumber = BigNumber.from(latestBlock.number);
    const storeFields = await strategy.getUpdateStoreFields();

    expect(storeFields.borrowedInvariant).to.equal(expBorrowedInvariant);
    expect(storeFields.accFeeIndex).to.equal(expAccFeeIndex);
    expect(storeFields.lpInvariant).to.equal(expLPInvariant);
    expect(storeFields.lpTokenTotal).to.equal(expLPTokenTotal);
    expect(storeFields.totalInvariant).to.equal(expTotalInvariant);
    expect(storeFields.lastBlockNumber).to.equal(expBlockNumber);
  }

  async function testUpdateStore(
    strategy: any,
    accFeeIndex: BigNumber,
    lastFeeIndex: BigNumber,
    lpTokenBalance: BigNumber,
    borrowedInvariant: BigNumber,
    lastCFMMTotalSupply: BigNumber,
    lastCFMMInvariant: BigNumber
  ) {
    await (
      await strategy.setUpdateStoreFields(
        accFeeIndex,
        lastFeeIndex,
        lpTokenBalance,
        borrowedInvariant,
        lastCFMMTotalSupply,
        lastCFMMInvariant
      )
    ).wait();
    await (await strategy.testUpdateStore()).wait();
    await checkUpdateStore(
      strategy,
      accFeeIndex,
      lastFeeIndex,
      lpTokenBalance,
      borrowedInvariant,
      lastCFMMTotalSupply,
      lastCFMMInvariant
    );
  }

  async function execFirstUpdateIndex() {
    const ONE = BigNumber.from(10).pow(18);
    const cfmmInvariant = ONE.mul(1000);
    await (await strategy.setInvariant(cfmmInvariant)).wait();
    await (await cfmm.mint(ONE.mul(100), owner.address)).wait();
    await (await cfmm.mint(ONE.mul(100), strategy.address)).wait();
    const lpTokenBal = ONE.mul(100);
    const borrowedInvariant = ONE.mul(200);
    await (
      await strategy.setLPTokenBalAndBorrowedInv(lpTokenBal, borrowedInvariant)
    ).wait();
    await (await strategy.testUpdateIndex()).wait();
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set right init params", async function () {
      const params = await strategy.getParameters();
      expect(params.factory).to.equal(factory.address);
      expect(params.cfmm).to.equal(cfmm.address);
      expect(params.tokens[0]).to.equal(tokenA.address);
      expect(params.tokens[1]).to.equal(tokenB.address);
      expect(params.protocolId).to.equal(PROTOCOL_ID);

      const cfmmData = await strategy.getCFMMData();
      const ONE = ethers.BigNumber.from(10).pow(18);
      expect(cfmmData.lastCFMMInvariant).to.equal(0);
      expect(cfmmData.lastCFMMTotalSupply).to.equal(0);

      expect(await strategy.invariant()).to.equal(0);
      await (await strategy.setInvariant(100000)).wait();
      expect(await strategy.invariant()).to.equal(100000);

      expect(await strategy.getCFMMIndex()).to.equal(0);
      await (await strategy.setCFMMIndex(ONE.mul(2))).wait();
      expect(await strategy.getCFMMIndex()).to.equal(ONE.mul(2));

      expect(await strategy.borrowRate()).to.equal(ONE);
      await (await strategy.setBorrowRate(ONE.mul(2))).wait();
      expect(await strategy.borrowRate()).to.equal(ONE.mul(2));

      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);
      const lastBlockNumber = await strategy.getLastBlockNumber();
      const latestBlock = await ethers.provider.getBlock("latest");

      expect(lastBlockNumber).to.lt(BigNumber.from(latestBlock.number));

      await (await strategy.updateLastBlockNumber()).wait();
      const latestBlock0 = await ethers.provider.getBlock("latest");
      const lastBlockNumber0 = await strategy.getLastBlockNumber();
      expect(lastBlockNumber0).to.equal(BigNumber.from(latestBlock0.number));

      await (
        await strategy.setUpdateStoreFields(10, 20, 30, 40, 50, 60)
      ).wait();
      const storeFields = await strategy.getUpdateStoreFields();
      expect(storeFields.accFeeIndex).to.equal(10);
      expect(storeFields.lastFeeIndex).to.equal(20);
      expect(storeFields.lpTokenBalance).to.equal(30);
      expect(storeFields.borrowedInvariant).to.equal(40);
      expect(storeFields.lastCFMMTotalSupply).to.equal(50);
      expect(storeFields.lastCFMMInvariant).to.equal(60);
    });

    it("Update reserves", async function () {
      await depositInCFMM(1000, 2000);
      const reserves = await strategy.getReserves();
      await (await strategy.testUpdateReserves()).wait();
      const _reserves = await strategy.getReserves();
      expect(_reserves[0]).to.equal(reserves[0].add(1000));
      expect(_reserves[1]).to.equal(reserves[1].add(2000));
    });

    it("Mint & Burn shares", async function () {
      const balance = await cfmm.balanceOf(owner.address);
      const totalSupply = await cfmm.totalSupply();
      await (await cfmm.mint(100, owner.address)).wait();
      expect(await cfmm.balanceOf(owner.address)).to.equal(balance.add(100));
      expect(await cfmm.totalSupply()).to.equal(totalSupply.add(100));

      await (await cfmm.burn(100, owner.address)).wait();
      expect(await cfmm.balanceOf(owner.address)).to.equal(balance);
      expect(await cfmm.totalSupply()).to.equal(totalSupply);
    });
  });

  describe("Mint & Burn", function () {
    it("Mint", async function () {
      const balance = await strategy.balanceOf(owner.address);
      expect(balance).to.equal(0);
      expect(await strategy.totalSupply()).to.equal(0);

      await (await strategy.testMint(owner.address, 100)).wait();

      expect(await strategy.balanceOf(owner.address)).to.equal(
        balance.add(100)
      );
      expect(await strategy.totalSupply()).to.equal(100);

      await expect(
        strategy.testMint(owner.address, 0)
      ).to.be.revertedWithCustomError(strategy, "ZeroAmount");
      expect(await strategy.totalSupply()).to.equal(100);
    });

    it("Burn", async function () {
      await (await strategy.testMint(owner.address, 100)).wait();
      const balance = await strategy.balanceOf(owner.address);
      expect(balance).to.equal(100);
      expect(await strategy.totalSupply()).to.equal(100);

      await expect(
        strategy.testBurn(ethers.constants.AddressZero, 10)
      ).to.be.revertedWithCustomError(strategy, "ZeroAddress");

      await expect(
        strategy.testBurn(owner.address, 101)
      ).to.be.revertedWithCustomError(strategy, "ExcessiveBurn");
      await expect(
        strategy.testBurn(addr1.address, 1)
      ).to.be.revertedWithCustomError(strategy, "ExcessiveBurn");
      expect(await strategy.totalSupply()).to.equal(100);

      await (await strategy.testBurn(owner.address, 10)).wait();
      expect(await strategy.balanceOf(owner.address)).to.equal(90);
      expect(await strategy.totalSupply()).to.equal(90);

      await (await strategy.testBurn(owner.address, 90)).wait();
      expect(await strategy.balanceOf(owner.address)).to.equal(0);
      expect(await strategy.totalSupply()).to.equal(0);
    });
  });

  describe("Update Index Functions", function () {
    it("Update CFMM Index, last = 0, prev = 0 => idx = 1, prev = 0", async function () {
      const cfmmData = await strategy.getCFMMData();
      const ONE = ethers.BigNumber.from(10).pow(18);
      const prevCFMMInvariant = cfmmData.lastCFMMInvariant;
      const prevCFMMTotalSupply = cfmmData.lastCFMMTotalSupply;
      const prevCFMMFeeIndex = cfmmData.lastCFMMFeeIndex;

      const cfmmTotalSupply = await cfmm.totalSupply();
      const cfmmInvariant = await strategy.invariant();

      expect(prevCFMMFeeIndex).to.equal(0);
      expect(prevCFMMTotalSupply).to.equal(0);
      expect(prevCFMMInvariant).to.equal(0);
      expect(cfmmTotalSupply).to.equal(0);
      expect(cfmmInvariant).to.equal(0);
      // last = 0, prev = 0 => idx = 1, prev = 0
      // both 0
      await checkCFMMData(strategy, ONE, cfmmInvariant, cfmmTotalSupply);

      // only last.supp is 0
      const newInvariant = ONE.mul(100);
      await (await strategy.setInvariant(newInvariant)).wait();
      const cfmmInvariant0 = await strategy.invariant(); // 100
      const cfmmTotalSupply0 = await cfmm.totalSupply(); // 0
      expect(cfmmInvariant0).to.equal(newInvariant);
      expect(cfmmTotalSupply0).to.equal(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant0, cfmmTotalSupply0);

      // reset
      await (await strategy.setInvariant(0)).wait();
      const cfmmInvariant1 = await strategy.invariant(); // 0
      const cfmmTotalSupply1 = await cfmm.totalSupply(); // 0
      expect(cfmmInvariant1).to.equal(0);
      expect(cfmmTotalSupply1).to.equal(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant1, cfmmTotalSupply1);

      // only last.inv is 0
      const newSupply = ONE.mul(100);
      await (await cfmm.mint(newSupply, owner.address)).wait();
      const cfmmInvariant2 = await strategy.invariant(); // 0
      const cfmmTotalSupply2 = await cfmm.totalSupply(); // 0
      expect(cfmmInvariant2).to.equal(0);
      expect(cfmmTotalSupply2).to.equal(newSupply);
      await checkCFMMData(strategy, ONE, cfmmInvariant2, cfmmTotalSupply2);
    });

    it("Update CFMM Index, last > 0, prev = 0 => idx = 1, prev = last", async function () {
      // last > 0, prev = 0 => idx = 1, prev = last
      const cfmmData = await strategy.getCFMMData();
      const ONE = ethers.BigNumber.from(10).pow(18);
      const prevCFMMInvariant = cfmmData.lastCFMMInvariant;
      const prevCFMMTotalSupply = cfmmData.lastCFMMTotalSupply;
      const prevCFMMFeeIndex = cfmmData.lastCFMMFeeIndex;

      expect(prevCFMMFeeIndex).to.equal(0);
      expect(prevCFMMTotalSupply).to.equal(0);
      expect(prevCFMMInvariant).to.equal(0);

      const newSupply = ONE.mul(100);
      const newInvariant = ONE.mul(200);
      await (await cfmm.mint(newSupply, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant)).wait();
      const cfmmTotalSupply = await cfmm.totalSupply();
      const cfmmInvariant = await strategy.invariant();
      expect(cfmmTotalSupply).to.equal(newSupply);
      expect(cfmmInvariant).to.equal(newInvariant);
      await checkCFMMData(strategy, ONE, cfmmInvariant, cfmmTotalSupply);
    });

    it("Update CFMM Index, last > 0, prev > 0 => idx > 1, prev = last", async function () {
      const ONE = ethers.BigNumber.from(10).pow(18);
      const newSupply = ONE.mul(100);
      const newInvariant = ONE.mul(200);

      // last > 0, prev > 0 => idx > 1, prev = last
      await (await cfmm.mint(newSupply, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant.mul(3))).wait();
      const cfmmTotalSupplyX = await cfmm.totalSupply();
      const cfmmInvariantX = await strategy.invariant();
      expect(cfmmTotalSupplyX).to.equal(newSupply);
      expect(cfmmInvariantX).to.equal(newInvariant.mul(3));

      await (await strategy.testUpdateCFMMIndex()).wait();
      await (await cfmm.mint(newSupply, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant.mul(6))).wait();
      const cfmmTotalSupply0 = await cfmm.totalSupply();
      const cfmmInvariant0 = await strategy.invariant();
      expect(cfmmTotalSupply0).to.equal(newSupply.mul(2));
      expect(cfmmInvariant0).to.equal(newInvariant.mul(6));

      const cfmmData0 = await strategy.getCFMMData();
      const prevCFMMInvariant0 = cfmmData0.lastCFMMInvariant;
      const prevCFMMTotalSupply0 = cfmmData0.lastCFMMTotalSupply;
      expect(prevCFMMInvariant0).to.gt(0);
      expect(prevCFMMTotalSupply0).to.gt(0);
      const cfmmIndex = getCFMMIndex(
        cfmmInvariant0,
        cfmmTotalSupply0,
        prevCFMMInvariant0,
        prevCFMMTotalSupply0
      );

      await checkCFMMData(
        strategy,
        cfmmIndex,
        cfmmInvariant0,
        cfmmTotalSupply0
      );

      // last = 0, prev > 0 => idx = 1, prev = 0
      // both 0
      await (await cfmm.burn(cfmmTotalSupply0, owner.address)).wait();
      await (await strategy.setInvariant(0)).wait();
      const cfmmTotalSupply1 = await cfmm.totalSupply();
      const cfmmInvariant1 = await strategy.invariant();
      expect(cfmmTotalSupply1).to.equal(0);
      expect(cfmmInvariant1).to.equal(0);
      const cfmmData1 = await strategy.getCFMMData();
      const prevCFMMInvariant1 = cfmmData1.lastCFMMInvariant;
      const prevCFMMTotalSupply1 = cfmmData1.lastCFMMTotalSupply;
      const prevCFMMFeeIndex1 = cfmmData1.lastCFMMFeeIndex;
      expect(prevCFMMInvariant1).to.gt(0);
      expect(prevCFMMTotalSupply1).to.gt(0);
      expect(prevCFMMFeeIndex1).to.gt(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant1, cfmmTotalSupply1);

      // only supp becomes 0
      await (await cfmm.mint(cfmmTotalSupply0, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant.mul(4))).wait();
      const cfmmTotalSupply2 = await cfmm.totalSupply();
      const cfmmInvariant2 = await strategy.invariant();
      expect(cfmmTotalSupply2).to.gt(0);
      expect(cfmmInvariant2).to.gt(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant2, cfmmTotalSupply2);
      await (await strategy.setCFMMIndex(ONE.mul(4))).wait();
      const cfmmData2 = await strategy.getCFMMData();
      const prevCFMMInvariant2 = cfmmData2.lastCFMMInvariant;
      const prevCFMMTotalSupply2 = cfmmData2.lastCFMMTotalSupply;
      const prevCFMMFeeIndex2 = cfmmData2.lastCFMMFeeIndex;
      expect(prevCFMMInvariant2).to.gt(0);
      expect(prevCFMMTotalSupply2).to.gt(0);
      expect(prevCFMMFeeIndex2).to.equal(ONE.mul(4));

      await (await cfmm.burn(cfmmTotalSupply2, owner.address)).wait();
      const cfmmTotalSupply_ = await cfmm.totalSupply();
      const cfmmInvariant_ = await strategy.invariant();
      expect(cfmmTotalSupply_).to.equal(0);
      expect(cfmmInvariant_).to.gt(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant_, cfmmTotalSupply_);

      // only inv becomes 0
      await (await cfmm.mint(cfmmTotalSupply0, owner.address)).wait();
      await (await strategy.setInvariant(newInvariant.mul(5))).wait();
      const cfmmTotalSupply3 = await cfmm.totalSupply();
      const cfmmInvariant3 = await strategy.invariant();
      expect(cfmmTotalSupply3).to.gt(0);
      expect(cfmmInvariant3).to.gt(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant3, cfmmTotalSupply3);
      await (await strategy.setCFMMIndex(ONE.mul(3))).wait();
      const cfmmData3 = await strategy.getCFMMData();
      const prevCFMMInvariant3 = cfmmData3.lastCFMMInvariant;
      const prevCFMMTotalSupply3 = cfmmData3.lastCFMMTotalSupply;
      const prevCFMMFeeIndex3 = cfmmData3.lastCFMMFeeIndex;
      expect(prevCFMMInvariant3).to.gt(0);
      expect(prevCFMMTotalSupply3).to.gt(0);
      expect(prevCFMMFeeIndex3).to.equal(ONE.mul(3));

      await (await strategy.setInvariant(0)).wait();
      const cfmmTotalSupply0_ = await cfmm.totalSupply();
      const cfmmInvariant0_ = await strategy.invariant();
      expect(cfmmTotalSupply0_).to.gt(0);
      expect(cfmmInvariant0_).to.equal(0);
      await checkCFMMData(strategy, ONE, cfmmInvariant0_, cfmmTotalSupply0_);
    });

    it("Update Fee Index", async function () {
      const ONE = ethers.BigNumber.from(10).pow(18);
      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));

      // mine 1000 blocks with an interval of 1 minute
      await ethers.provider.send("hardhat_mine", ["0x3e8", "0x3c"]);

      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));

      await (await strategy.updateLastBlockNumber()).wait();

      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));

      // mine 1000 blocks with an interval of 1 minute
      await ethers.provider.send("hardhat_mine", ["0xaf9", "0xa3c"]);

      await testFeeIndexCases(ONE);
      await testFeeIndexCases(ONE.mul(2));
      await testFeeIndexCases(ONE.mul(3));
      await testFeeIndexCases(ONE.mul(5));
    });

    it("Update Store", async function () {
      const ONE = ethers.BigNumber.from(10).pow(18);
      const accFeeIndex = ONE.mul(10);
      const lastFeeIndex = ONE.mul(20);
      const lpTokenBalance = ONE.mul(30);
      const borrowedInvariant = ONE.mul(40);
      const lastCFMMTotalSupply = ONE.mul(50);
      const lastCFMMInvariant = ONE.mul(60);
      await testUpdateStore(
        strategy,
        accFeeIndex,
        lastFeeIndex,
        lpTokenBalance,
        borrowedInvariant,
        lastCFMMTotalSupply,
        lastCFMMInvariant
      );

      const accFeeIndex0 = ONE.mul(10);
      const lastFeeIndex0 = ONE.mul(20);
      const lpTokenBalance0 = ONE.mul(30);
      const borrowedInvariant0 = ONE.mul(40);
      const lastCFMMTotalSupply0 = ONE.mul(0);
      const lastCFMMInvariant0 = ONE.mul(60);
      await testUpdateStore(
        strategy,
        accFeeIndex0,
        lastFeeIndex0,
        lpTokenBalance0,
        borrowedInvariant0,
        lastCFMMTotalSupply0,
        lastCFMMInvariant0
      );

      const accFeeIndex1 = ONE.mul(10);
      const lastFeeIndex1 = ONE.mul(20);
      const lpTokenBalance1 = ONE.mul(30);
      const borrowedInvariant1 = ONE.mul(40);
      const lastCFMMTotalSupply1 = ONE.mul(50);
      const lastCFMMInvariant1 = ONE.mul(0);
      await testUpdateStore(
        strategy,
        accFeeIndex1,
        lastFeeIndex1,
        lpTokenBalance1,
        borrowedInvariant1,
        lastCFMMTotalSupply1,
        lastCFMMInvariant1
      );

      const accFeeIndex2 = ONE.mul(10);
      const lastFeeIndex2 = ONE.mul(20);
      const lpTokenBalance2 = ONE.mul(30);
      const borrowedInvariant2 = ONE.mul(40);
      const lastCFMMTotalSupply2 = ONE.mul(0);
      const lastCFMMInvariant2 = ONE.mul(0);
      await testUpdateStore(
        strategy,
        accFeeIndex2,
        lastFeeIndex2,
        lpTokenBalance2,
        borrowedInvariant2,
        lastCFMMTotalSupply2,
        lastCFMMInvariant2
      );

      const accFeeIndex3 = ONE.mul(103);
      const lastFeeIndex3 = ONE.mul(204);
      const lpTokenBalance3 = ONE.mul(320);
      const borrowedInvariant3 = ONE.mul(430);
      const lastCFMMTotalSupply3 = ONE.mul(1230);
      const lastCFMMInvariant3 = ONE.mul(110);
      await testUpdateStore(
        strategy,
        accFeeIndex3,
        lastFeeIndex3,
        lpTokenBalance3,
        borrowedInvariant3,
        lastCFMMTotalSupply3,
        lastCFMMInvariant3
      );
    });
  });

  describe("Update EMA Utilization Rate", function () {
    it("Init EMA Util Rate", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const twelveDec = BigNumber.from(10).pow(12);
      const sixDec = BigNumber.from(10).pow(6);
      const tx = await (
        await strategy.testUpdateUtilRateEma(ONE.div(twelveDec).div(10), 0, 2)
      ).wait();
      const event = tx.events[tx.events.length - 1];
      expect(event.event).to.equal("EmaUtilRate");
      expect(event.args.emaUtilRate).to.eq(0);

      const tx1 = await (
        await strategy.testUpdateUtilRateEma(ONE.div(sixDec), 0, 2)
      ).wait();
      const event1 = tx1.events[tx1.events.length - 1];
      expect(event1.event).to.equal("EmaUtilRate");
      expect(event1.args.emaUtilRate).to.eq(1);

      const tx2 = await (
        await strategy.testUpdateUtilRateEma(ONE.div(sixDec.div(10)), 0, 2)
      ).wait();
      const event2 = tx2.events[tx2.events.length - 1];
      expect(event2.event).to.equal("EmaUtilRate");
      expect(event2.args.emaUtilRate).to.eq(10);

      const pct80 = ONE.mul(80).div(100);
      const tx3 = await (
        await strategy.testUpdateUtilRateEma(pct80, 0, 2)
      ).wait();
      const event3 = tx3.events[tx3.events.length - 1];
      expect(event3.event).to.equal("EmaUtilRate");
      expect(event3.args.emaUtilRate).to.eq(pct80.div(twelveDec));
    });

    it("Update EMA Util Rate", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const twelveDec = BigNumber.from(10).pow(12);
      const initEmaUtilRate = ONE.mul(80).div(100).div(twelveDec); // 80%
      // EMA_1 = val * mult + EMA_0 * (1 - mult)
      const pct85 = ONE.mul(85).div(100);
      const tx = await (
        await strategy.testUpdateUtilRateEma(pct85, initEmaUtilRate, 0)
      ).wait();
      const event = tx.events[tx.events.length - 1];
      expect(event.event).to.equal("EmaUtilRate");
      expect(event.args.emaUtilRate).to.eq(initEmaUtilRate);

      const tx1 = await (
        await strategy.testUpdateUtilRateEma(pct85, initEmaUtilRate, 100)
      ).wait();
      const event1 = tx1.events[tx1.events.length - 1];
      expect(event1.event).to.equal("EmaUtilRate");
      expect(event1.args.emaUtilRate).to.eq(pct85.div(twelveDec));

      const pct805 = ONE.mul(805).div(1000);
      const tx2 = await (
        await strategy.testUpdateUtilRateEma(pct85, initEmaUtilRate, 10)
      ).wait();
      const event2 = tx2.events[tx2.events.length - 1];
      expect(event2.event).to.equal("EmaUtilRate");
      expect(event2.args.emaUtilRate).to.eq(pct805.div(twelveDec));

      const pct8095 = ONE.mul(8095).div(10000);
      const tx3 = await (
        await strategy.testUpdateUtilRateEma(pct85, pct805.div(twelveDec), 10)
      ).wait();
      const event3 = tx3.events[tx3.events.length - 1];
      expect(event3.event).to.equal("EmaUtilRate");
      expect(event3.args.emaUtilRate).to.eq(pct8095.div(twelveDec));

      const pct8176 = ONE.mul(8176).div(10000);
      const tx4 = await (
        await strategy.testUpdateUtilRateEma(pct85, pct8095.div(twelveDec), 20)
      ).wait();
      const event4 = tx4.events[tx4.events.length - 1];
      expect(event4.event).to.equal("EmaUtilRate");
      expect(event4.args.emaUtilRate).to.eq(pct8176.div(twelveDec));

      const pct1 = ONE.div(100);
      const pct65608 = ONE.mul(65608).div(100000);
      const tx5 = await (
        await strategy.testUpdateUtilRateEma(pct1, pct8176.div(twelveDec), 20)
      ).wait();
      const event5 = tx5.events[tx5.events.length - 1];
      expect(event5.event).to.equal("EmaUtilRate");
      expect(event5.args.emaUtilRate).to.eq(pct65608.div(twelveDec));
    });
  });

  describe("Update Index", function () {
    it("Update Index, check first update", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const cfmmInvariant = ONE.mul(1000);
      await (await strategy.setInvariant(cfmmInvariant)).wait();
      await (await cfmm.mint(ONE.mul(100), owner.address)).wait();
      await (await cfmm.mint(ONE.mul(100), strategy.address)).wait();
      const totalCFMMSupply = await cfmm.totalSupply();
      const lpTokenBal = ONE.mul(100);
      const borrowedInvariant = ONE.mul(200);
      await (
        await strategy.setLPTokenBalAndBorrowedInv(
          lpTokenBal,
          borrowedInvariant
        )
      ).wait();
      await (await strategy.testUpdateIndex()).wait();

      const fields = await strategy.getUpdateIndexFields();
      expect(fields.lastCFMMTotalSupply).to.equal(totalCFMMSupply);
      expect(fields.lastCFMMInvariant).to.equal(cfmmInvariant);
      expect(fields.lastCFMMFeeIndex).to.equal(ONE);
      expect(fields.lastFeeIndex).to.gt(ONE);
      expect(fields.accFeeIndex).to.equal(fields.lastFeeIndex); // first update
      expect(fields.borrowedInvariant).to.gt(borrowedInvariant);
      expect(fields.lpInvariant).to.equal(
        cfmmInvariant.mul(lpTokenBal).div(totalCFMMSupply)
      );
      const borrowedLPTokens = borrowedInvariant
        .mul(totalCFMMSupply)
        .div(cfmmInvariant);
      expect(fields.lpTokenBorrowedPlusInterest).to.gt(borrowedLPTokens);
      expect(fields.lpTokenBal).to.equal(lpTokenBal);
      expect(fields.lpTokenTotal).gt(lpTokenBal.add(borrowedLPTokens));

      const latestBlock = await ethers.provider.getBlock("latest");
      const expBlockNumber = BigNumber.from(latestBlock.number);
      expect(fields.lastBlockNumber).to.equal(expBlockNumber);
    });

    it("Update Index, only time passes by", async function () {
      await execFirstUpdateIndex();
      const fields0 = await strategy.getUpdateIndexFields();

      // only time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      await (await strategy.testUpdateIndex()).wait();

      const fields1 = await strategy.getUpdateIndexFields();
      expect(fields1.lastBlockNumber).to.gt(fields0.lastBlockNumber);
      expect(fields1.lastFeeIndex).to.gt(fields0.lastFeeIndex);
      expect(fields1.borrowedInvariant).to.gt(fields0.borrowedInvariant);
      expect(fields1.lpTokenBorrowedPlusInterest).to.gt(
        fields0.lpTokenBorrowedPlusInterest
      );
      expect(fields1.lpTokenTotal).to.gt(fields0.lpTokenTotal);
      expect(fields1.totalInvariant).to.gt(fields0.totalInvariant);
      expect(fields1.accFeeIndex).to.gt(fields0.accFeeIndex);

      expect(fields1.lpInvariant).to.equal(fields0.lpInvariant);
      expect(fields1.lastCFMMInvariant).to.equal(fields0.lastCFMMInvariant);
      expect(fields1.lastCFMMFeeIndex).to.equal(fields0.lastCFMMFeeIndex);
      expect(fields1.lastCFMMTotalSupply).to.equal(fields0.lastCFMMTotalSupply);
      expect(fields1.lpTokenBal).to.equal(fields0.lpTokenBal);
    });

    it("Update Index, only trades happen", async function () {
      await execFirstUpdateIndex();
      const fields0 = await strategy.getUpdateIndexFields();

      // only trades happen
      const latestBlock = await ethers.provider.getBlock("latest");
      const cfmmInvariant = await strategy.invariant();
      await (await strategy.setInvariant(cfmmInvariant.mul(2))).wait();
      await (await strategy.setLastBlockNumber(latestBlock.number + 3)).wait(); // +3 because updates took 2 blocks
      const lastBlockNum = await strategy.getLastBlockNumber();
      await (await strategy.testUpdateIndex()).wait();

      const fields1 = await strategy.getUpdateIndexFields();
      const latestBlock1 = await ethers.provider.getBlock("latest");
      const expBlockNumber1 = BigNumber.from(latestBlock1.number);
      expect(expBlockNumber1).to.equal(lastBlockNum);
      expect(fields1.lastBlockNumber).to.equal(expBlockNumber1);
      expect(fields1.lastCFMMInvariant).to.gt(fields0.lastCFMMInvariant);
      expect(fields1.lastCFMMFeeIndex).to.gt(fields0.lastCFMMFeeIndex);
      expect(fields1.lastFeeIndex).to.eq(BigNumber.from(10).pow(18));
      expect(fields1.borrowedInvariant).to.eq(fields0.borrowedInvariant);
      expect(fields1.lpInvariant).to.gt(fields0.lpInvariant);
      expect(fields1.accFeeIndex).to.eq(fields0.accFeeIndex);
      expect(fields1.totalInvariant).to.gt(fields0.totalInvariant);
      expect(fields1.lpTokenBorrowedPlusInterest).to.equal(
        fields0.lpTokenBorrowedPlusInterest.div(2) // You end up with less LP Tokens than you started with
      );
      expect(fields1.lpTokenTotal).to.equal(
        fields0.lpTokenTotal.sub(fields0.lpTokenBorrowedPlusInterest.div(2))
      );
      expect(fields1.lpTokenBal).to.equal(fields0.lpTokenBal);
      expect(fields1.lastCFMMTotalSupply).to.equal(fields0.lastCFMMTotalSupply);
    });

    it("Update Index, trades happen & time passes by", async function () {
      await execFirstUpdateIndex();
      const fields0 = await strategy.getUpdateIndexFields();

      // trades happen
      const cfmmInvariant = await strategy.invariant();
      await (
        await strategy.setInvariant(cfmmInvariant.add(cfmmInvariant.div(10000)))
      ).wait();

      // time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      await (await strategy.testUpdateIndex()).wait();

      const fields1 = await strategy.getUpdateIndexFields();
      expect(fields1.lastBlockNumber).to.gt(fields0.lastBlockNumber);
      expect(fields1.lastCFMMInvariant).to.gt(fields0.lastCFMMInvariant);
      expect(fields1.lastCFMMFeeIndex).to.gt(fields0.lastCFMMFeeIndex);
      expect(fields1.lastFeeIndex).to.gt(fields0.lastFeeIndex);
      expect(fields1.borrowedInvariant).to.gt(fields0.borrowedInvariant);
      expect(fields1.lpInvariant).to.gt(fields0.lpInvariant);
      expect(fields1.accFeeIndex).to.gt(fields0.accFeeIndex);
      expect(fields1.totalInvariant).to.gt(fields0.totalInvariant);
      expect(fields1.lpTokenBorrowedPlusInterest).to.gt(
        fields0.lpTokenBorrowedPlusInterest
      );
      expect(fields1.lpTokenTotal).to.gt(fields0.lpTokenTotal);
      expect(fields1.lpTokenBal).to.equal(fields0.lpTokenBal);
      expect(fields1.lastCFMMTotalSupply).to.equal(fields0.lastCFMMTotalSupply);
    });

    it("Update Index, only deposits outside GS", async function () {
      await execFirstUpdateIndex();
      const fields0 = await strategy.getUpdateIndexFields();

      // only trades happen
      const latestBlock = await ethers.provider.getBlock("latest");
      const cfmmInvariant = await strategy.invariant();
      await (await strategy.setInvariant(cfmmInvariant.mul(2))).wait(); // we double the CFMM invariant
      const totalCFMMSupply = await cfmm.totalSupply();
      await (await cfmm.mint(totalCFMMSupply, owner.address)).wait(); // we double the CFMM shares

      await (await strategy.setLastBlockNumber(latestBlock.number + 4)).wait(); // +4 because updates took 3 blocks
      const lastBlockNum = await strategy.getLastBlockNumber();

      await (await strategy.testUpdateIndex()).wait();

      const fields1 = await strategy.getUpdateIndexFields();
      const latestBlock1 = await ethers.provider.getBlock("latest");
      const expBlockNumber1 = BigNumber.from(latestBlock1.number);
      expect(expBlockNumber1).to.equal(lastBlockNum);
      expect(fields1.lastBlockNumber).to.equal(expBlockNumber1);
      expect(fields1.lastCFMMFeeIndex).to.equal(fields0.lastCFMMFeeIndex);
      expect(fields1.lastFeeIndex).to.lt(fields0.lastFeeIndex);
      expect(fields1.lastFeeIndex).to.equal(BigNumber.from(10).pow(18));
      expect(fields1.borrowedInvariant).to.equal(fields0.borrowedInvariant);
      expect(fields1.lpInvariant).to.equal(fields0.lpInvariant);
      expect(fields1.accFeeIndex).to.equal(fields0.accFeeIndex);
      expect(fields1.totalInvariant).to.equal(fields0.totalInvariant);
      expect(fields1.lpTokenBorrowedPlusInterest).to.equal(
        fields0.lpTokenBorrowedPlusInterest
      );
      expect(fields1.lpTokenTotal).to.equal(fields0.lpTokenTotal);
      expect(fields1.lpTokenBal).to.equal(fields0.lpTokenBal);
      expect(fields1.lastCFMMInvariant).to.gt(fields0.lastCFMMInvariant);
      expect(fields1.lastCFMMTotalSupply).to.gt(fields0.lastCFMMTotalSupply);
    });

    it("Update Index, only withdrawals outside GS", async function () {
      await execFirstUpdateIndex();
      const fields0 = await strategy.getUpdateIndexFields();

      // only trades happen
      const latestBlock = await ethers.provider.getBlock("latest");
      const cfmmInvariant = await strategy.invariant();
      await (await strategy.setInvariant(cfmmInvariant.div(2))).wait(); // we half the CFMM invariant
      const ownerBalance = await cfmm.balanceOf(owner.address); // owner has half the total CFMM supply
      await (await cfmm.burn(ownerBalance, owner.address)).wait(); // we half the CFMM shares

      await (await strategy.setLastBlockNumber(latestBlock.number + 4)).wait(); // +4 because updates took 3 blocks
      const lastBlockNum = await strategy.getLastBlockNumber();

      await (await strategy.testUpdateIndex()).wait();

      const fields1 = await strategy.getUpdateIndexFields();
      const latestBlock1 = await ethers.provider.getBlock("latest");
      const expBlockNumber1 = BigNumber.from(latestBlock1.number);
      expect(expBlockNumber1).to.equal(lastBlockNum);
      expect(fields1.lastBlockNumber).to.equal(expBlockNumber1);
      expect(fields1.lastCFMMFeeIndex).to.equal(fields0.lastCFMMFeeIndex);
      expect(fields1.lastFeeIndex).to.lt(fields0.lastFeeIndex);
      expect(fields1.lastFeeIndex).to.equal(BigNumber.from(10).pow(18));
      expect(fields1.borrowedInvariant).to.equal(fields0.borrowedInvariant);
      expect(fields1.lpInvariant).to.equal(fields0.lpInvariant);
      expect(fields1.accFeeIndex).to.equal(fields0.accFeeIndex);
      expect(fields1.totalInvariant).to.equal(fields0.totalInvariant);
      expect(fields1.lpTokenBorrowedPlusInterest).to.equal(
        fields0.lpTokenBorrowedPlusInterest
      );
      expect(fields1.lpTokenTotal).to.equal(fields0.lpTokenTotal);
      expect(fields1.lpTokenBal).to.equal(fields0.lpTokenBal);
      expect(fields1.lastCFMMInvariant).to.lt(fields0.lastCFMMInvariant);
      expect(fields1.lastCFMMTotalSupply).to.lt(fields0.lastCFMMTotalSupply);
    });

    it("Update Index, only deposits inside GS", async function () {
      await execFirstUpdateIndex();
      const fields0 = await strategy.getUpdateIndexFields();

      // only trades happen
      const latestBlock = await ethers.provider.getBlock("latest");
      const cfmmInvariant = await strategy.invariant();
      await (await strategy.setInvariant(cfmmInvariant.mul(2))).wait(); // we double the CFMM invariant
      const totalCFMMSupply = await cfmm.totalSupply();
      await (await cfmm.mint(totalCFMMSupply, strategy.address)).wait(); // we double the CFMM shares
      const resp = await strategy.getLPTokenBalAndBorrowedInv();
      await (
        await strategy.setLPTokenBalAndBorrowedInv(
          resp.lpTokenBal.add(totalCFMMSupply),
          resp.borrowedInv
        )
      ).wait();

      await (await strategy.setLastBlockNumber(latestBlock.number + 5)).wait(); // +5 because updates took 4 blocks
      const lastBlockNum = await strategy.getLastBlockNumber();

      await (await strategy.testUpdateIndex()).wait();

      const fields1 = await strategy.getUpdateIndexFields();
      const latestBlock1 = await ethers.provider.getBlock("latest");
      const expBlockNumber1 = BigNumber.from(latestBlock1.number);
      expect(expBlockNumber1).to.equal(lastBlockNum);
      expect(fields1.lastBlockNumber).to.equal(expBlockNumber1);
      expect(fields1.lastCFMMFeeIndex).to.equal(fields0.lastCFMMFeeIndex);
      expect(fields1.lastFeeIndex).to.lt(fields0.lastFeeIndex);
      expect(fields1.lastFeeIndex).to.equal(BigNumber.from(10).pow(18));
      expect(fields1.borrowedInvariant).to.equal(fields0.borrowedInvariant);
      expect(fields1.lpInvariant).to.equal(
        fields0.lpInvariant.add(cfmmInvariant)
      );
      expect(fields1.accFeeIndex).to.equal(fields0.accFeeIndex);
      expect(fields1.totalInvariant).to.equal(
        fields0.totalInvariant.add(cfmmInvariant)
      );
      expect(fields1.lpTokenBorrowedPlusInterest).to.equal(
        fields0.lpTokenBorrowedPlusInterest
      );
      expect(fields1.lpTokenTotal).to.equal(
        fields0.lpTokenTotal.add(totalCFMMSupply)
      );
      expect(fields1.lpTokenBal).to.equal(
        fields0.lpTokenBal.add(totalCFMMSupply)
      );
      expect(fields1.lastCFMMInvariant).to.equal(
        fields0.lastCFMMInvariant.add(cfmmInvariant)
      );
      expect(fields1.lastCFMMTotalSupply).to.equal(
        fields0.lastCFMMTotalSupply.add(totalCFMMSupply)
      );
    });

    it("Update Index, only withdrawals inside GS", async function () {
      await execFirstUpdateIndex();
      const fields0 = await strategy.getUpdateIndexFields();

      // only trades happen
      const latestBlock = await ethers.provider.getBlock("latest");
      const cfmmInvariant = await strategy.invariant();
      await (await strategy.setInvariant(cfmmInvariant.mul(3).div(4))).wait(); // we quarter the CFMM invariant
      const gsBalance = await cfmm.balanceOf(strategy.address); // GS has half the total CFMM supply
      await (await cfmm.burn(gsBalance.div(2), strategy.address)).wait(); // we quarter the CFMM shares (half GS Balance)

      const resp = await strategy.getLPTokenBalAndBorrowedInv();
      await (
        await strategy.setLPTokenBalAndBorrowedInv(
          resp.lpTokenBal.div(2),
          resp.borrowedInv
        )
      ).wait();

      await (await strategy.setLastBlockNumber(latestBlock.number + 5)).wait(); // +5 because updates took 4 blocks
      const lastBlockNum = await strategy.getLastBlockNumber();

      await (await strategy.testUpdateIndex()).wait();

      const fields1 = await strategy.getUpdateIndexFields();
      const latestBlock1 = await ethers.provider.getBlock("latest");
      const expBlockNumber1 = BigNumber.from(latestBlock1.number);
      expect(expBlockNumber1).to.equal(lastBlockNum);
      expect(fields1.lastBlockNumber).to.equal(expBlockNumber1);
      expect(fields1.lastCFMMFeeIndex).to.equal(fields0.lastCFMMFeeIndex);
      expect(fields1.lastFeeIndex).to.lt(fields0.lastFeeIndex);
      expect(fields1.lastFeeIndex).to.equal(BigNumber.from(10).pow(18));
      expect(fields1.borrowedInvariant).to.equal(fields0.borrowedInvariant);
      expect(fields1.lpInvariant).to.equal(fields0.lpInvariant.div(2));
      expect(fields1.accFeeIndex).to.equal(fields0.accFeeIndex);
      expect(fields1.totalInvariant).to.equal(
        fields0.totalInvariant.sub(fields0.lpInvariant.div(2))
      );
      expect(fields1.lpTokenBorrowedPlusInterest).to.equal(
        fields0.lpTokenBorrowedPlusInterest
      );
      expect(fields1.lpTokenTotal).to.equal(
        fields0.lpTokenTotal.sub(resp.lpTokenBal.div(2))
      );
      expect(fields1.lpTokenBal).to.equal(fields0.lpTokenBal.div(2));
      expect(fields1.lastCFMMInvariant).to.equal(
        fields0.lastCFMMInvariant.mul(3).div(4)
      );
      expect(fields1.lastCFMMTotalSupply).to.equal(
        fields0.lastCFMMTotalSupply.mul(3).div(4)
      );
    });

    it("Update Index, increase debt", async function () {
      await execFirstUpdateIndex();
      const fields0 = await strategy.getUpdateIndexFields();

      // only trades happen
      const latestBlock = await ethers.provider.getBlock("latest");
      const cfmmInvariant = await strategy.invariant();
      await (await strategy.setInvariant(cfmmInvariant.mul(3).div(4))).wait(); // we quarter the CFMM invariant
      const gsBalance = await cfmm.balanceOf(strategy.address); // GS has half the total CFMM supply
      await (await cfmm.burn(gsBalance.div(2), strategy.address)).wait(); // we quarter the CFMM shares (half GS Balance)

      const resp = await strategy.getLPTokenBalAndBorrowedInv();
      await (
        await strategy.setLPTokenBalAndBorrowedInv(
          resp.lpTokenBal.div(2),
          resp.borrowedInv.add(cfmmInvariant.mul(1).div(4))
        )
      ).wait();

      await (await strategy.setLastBlockNumber(latestBlock.number + 5)).wait(); // +5 because updates took 4 blocks
      const lastBlockNum = await strategy.getLastBlockNumber();

      await (await strategy.testUpdateIndex()).wait();

      const fields1 = await strategy.getUpdateIndexFields();
      const latestBlock1 = await ethers.provider.getBlock("latest");
      const expBlockNumber1 = BigNumber.from(latestBlock1.number);
      expect(expBlockNumber1).to.equal(lastBlockNum);
      expect(fields1.lastBlockNumber).to.equal(expBlockNumber1);
      expect(fields1.lastCFMMFeeIndex).to.equal(fields0.lastCFMMFeeIndex);
      expect(fields1.lastFeeIndex).to.lt(fields0.lastFeeIndex);
      expect(fields1.lastFeeIndex).to.equal(BigNumber.from(10).pow(18));
      expect(fields1.borrowedInvariant).to.equal(
        fields0.borrowedInvariant.add(cfmmInvariant.mul(1).div(4))
      );
      expect(fields1.lpInvariant).to.equal(fields0.lpInvariant.div(2));
      expect(fields1.accFeeIndex).to.equal(fields0.accFeeIndex);
      expect(fields1.totalInvariant).to.equal(fields0.totalInvariant);
      expect(fields1.lpTokenBorrowedPlusInterest).to.equal(
        fields0.lpTokenBorrowedPlusInterest.add(resp.lpTokenBal.div(2))
      );
      expect(fields1.lpTokenTotal).to.equal(fields0.lpTokenTotal);
      expect(fields1.lpTokenBal).to.equal(fields0.lpTokenBal.div(2));
      expect(fields1.lastCFMMInvariant).to.equal(
        fields0.lastCFMMInvariant.mul(3).div(4)
      );
      expect(fields1.lastCFMMTotalSupply).to.equal(
        fields0.lastCFMMTotalSupply.mul(3).div(4)
      );
    });

    it("Update Index, pay debt", async function () {
      await execFirstUpdateIndex();
      const fields0 = await strategy.getUpdateIndexFields();

      // only trades happen
      const latestBlock = await ethers.provider.getBlock("latest");
      const cfmmInvariant = await strategy.invariant();
      const ONE = BigNumber.from(10).pow(18);
      const paidInvariant = ONE.mul(50);
      const paidShares = ONE.mul(10);
      await (
        await strategy.setInvariant(cfmmInvariant.add(paidInvariant))
      ).wait(); // we quarter the CFMM invariant
      await (await cfmm.mint(paidShares, strategy.address)).wait(); // we quarter the CFMM shares (half GS Balance)

      const resp = await strategy.getLPTokenBalAndBorrowedInv();
      await (
        await strategy.setLPTokenBalAndBorrowedInv(
          resp.lpTokenBal.add(paidShares),
          resp.borrowedInv.sub(paidInvariant)
        )
      ).wait();

      await (await strategy.setLastBlockNumber(latestBlock.number + 5)).wait(); // +5 because updates took 4 blocks
      const lastBlockNum = await strategy.getLastBlockNumber();

      await (await strategy.testUpdateIndex()).wait();

      const fields1 = await strategy.getUpdateIndexFields();
      const latestBlock1 = await ethers.provider.getBlock("latest");
      const expBlockNumber1 = BigNumber.from(latestBlock1.number);
      expect(expBlockNumber1).to.equal(lastBlockNum);
      expect(fields1.lastBlockNumber).to.equal(expBlockNumber1);
      expect(fields1.lastCFMMFeeIndex).to.equal(fields0.lastCFMMFeeIndex);
      expect(fields1.lastFeeIndex).to.lt(fields0.lastFeeIndex);
      expect(fields1.lastFeeIndex).to.equal(ONE);
      expect(fields1.borrowedInvariant).to.equal(
        fields0.borrowedInvariant.sub(paidInvariant)
      );
      expect(fields1.lpInvariant).to.equal(
        fields0.lpInvariant.add(paidInvariant)
      );
      expect(fields1.accFeeIndex).to.equal(fields0.accFeeIndex);
      expect(fields1.totalInvariant).to.equal(fields0.totalInvariant);
      expect(fields1.lpTokenBorrowedPlusInterest).to.equal(
        fields0.lpTokenBorrowedPlusInterest.sub(paidShares)
      );
      expect(fields1.lpTokenTotal).to.equal(fields0.lpTokenTotal);
      expect(fields1.lpTokenBal).to.equal(fields0.lpTokenBal.add(paidShares));
      expect(fields1.lastCFMMInvariant).to.equal(
        fields0.lastCFMMInvariant.add(paidInvariant)
      );
      expect(fields1.lastCFMMTotalSupply).to.equal(
        fields0.lastCFMMTotalSupply.add(paidShares)
      );
    });
  });

  describe("mintToDevs", function () {
    const sqrt = (y: BigNumber) => {
      let z;
      if (y.gt(3)) {
        z = y;
        let x = y.div(2).add(1);
        while (x.lt(z)) {
          z = x;
          x = y.div(x).add(x).div(2);
        }
      } else if (!y.isZero()) {
        z = BigNumber.from(1);
      }
      return z;
    };

    it("Mints to Dev Address", async () => {
      // setup
      const ONE = BigNumber.from(10).pow(18);
      await (await tokenA.transfer(cfmm.address, ONE.mul(500))).wait();
      await (await tokenB.transfer(cfmm.address, ONE.mul(1000))).wait();
      await (await cfmm.mint(ONE.mul(4), strategy.address)).wait();
      await (
        await strategy.setUpdateStoreFields(
          ONE.mul(10),
          ONE.mul(20),
          ONE.mul(30),
          ONE.mul(40),
          ONE.mul(50),
          ONE.mul(60)
        )
      ).wait();
      await (await strategy.testMint(owner.address, ONE.mul(2))).wait();

      // beginning balance of addr1
      await (await strategy.testMint(addr1.address, "123456")).wait();

      // set the address before minting
      await (await factory.setFeeTo(addr1.address)).wait();
      await (await factory.setFee(10000)).wait();

      // need premint values to calculate minted amount
      const reserves = await cfmm.getReserves();
      const uniInvariant = sqrt(reserves[0].div(150).mul(reserves[1].div(150)));
      await strategy.setInvariant(uniInvariant);
      const totalPoolSharesSupply0 = await strategy.totalSupply();
      const fields0 = await strategy.getUpdateIndexFields();

      await ethers.provider.send("hardhat_mine", ["0x10000"]);

      await (await strategy.testUpdateIndex()).wait();

      // compare borrowedInvariant and no new shares issued
      const fields1 = await strategy.getUpdateIndexFields();
      expect(fields1.borrowedInvariant.gt(fields0.borrowedInvariant)).to.equal(
        true
      );

      const totalPoolSharesSupply1 = await strategy.totalSupply();
      expect(totalPoolSharesSupply1).to.gt(totalPoolSharesSupply0);

      const devFee = await factory.fee();

      const gsFeeIndex = fields1.lastFeeIndex.gt(fields1.lastCFMMFeeIndex)
        ? fields1.lastFeeIndex.sub(fields1.lastCFMMFeeIndex)
        : ethers.constants.Zero;
      const protFee = gsFeeIndex.mul(devFee).div(100000);
      const lastFeeIndexAdj = fields1.lastFeeIndex.sub(protFee);
      const utilrate = ONE.div(2);
      const utilRateComplement = ONE.sub(utilrate);

      const lastCFMMIndexWeighted =
        fields1.lastCFMMFeeIndex.mul(utilRateComplement);
      const numerator = fields1.lastFeeIndex
        .mul(utilrate)
        .add(lastCFMMIndexWeighted)
        .div(ONE);
      const denominator = lastFeeIndexAdj
        .mul(utilrate)
        .add(lastCFMMIndexWeighted)
        .div(ONE);

      const pctToPrint = numerator.mul(ONE).div(denominator).sub(ONE);
      const devShares = pctToPrint.gt(0)
        ? totalPoolSharesSupply0.mul(pctToPrint).div(ONE)
        : ethers.constants.Zero;
      expect(totalPoolSharesSupply1.sub(totalPoolSharesSupply0)).to.eq(
        devShares
      );
      expect(devShares).to.gt(0);
    });
  });
});
