import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe("RebalanceStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let TestFactory: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let strategy: any;
  let factory: any;
  let owner: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCFMM = await ethers.getContractFactory("TestCFMM");
    TestStrategy = await ethers.getContractFactory("TestRebalanceStrategy");
    TestFactory = await ethers.getContractFactory("TestGammaPoolFactory2");
    [owner] = await ethers.getSigners();

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    cfmm = await TestCFMM.deploy(
      tokenA.address,
      tokenB.address,
      "Test CFMM",
      "TCFMM"
    );

    factory = await TestFactory.deploy();
    strategy = await TestStrategy.deploy();
    await (
      await strategy.initialize(
        factory.address,
        cfmm.address,
        PROTOCOL_ID,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();
  });

  function checkEventData(
    event: any,
    tokenId: BigNumber,
    tokenHeld1: any,
    tokenHeld2: any,
    liquidity: any,
    lpTokens: any,
    rateIndex: any
  ) {
    expect(event.event).to.equal("LoanUpdated");
    expect(event.args.tokenId).to.equal(tokenId);
    expect(event.args.tokensHeld.length).to.equal(2);
    expect(event.args.tokensHeld[0]).to.equal(tokenHeld1);
    expect(event.args.tokensHeld[1]).to.equal(tokenHeld2);
    expect(event.args.liquidity).to.equal(liquidity);
    expect(event.args.lpTokens).to.equal(lpTokens);
    expect(event.args.rateIndex).to.equal(rateIndex);
  }

  function checkPoolEventData(
    event: any,
    lpTokenBalance: any,
    lpTokenBorrowed: any,
    lpTokenBorrowedPlusInterest: any,
    lpInvariant: any,
    borrowedInvariant: any,
    txType: any
  ) {
    expect(event.event).to.equal("PoolUpdated");
    expect(event.args.lpTokenBalance).to.equal(lpTokenBalance);
    expect(event.args.lpTokenBorrowed).to.equal(lpTokenBorrowed);
    expect(event.args.lpTokenBorrowedPlusInterest).to.equal(
      lpTokenBorrowedPlusInterest
    );
    expect(event.args.lpInvariant).to.equal(lpInvariant);
    expect(event.args.borrowedInvariant).to.equal(borrowedInvariant);
    expect(event.args.txType).to.equal(txType);
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Check Init Params", async function () {
      const tokens = await strategy.tokens();
      expect(tokens.length).to.equal(2);
      expect(tokens[0]).to.equal(tokenA.address);
      expect(tokens[1]).to.equal(tokenB.address);

      const tokenBalances = await strategy.tokenBalances();
      expect(tokenBalances.length).to.equal(2);
      expect(tokenBalances[0]).to.equal(0);
      expect(tokenBalances[1]).to.equal(0);
    });
  });

  describe("Update Pool", function () {
    it("Update Pool", async function () {
      // time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      await (await strategy.testUpdateIndex()).wait();

      // updateLoanLiquidity
      const res = await (await strategy.createLoan()).wait();
      expect(res.events[0].args.caller).to.equal(owner.address);
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const loan = await strategy.getLoan(tokenId);
      expect(loan.id).to.equal(1);
      expect(loan.poolId).to.equal(strategy.address);
      expect(loan.tokensHeld.length).to.equal(2);
      expect(loan.tokensHeld[0]).to.equal(0);
      expect(loan.tokensHeld[1]).to.equal(0);
      expect(loan.liquidity).to.equal(0);
      expect(loan.lpTokens).to.equal(0);
      const accFeeIndex = await strategy.getAccFeeIndex();
      expect(loan.rateIndex).to.equal(accFeeIndex);

      const liquidity = ONE.mul(100);
      await (await strategy.setLoanLiquidity(tokenId, liquidity)).wait();

      await (await strategy.setBorrowRate(ONE.mul(2))).wait();
      // time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      const _data = await strategy.getPoolData();
      expect(_data.accFeeIndex).to.gt(ONE);

      const resp = await (await strategy._updatePool(0)).wait();
      const _data1 = await strategy.getPoolData();
      expect(resp.events.length).to.eq(1);
      expect(resp.events[0].event).to.equal("PoolUpdated");
      expect(resp.events[0].args.accFeeIndex).to.gt(_data.accFeeIndex);
      expect(resp.events[0].args.accFeeIndex).to.eq(_data1.accFeeIndex);
      expect(resp.events[0].args.txType).to.eq(17);
      expect(_data1.accFeeIndex).to.gt(_data.accFeeIndex);
    });

    it("Update Pool with Loan", async function () {
      // time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      await (await strategy.testUpdateIndex()).wait();

      // updateLoanLiquidity
      const res = await (await strategy.createLoan()).wait();
      expect(res.events[0].args.caller).to.equal(owner.address);
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const loan = await strategy.getLoan(tokenId);
      expect(loan.id).to.equal(1);
      expect(loan.poolId).to.equal(strategy.address);
      expect(loan.tokensHeld.length).to.equal(2);
      expect(loan.tokensHeld[0]).to.equal(0);
      expect(loan.tokensHeld[1]).to.equal(0);
      expect(loan.liquidity).to.equal(0);
      expect(loan.lpTokens).to.equal(0);
      const accFeeIndex = await strategy.getAccFeeIndex();
      expect(loan.rateIndex).to.equal(accFeeIndex);

      const liquidity = ONE.mul(100);
      await (await strategy.setLoanLiquidity(tokenId, liquidity)).wait();

      await (await strategy.setBorrowRate(ONE.mul(2))).wait();
      // time passes by
      // mine 256 blocks
      await ethers.provider.send("hardhat_mine", ["0x100"]);

      const _data = await strategy.getPoolData();
      expect(_data.accFeeIndex).to.gt(ONE);

      const resp = await (await strategy._updatePool(tokenId)).wait();

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.gt(liquidity);

      const _data1 = await strategy.getPoolData();
      expect(resp.events.length).to.eq(2);
      expect(resp.events[0].event).to.equal("LoanUpdated");
      expect(resp.events[0].args.tokenId).to.eq(tokenId);
      expect(resp.events[0].args.tokensHeld.length).to.eq(2);
      expect(resp.events[0].args.tokensHeld[0]).to.eq(0);
      expect(resp.events[0].args.tokensHeld[1]).to.eq(0);
      expect(resp.events[0].args.liquidity).to.gt(liquidity);
      expect(resp.events[0].args.rateIndex).to.gt(loan.rateIndex);
      expect(resp.events[0].args.initLiquidity).to.eq(0);
      expect(resp.events[0].args.lpTokens).to.eq(0);
      expect(resp.events[0].args.txType).to.eq(17);

      expect(resp.events[1].event).to.equal("PoolUpdated");
      expect(resp.events[1].args.accFeeIndex).to.gt(_data.accFeeIndex);
      expect(resp.events[1].args.accFeeIndex).to.eq(_data1.accFeeIndex);
      expect(resp.events[1].args.txType).to.eq(17);
      expect(_data1.accFeeIndex).to.gt(_data.accFeeIndex);
    });
  });

  describe("Rebalance Collateral", function () {
    it("Error rebalance, > margin", async function () {
      const ONE = BigNumber.from(10).pow(18);

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const amtA = ONE.mul(2);
      const amtB = ONE.mul(4);

      await (await tokenA.transfer(strategy.address, amtA)).wait();
      await (await tokenB.transfer(strategy.address, amtB)).wait();

      await (await strategy._increaseCollateral(tokenId, [])).wait();
      await (await strategy.setBorrowRate(ONE)).wait();

      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const loanLiquidity = ONE.mul(20);
      const loanLPTokens = ONE.mul(10);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);

      await (
        await strategy.setLPTokenLoanBalance(
          tokenId,
          startLiquidity,
          startLpTokens,
          loanLiquidity,
          loanLPTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const res1a = await strategy.getLoanChangeData(tokenId);
      expect(res1a.loanLiquidity).to.equal(loanLiquidity);
      expect(res1a.loanLpTokens).to.equal(loanLPTokens);
      expect(res1a.borrowedInvariant).to.equal(loanLiquidity);
      expect(res1a.lpInvariant).to.equal(startLiquidity);
      expect(res1a.totalInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res1a.lpTokenBorrowed).to.equal(loanLPTokens);
      expect(res1a.lpTokenBalance).to.equal(startLpTokens);
      expect(res1a.lpTokenBorrowedPlusInterest).to.equal(loanLPTokens);
      expect(res1a.lpTokenTotal).to.equal(startLpTokens.add(loanLPTokens));

      const res1b = await strategy.getLoan(tokenId);
      const heldLiquidity = await strategy.squareRoot(amtA.mul(amtB).div(ONE));
      expect(res1b.poolId).to.equal(strategy.address);
      expect(res1b.tokensHeld[0]).to.equal(amtA);
      expect(res1b.tokensHeld[1]).to.equal(amtB);
      expect(res1b.heldLiquidity).to.equal(heldLiquidity);
      expect(res1b.liquidity).to.equal(loanLiquidity);
      expect(res1b.lpTokens).to.equal(loanLPTokens);

      await expect(
        strategy._rebalanceCollateral(tokenId, [10, 10], [])
      ).to.be.revertedWithCustomError(strategy, "Margin");
    });

    it("Rebalance success", async function () {
      const ONE = BigNumber.from(10).pow(18);

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const amtA = ONE.mul(20);
      const amtB = ONE.mul(40);

      await (await tokenA.transfer(strategy.address, amtA)).wait();
      await (await tokenB.transfer(strategy.address, amtB)).wait();

      await (await strategy._increaseCollateral(tokenId, [])).wait();
      await (await strategy.setBorrowRate(ONE)).wait();

      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const loanLiquidity = ONE.mul(20);
      const loanLPTokens = ONE.mul(10);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);

      await (
        await strategy.setLPTokenLoanBalance(
          tokenId,
          startLiquidity,
          startLpTokens,
          loanLiquidity,
          loanLPTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const res1a = await strategy.getLoanChangeData(tokenId);
      expect(res1a.loanLiquidity).to.equal(loanLiquidity);
      expect(res1a.loanLpTokens).to.equal(loanLPTokens);
      expect(res1a.borrowedInvariant).to.equal(loanLiquidity);
      expect(res1a.lpInvariant).to.equal(startLiquidity);
      expect(res1a.totalInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res1a.lpTokenBorrowed).to.equal(loanLPTokens);
      expect(res1a.lpTokenBalance).to.equal(startLpTokens);
      expect(res1a.lpTokenBorrowedPlusInterest).to.equal(loanLPTokens);
      expect(res1a.lpTokenTotal).to.equal(startLpTokens.add(loanLPTokens));

      const res1b = await strategy.getLoan(tokenId);
      const heldLiquidity = await strategy.squareRoot(amtA.mul(amtB).div(ONE));
      expect(res1b.poolId).to.equal(strategy.address);
      expect(res1b.tokensHeld[0]).to.equal(amtA);
      expect(res1b.tokensHeld[1]).to.equal(amtB);
      expect(res1b.heldLiquidity).to.equal(heldLiquidity);
      expect(res1b.liquidity).to.equal(loanLiquidity);
      expect(res1b.lpTokens).to.equal(loanLPTokens);

      const rebalAmt1 = ONE.mul(10);
      const rebalAmt2 = ethers.constants.Zero;

      let res = await (
        await strategy._rebalanceCollateral(tokenId, [rebalAmt1, rebalAmt2], [])
      ).wait();

      let expAmtA = amtA.add(rebalAmt1);
      let expAmtB = amtB.add(rebalAmt2);

      checkEventData(
        res.events[res.events.length - 2],
        tokenId,
        expAmtA,
        expAmtB,
        loanLiquidity,
        loanLPTokens,
        ONE
      );

      checkPoolEventData(
        res.events[res.events.length - 1],
        startLpTokens,
        loanLPTokens,
        loanLPTokens,
        startLiquidity,
        loanLiquidity,
        6
      );

      const res1c = await strategy.getLoanChangeData(tokenId);
      expect(res1c.loanLiquidity).to.equal(loanLiquidity);
      expect(res1c.loanLpTokens).to.equal(loanLPTokens);
      expect(res1c.borrowedInvariant).to.equal(loanLiquidity);
      expect(res1c.lpInvariant).to.equal(startLiquidity);
      expect(res1c.totalInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res1c.lpTokenBorrowed).to.equal(loanLPTokens);
      expect(res1c.lpTokenBalance).to.equal(startLpTokens);
      expect(res1c.lpTokenBorrowedPlusInterest).to.equal(loanLPTokens);
      expect(res1c.lpTokenTotal).to.equal(startLpTokens.add(loanLPTokens));

      // Rebalance collateral with ratio enabled
      res = await (
        await strategy._rebalanceCollateral(
          tokenId,
          [rebalAmt1, rebalAmt2],
          [1000, 100000]
        )
      ).wait();
      expAmtA = expAmtA.add(0);
      expAmtB = expAmtB.add(100);

      checkEventData(
        res.events[res.events.length - 2],
        tokenId,
        expAmtA,
        expAmtB,
        loanLiquidity,
        loanLPTokens,
        ONE
      );
    });
  });
});
