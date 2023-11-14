import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

describe("ShortStrategySync", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let cfmm: any;
  let strategy: any;
  let owner: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCFMM = await ethers.getContractFactory("TestCFMM");
    TestStrategy = await ethers.getContractFactory("TestShortStrategySync");
    [owner] = await ethers.getSigners();

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");

    cfmm = await TestCFMM.deploy(
      tokenA.address,
      tokenB.address,
      "Test CFMM",
      "TCFMM"
    );

    strategy = await TestStrategy.deploy();
    await (
      await strategy.initialize(
        cfmm.address,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();
  });

  async function checkGSPoolIsEmpty(
    cfmmTotalSupply: BigNumber,
    cfmmTotalInvariant: BigNumber
  ) {
    expect(await strategy.getTotalAssets()).to.equal(0);
    expect(await strategy.totalSupply0()).to.equal(0);
    const params = await strategy.getTotalAssetsParams2();
    expect(params.borrowedInvariant).to.equal(0);
    expect(params.lpBalance).to.equal(0);
    expect(params.lpBorrowed).to.equal(0);
    expect(params.lpTokenTotal).to.equal(0);
    expect(params.lpTokenBorrowedPlusInterest).to.equal(0);
    expect(params.prevCFMMInvariant).to.equal(cfmmTotalInvariant);
    expect(params.prevCFMMTotalSupply).to.equal(cfmmTotalSupply);
  }

  describe("Sync LP Tokens & LP Invariant", function () {
    it("Error No First Deposit", async function () {
      const cfmmBalance0 = await cfmm.balanceOf(strategy.address);
      expect(cfmmBalance0).to.equal(0);

      await (await cfmm.mint(4000, strategy.address)).wait();

      const params2 = await strategy.getTotalAssetsParams2();
      expect(params2.borrowedInvariant).to.equal(0);
      expect(params2.lpBalance).to.equal(0);
      expect(params2.lpBorrowed).to.equal(0);
      expect(params2.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(params2.lpInvariant).to.equal(0);
      expect(params2.tokenBalances.length).to.equal(2);
      expect(params2.tokenBalances[0]).to.equal(0);
      expect(params2.tokenBalances[1]).to.equal(0);

      const cfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(cfmmBalance1).gt(0);

      await expect(strategy._sync()).to.be.revertedWithCustomError(
        strategy,
        "ZeroShares"
      );
    });

    it("Syncing already synced", async function () {
      await (await tokenA.transfer(strategy.address, 1000)).wait();
      await (await tokenB.transfer(strategy.address, 2000)).wait();
      await (await tokenC.transfer(strategy.address, 3000)).wait();

      const tokenABal0 = await tokenA.balanceOf(strategy.address);
      const tokenBBal0 = await tokenB.balanceOf(strategy.address);
      const tokenCBal0 = await tokenC.balanceOf(strategy.address);

      await (await strategy.testUpdateIndex()).wait();
      await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

      expect(await cfmm.totalSupply()).to.equal(0);
      expect(await cfmm.invariant()).to.equal(0);

      const ONE = BigNumber.from(10).pow(18);
      const shares = ONE.mul(200);
      await (await cfmm.mint(shares, owner.address)).wait();

      await (await strategy.testUpdateIndex()).wait();
      await checkGSPoolIsEmpty(shares, shares);

      expect(await cfmm.totalSupply()).to.equal(shares);
      expect(await cfmm.invariant()).to.equal(shares);

      const assets = shares.div(2);
      const params = await strategy.getTotalAssetsParams2();
      expect(params.lpBalance).to.equal(0);

      await (await cfmm.transfer(strategy.address, assets)).wait();

      await (await strategy._depositNoPull(owner.address)).wait();

      const params1 = await strategy.getTotalAssetsParams2();
      expect(params1.borrowedInvariant).to.equal(0);
      expect(params1.lpBalance).to.equal(assets);
      expect(params1.lpBorrowed).to.equal(0);
      expect(params1.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(params1.lpInvariant).to.equal(assets);
      expect(params1.tokenBalances.length).to.equal(2);
      expect(params1.tokenBalances[0]).to.equal(0);
      expect(params1.tokenBalances[1]).to.equal(0);

      const cfmmInvariant0 = await cfmm.invariant();
      const cfmmTotalSupply0 = await cfmm.totalSupply();
      const cfmmBalance0 = await cfmm.balanceOf(strategy.address);
      expect(cfmmBalance0).to.equal(assets);
      expect(cfmmBalance0).to.equal(params1.lpBalance);

      const expectedBorrowedInvariant0 = cfmmBalance0
        .mul(cfmmInvariant0)
        .div(cfmmTotalSupply0);
      expect(params1.lpInvariant).to.equal(expectedBorrowedInvariant0);

      const tradeYield = ONE.mul(10);
      await (await cfmm.trade(tradeYield)).wait();

      await (await strategy._sync()).wait();

      const params2 = await strategy.getTotalAssetsParams2();
      expect(params2.borrowedInvariant).to.equal(0);
      expect(params2.lpBalance).to.equal(assets);
      expect(params2.lpBorrowed).to.equal(0);
      expect(params2.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(params2.lpInvariant).to.equal(assets.add(tradeYield.div(2)));
      expect(params2.tokenBalances.length).to.equal(2);
      expect(params2.tokenBalances[0]).to.equal(0);
      expect(params2.tokenBalances[1]).to.equal(0);

      const cfmmInvariant1 = await cfmm.invariant();
      const cfmmTotalSupply1 = await cfmm.totalSupply();
      const cfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(cfmmBalance1).to.equal(assets);
      expect(cfmmBalance1).to.equal(params2.lpBalance);

      const expectedBorrowedInvariant1 = cfmmBalance1
        .mul(cfmmInvariant1)
        .div(cfmmTotalSupply1);
      expect(params2.lpInvariant).to.equal(expectedBorrowedInvariant1);

      const tokenABal1 = await tokenA.balanceOf(strategy.address);
      const tokenBBal1 = await tokenB.balanceOf(strategy.address);
      const tokenCBal1 = await tokenC.balanceOf(strategy.address);
      expect(tokenABal1).to.equal(tokenABal0);
      expect(tokenBBal1).to.equal(tokenBBal0);
      expect(tokenCBal1).to.equal(tokenCBal0);
    });

    it("Syncing unsynced", async function () {
      await (await tokenA.transfer(strategy.address, 1000)).wait();
      await (await tokenB.transfer(strategy.address, 2000)).wait();
      await (await tokenC.transfer(strategy.address, 3000)).wait();

      const tokenABal0 = await tokenA.balanceOf(strategy.address);
      const tokenBBal0 = await tokenB.balanceOf(strategy.address);
      const tokenCBal0 = await tokenC.balanceOf(strategy.address);

      await (await strategy.testUpdateIndex()).wait();
      await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

      expect(await cfmm.totalSupply()).to.equal(0);
      expect(await cfmm.invariant()).to.equal(0);

      const ONE = BigNumber.from(10).pow(18);
      const shares = ONE.mul(200);
      await (await cfmm.mint(shares, owner.address)).wait();

      await (await strategy.testUpdateIndex()).wait();
      await checkGSPoolIsEmpty(shares, shares);

      expect(await cfmm.totalSupply()).to.equal(shares);
      expect(await cfmm.invariant()).to.equal(shares);

      const assets = shares.div(2);
      const params = await strategy.getTotalAssetsParams2();
      expect(params.lpBalance).to.equal(0);

      await (await cfmm.transfer(strategy.address, assets)).wait();

      await (await strategy._depositNoPull(owner.address)).wait();

      const params1 = await strategy.getTotalAssetsParams2();
      expect(params1.borrowedInvariant).to.equal(0);
      expect(params1.lpBalance).to.equal(assets);
      expect(params1.lpBorrowed).to.equal(0);
      expect(params1.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(params1.lpInvariant).to.equal(assets);
      expect(params1.tokenBalances.length).to.equal(2);
      expect(params1.tokenBalances[0]).to.equal(0);
      expect(params1.tokenBalances[1]).to.equal(0);

      const cfmmInvariant0 = await cfmm.invariant();
      const cfmmTotalSupply0 = await cfmm.totalSupply();
      const cfmmBalance0 = await cfmm.balanceOf(strategy.address);
      expect(cfmmBalance0).to.equal(assets);
      expect(cfmmBalance0).to.equal(params1.lpBalance);

      const expectedBorrowedInvariant0 = cfmmBalance0
        .mul(cfmmInvariant0)
        .div(cfmmTotalSupply0);
      expect(params1.lpInvariant).to.equal(expectedBorrowedInvariant0);

      await (await cfmm.transfer(strategy.address, assets)).wait();

      const tradeYield = ONE.mul(10);
      await (await cfmm.trade(tradeYield)).wait();

      await (await strategy._sync()).wait();

      const params2 = await strategy.getTotalAssetsParams2();
      expect(params2.borrowedInvariant).to.equal(0);
      expect(params2.lpBalance).to.equal(assets.mul(2));
      expect(params2.lpBorrowed).to.equal(0);
      expect(params2.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(params2.lpInvariant).to.equal(assets.mul(2).add(tradeYield));
      expect(params2.tokenBalances.length).to.equal(2);
      expect(params2.tokenBalances[0]).to.equal(0);
      expect(params2.tokenBalances[1]).to.equal(0);

      const cfmmInvariant1 = await cfmm.invariant();
      const cfmmTotalSupply1 = await cfmm.totalSupply();
      const cfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(cfmmBalance1).to.equal(assets.mul(2));
      expect(cfmmBalance1).to.equal(params2.lpBalance);

      const expectedBorrowedInvariant1 = cfmmBalance1
        .mul(cfmmInvariant1)
        .div(cfmmTotalSupply1);
      expect(params2.lpInvariant).to.equal(expectedBorrowedInvariant1);

      const tokenABal1 = await tokenA.balanceOf(strategy.address);
      const tokenBBal1 = await tokenB.balanceOf(strategy.address);
      const tokenCBal1 = await tokenC.balanceOf(strategy.address);
      expect(tokenABal1).to.equal(tokenABal0);
      expect(tokenBBal1).to.equal(tokenBBal0);
      expect(tokenCBal1).to.equal(tokenCBal0);
    });
  });
});
