import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe("LongStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let TestStrategy2: any;
  let TestStrategy3: any;
  let TestFactory: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let strategy: any;
  let strategy2: any;
  let strategy3: any;
  let factory: any;
  let owner: any;
  let addr1: any;
  let addr2: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCFMM = await ethers.getContractFactory("TestCFMM");
    TestStrategy = await ethers.getContractFactory("TestLongStrategy");
    TestStrategy2 = await ethers.getContractFactory("TestRepayStrategy");
    TestStrategy3 = await ethers.getContractFactory("TestBorrowStrategy");
    TestFactory = await ethers.getContractFactory("TestGammaPoolFactory2");
    [owner, addr1, addr2] = await ethers.getSigners();

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

    strategy2 = await TestStrategy2.deploy();
    await (
      await strategy2.initialize(
        factory.address,
        cfmm.address,
        PROTOCOL_ID,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();

    strategy3 = await TestStrategy3.deploy();
    await (
      await strategy3.initialize(
        factory.address,
        cfmm.address,
        PROTOCOL_ID,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();
  });

  async function checkBalancesAndLiquidity(
    tokenId: BigNumber,
    tok1Bal: any,
    tok2Bal: any,
    bal1: any,
    bal2: any,
    tokHeld1: any,
    tokHeld2: any,
    heldLiq: any,
    liq: any
  ) {
    const tokenBalances = await strategy.tokenBalances();
    expect(tokenBalances.length).to.equal(2);
    expect(tokenBalances[0]).to.equal(bal1);
    expect(tokenBalances[1]).to.equal(bal2);

    const loanInfo = await strategy.getLoan(tokenId);
    expect(loanInfo.tokensHeld.length).to.equal(2);
    expect(loanInfo.tokensHeld[0]).to.equal(tokHeld1);
    expect(loanInfo.tokensHeld[1]).to.equal(tokHeld2);
    expect(loanInfo.heldLiquidity).to.equal(heldLiq);
    expect(loanInfo.liquidity).to.equal(liq);

    expect(await tokenA.balanceOf(strategy.address)).to.equal(tok1Bal);
    expect(await tokenB.balanceOf(strategy.address)).to.equal(tok2Bal);
  }

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

  async function checkEventData2(
    event: any,
    tokenId: BigNumber,
    tokenHeld1: any,
    tokenHeld2: any,
    heldLiquidity: any,
    liquidity: any,
    lpTokens: any,
    rateIndex: any
  ) {
    expect(event.event).to.equal("LoanUpdated");
    expect(event.args.tokenId).to.equal(tokenId);
    expect(event.args.tokensHeld.length).to.equal(2);
    expect(event.args.tokensHeld[0]).to.equal(tokenHeld1);
    expect(event.args.tokensHeld[1]).to.equal(tokenHeld2);
    const expectedHeldLiquidity = await strategy.squareRoot(
      tokenHeld1.mul(tokenHeld2).div(BigNumber.from(10).pow(18))
    );
    // expect(event.args.heldLiquidity).to.equal(heldLiquidity);
    expect(expectedHeldLiquidity).to.equal(heldLiquidity);
    expect(event.args.liquidity).to.equal(liquidity);
    expect(event.args.lpTokens).to.equal(lpTokens);
    expect(event.args.rateIndex).to.gt(rateIndex);
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

  async function checkStrategyTokenBalances(bal1: any, bal2: any) {
    const tokenBalances = await strategy.tokenBalances();
    expect(tokenBalances.length).to.equal(2);
    expect(tokenBalances[0]).to.equal(bal1);
    expect(tokenBalances[1]).to.equal(bal2);
    expect(await tokenA.balanceOf(strategy.address)).to.equal(bal1);
    expect(await tokenB.balanceOf(strategy.address)).to.equal(bal2);
  }

  function updateLoanPrice(
    newLiquidity: BigNumber,
    currPrice: BigNumber,
    liquidity: BigNumber,
    lastPx: BigNumber
  ) {
    const totalLiquidity = newLiquidity.add(liquidity);
    const totalLiquidityPx = newLiquidity
      .mul(currPrice)
      .add(liquidity.mul(lastPx));
    return totalLiquidityPx.div(totalLiquidity);
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

  describe("Get Loan & Check Margin", function () {
    it("Create and Get Loan", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      const loanInfo = await strategy.getLoan(tokenId);
      expect(loanInfo.id).to.equal(1);
      expect(loanInfo.poolId).to.equal(strategy.address);
      expect(loanInfo.tokensHeld.length).to.equal(2);
      expect(loanInfo.tokensHeld[0]).to.equal(0);
      expect(loanInfo.tokensHeld[1]).to.equal(0);
      expect(loanInfo.heldLiquidity).to.equal(0);
      expect(loanInfo.initLiquidity).to.equal(0);
      expect(loanInfo.liquidity).to.equal(0);
      expect(loanInfo.lpTokens).to.equal(0);
      expect(loanInfo.rateIndex).to.equal(BigNumber.from(10).pow(18));

      await expect(
        strategy.connect(addr1).getLoan(tokenId)
      ).to.be.revertedWithCustomError(strategy, "Forbidden");
    });

    it("Check Margin", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;
      const ONE = BigNumber.from(10).pow(18);
      const liquidity = ONE.mul(800).div(1000);
      await (await strategy.setLiquidity(tokenId, liquidity)).wait();
      await (await strategy.setHeldAmounts(tokenId, [ONE, ONE])).wait();
      expect(await strategy.checkMargin2(tokenId)).to.equal(true);
      await (await strategy.setLiquidity(tokenId, liquidity.add(1))).wait();
      await expect(
        strategy.checkMargin2(tokenId)
      ).to.be.revertedWithCustomError(strategy, "Margin");
    });
  });

  describe("Update Loan", function () {
    it("Create Loan", async function () {
      const res = await (await strategy.createLoan()).wait();
      expect(res.events[0].args.caller).to.equal(owner.address);
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const accFeeIndex = ONE;
      await checkLoanFields(1, tokenId, accFeeIndex, strategy);

      const accFeeIndex0 = ONE.mul(2);
      await (await strategy.setAccFeeIndex(accFeeIndex0)).wait();
      const res0 = await (await strategy.createLoan()).wait();
      expect(res0.events[0].args.caller).to.equal(owner.address);
      const tokenId0 = res0.events[0].args.tokenId;
      await checkLoanFields(2, tokenId0, accFeeIndex0, strategy);

      const accFeeIndex1 = ONE.mul(3);
      await (await strategy.setAccFeeIndex(accFeeIndex1)).wait();
      const res1 = await (await strategy.createLoan()).wait();
      expect(res1.events[0].args.caller).to.equal(owner.address);
      const tokenId1 = res1.events[0].args.tokenId;
      await checkLoanFields(3, tokenId1, accFeeIndex1, strategy);
    });

    async function checkLoanFields(
      id: number,
      tokenId: BigNumber,
      accFeeIndex: BigNumber,
      strategy: any
    ) {
      const loan = await strategy.getLoan(tokenId);
      expect(loan.id).to.equal(id);
      expect(loan.poolId).to.equal(strategy.address);
      expect(loan.tokensHeld.length).to.equal(2);
      expect(loan.tokensHeld[0]).to.equal(0);
      expect(loan.tokensHeld[1]).to.equal(0);
      expect(loan.liquidity).to.equal(0);
      expect(loan.lpTokens).to.equal(0);
      expect(loan.rateIndex).to.equal(accFeeIndex);
    }

    it("Update Loan Liquidity", async function () {
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
      expect(loan.initLiquidity).to.equal(0);
      expect(loan.liquidity).to.equal(0);
      expect(loan.lpTokens).to.equal(0);
      const accFeeIndex = await strategy.getAccFeeIndex();
      expect(loan.rateIndex).to.equal(accFeeIndex);

      const newLiquidity = ONE.mul(1234);
      await (await strategy.setLoanLiquidity(tokenId, newLiquidity)).wait();
      const loan0 = await strategy.getLoan(tokenId);
      expect(loan0.liquidity).to.equal(newLiquidity);

      const newAccFeeIndex = accFeeIndex.mul(ONE.add(ONE.div(10))).div(ONE);
      await testLoanUpdateLiquidity(tokenId, newAccFeeIndex, loan);

      const newAccFeeIndex0 = newAccFeeIndex.mul(ONE.add(ONE.div(20))).div(ONE);
      await testLoanUpdateLiquidity(tokenId, newAccFeeIndex0, loan);

      const newAccFeeIndex1 = newAccFeeIndex0
        .mul(ONE.add(ONE.div(120)))
        .div(ONE);
      await testLoanUpdateLiquidity(tokenId, newAccFeeIndex1, loan);
    });

    async function testLoanUpdateLiquidity(
      tokenId: BigNumber,
      newAccFeeIndex: BigNumber,
      oldLoan: any
    ) {
      const loan0 = await strategy.getLoan(tokenId);
      expect(loan0.rateIndex).to.lt(newAccFeeIndex);
      expect(loan0.id).to.equal(oldLoan.id);
      expect(loan0.poolId).to.equal(oldLoan.poolId);
      expect(loan0.tokensHeld.length).to.equal(oldLoan.tokensHeld.length);
      expect(loan0.tokensHeld[0]).to.equal(oldLoan.tokensHeld[0]);
      expect(loan0.tokensHeld[1]).to.equal(oldLoan.tokensHeld[1]);
      expect(loan0.lpTokens).to.equal(oldLoan.lpTokens);
      await (
        await strategy.testUpdateLoanLiquidity(tokenId, newAccFeeIndex)
      ).wait();
      const loan = await strategy.getLoan(tokenId);
      expect(loan.liquidity).to.equal(
        updateLoanLiquidity(loan0.liquidity, newAccFeeIndex, loan0.rateIndex)
      );
      expect(loan.liquidity).to.gt(loan0.liquidity);
      expect(loan.rateIndex).to.equal(newAccFeeIndex);
      expect(loan.id).to.equal(oldLoan.id);
      expect(loan.poolId).to.equal(oldLoan.poolId);
      expect(loan.tokensHeld.length).to.equal(oldLoan.tokensHeld.length);
      expect(loan.tokensHeld[0]).to.equal(oldLoan.tokensHeld[0]);
      expect(loan.tokensHeld[1]).to.equal(oldLoan.tokensHeld[1]);
      expect(loan.lpTokens).to.equal(oldLoan.lpTokens);
    }

    function updateLoanLiquidity(
      liquidity: BigNumber,
      accFeeIndex: BigNumber,
      rateIndex: BigNumber
    ): BigNumber {
      return liquidity.mul(accFeeIndex).div(rateIndex);
    }

    it("Update Loan", async function () {
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

      await (await strategy.testUpdateLoan(tokenId)).wait();

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.gt(liquidity);
    });
  });

  describe("Collateral Management", function () {
    it("Check Get Reserves", async function () {
      await (await strategy.setCfmmReserves([100, 200])).wait();
      const reserves = await cfmm.getReserves();
      const res0 = await strategy.testGetReserves(cfmm.address);
      expect(res0[0]).to.eq(reserves[0]);
      expect(res0[1]).to.eq(reserves[1]);
      const res1 = await strategy.testGetReserves(addr1.address);
      expect(res1[0]).to.eq(100);
      expect(res1[1]).to.eq(200);
    });

    it("Get Unfunded Amounts to Withdraw", async function () {
      const res0 = await strategy.testGetUnfundedAmounts(
        [100, 100],
        [100, 100]
      );
      expect(res0.hasUnfundedAmounts).to.eq(false);
      expect(res0.unfundedAmounts.length).to.eq(2);
      expect(res0.unfundedAmounts[0]).to.eq(0);
      expect(res0.unfundedAmounts[1]).to.eq(0);
      expect(res0._tokensHeld[0]).to.eq(0);
      expect(res0._tokensHeld[1]).to.eq(0);

      const res1 = await strategy.testGetUnfundedAmounts(
        [101, 100],
        [100, 100]
      );
      expect(res1.hasUnfundedAmounts).to.eq(true);
      expect(res1.unfundedAmounts.length).to.eq(2);
      expect(res1.unfundedAmounts[0]).to.eq(101);
      expect(res1.unfundedAmounts[1]).to.eq(0);
      expect(res1._tokensHeld[0]).to.eq(100);
      expect(res1._tokensHeld[1]).to.eq(0);

      const res2 = await strategy.testGetUnfundedAmounts(
        [100, 101],
        [100, 100]
      );
      expect(res2.hasUnfundedAmounts).to.eq(true);
      expect(res2.unfundedAmounts.length).to.eq(2);
      expect(res2.unfundedAmounts[0]).to.eq(0);
      expect(res2.unfundedAmounts[1]).to.eq(101);
      expect(res2._tokensHeld[0]).to.eq(0);
      expect(res2._tokensHeld[1]).to.eq(100);

      const res3 = await strategy.testGetUnfundedAmounts(
        [101, 101],
        [100, 100]
      );
      expect(res3.hasUnfundedAmounts).to.eq(true);
      expect(res3.unfundedAmounts.length).to.eq(2);
      expect(res3.unfundedAmounts[0]).to.eq(101);
      expect(res3.unfundedAmounts[1]).to.eq(101);
      expect(res3._tokensHeld[0]).to.eq(100);
      expect(res3._tokensHeld[1]).to.eq(100);

      const res4 = await strategy.testGetUnfundedAmounts([99, 99], [100, 100]);
      expect(res4.hasUnfundedAmounts).to.eq(false);
      expect(res4.unfundedAmounts.length).to.eq(2);
      expect(res4.unfundedAmounts[0]).to.eq(0);
      expect(res4.unfundedAmounts[1]).to.eq(0);
      expect(res4._tokensHeld[0]).to.eq(1);
      expect(res4._tokensHeld[1]).to.eq(1);

      const res5 = await strategy.testGetUnfundedAmounts([101, 99], [100, 100]);
      expect(res5.hasUnfundedAmounts).to.eq(true);
      expect(res5.unfundedAmounts.length).to.eq(2);
      expect(res5.unfundedAmounts[0]).to.eq(101);
      expect(res5.unfundedAmounts[1]).to.eq(0);
      expect(res5._tokensHeld[0]).to.eq(100);
      expect(res5._tokensHeld[1]).to.eq(1);

      const res6 = await strategy.testGetUnfundedAmounts([99, 101], [100, 100]);
      expect(res6.hasUnfundedAmounts).to.eq(true);
      expect(res6.unfundedAmounts.length).to.eq(2);
      expect(res6.unfundedAmounts[0]).to.eq(0);
      expect(res6.unfundedAmounts[1]).to.eq(101);
      expect(res6._tokensHeld[0]).to.eq(1);
      expect(res6._tokensHeld[1]).to.eq(100);
    });

    it("Increase Collateral", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      await checkBalancesAndLiquidity(tokenId, 0, 0, 0, 0, 0, 0, 0, 0);

      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(100);
      const amtB = ONE.mul(400);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      await checkBalancesAndLiquidity(tokenId, amtA, amtB, 0, 0, 0, 0, 0, 0);

      const res1 = await (
        await strategy._increaseCollateral(tokenId, [])
      ).wait();
      checkEventData(res1.events[0], tokenId, amtA, amtB, 0, 0, ONE);

      await checkBalancesAndLiquidity(
        tokenId,
        amtA,
        amtB,
        amtA,
        amtB,
        amtA,
        amtB,
        amtA.mul(2),
        0
      );

      await tokenA.transfer(strategy.address, amtA.mul(3));

      await checkBalancesAndLiquidity(
        tokenId,
        amtB,
        amtB,
        amtA,
        amtB,
        amtA,
        amtB,
        amtA.mul(2),
        0
      );

      const res2 = await (
        await strategy._increaseCollateral(tokenId, [])
      ).wait();
      checkEventData(res2.events[0], tokenId, amtA.mul(4), amtB, 0, 0, ONE);

      await checkBalancesAndLiquidity(
        tokenId,
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        0
      );

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtA);

      await checkBalancesAndLiquidity(
        tokenId,
        amtA.mul(5),
        amtB.add(amtA),
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        amtB,
        amtA.mul(4),
        0
      );

      const res3 = await (
        await strategy._increaseCollateral(tokenId, [])
      ).wait();
      checkEventData(
        res3.events[0],
        tokenId,
        amtA.mul(5),
        amtB.add(amtA),
        0,
        0,
        ONE
      );

      await checkBalancesAndLiquidity(
        tokenId,
        amtA.mul(5),
        amtB.add(amtA),
        amtA.mul(5),
        amtB.add(amtA),
        amtA.mul(5),
        amtB.add(amtA),
        amtA.mul(5),
        0
      );
    });

    it("Decrease Collateral", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(200);
      const amtB = ONE.mul(800);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      const ownerBalA = await tokenA.balanceOf(owner.address);
      const ownerBalB = await tokenB.balanceOf(owner.address);

      const res1 = await (
        await strategy._increaseCollateral(tokenId, [])
      ).wait();
      checkEventData(res1.events[0], tokenId, amtA, amtB, 0, 0, ONE);

      await checkStrategyTokenBalances(amtA, amtB);

      await (await strategy.setBorrowRate(ONE)).wait();

      const res2 = await (
        await strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2), amtB.div(2)],
          owner.address,
          []
        )
      ).wait();

      checkEventData(
        res2.events[res2.events.length - 2],
        tokenId,
        amtA.div(2),
        amtB.div(2),
        0,
        0,
        ONE
      );

      checkPoolEventData(res2.events[res2.events.length - 1], 0, 0, 0, 0, 0, 5);

      expect(await tokenA.balanceOf(owner.address)).to.equal(
        ownerBalA.add(amtA.div(2))
      );
      expect(await tokenB.balanceOf(owner.address)).to.equal(
        ownerBalB.add(amtB.div(2))
      );

      await checkStrategyTokenBalances(amtA.div(2), amtB.div(2));

      await expect(
        strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2).add(1), amtB.div(2)],
          owner.address,
          []
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughCollateral");

      const resp = await (await strategy.createLoan()).wait();
      const tokenId2 = resp.events[0].args.tokenId;

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      await (await strategy._increaseCollateral(tokenId2, [])).wait();

      await expect(
        strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2).add(1), amtB.div(2)],
          owner.address,
          []
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughCollateral");

      await expect(
        strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2), amtB.div(2).add(1)],
          owner.address,
          []
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughCollateral");

      const addr1BalA = await tokenA.balanceOf(addr1.address);
      const addr1BalB = await tokenB.balanceOf(addr1.address);

      const res3 = await (
        await strategy._decreaseCollateral(
          tokenId,
          [amtA.div(4), amtB.div(4)],
          addr1.address,
          []
        )
      ).wait();

      checkEventData(
        res3.events[res3.events.length - 2],
        tokenId,
        amtA.div(4),
        amtB.div(4),
        0,
        0,
        ONE
      );

      checkPoolEventData(res3.events[res3.events.length - 1], 0, 0, 0, 0, 0, 5);

      expect(await tokenA.balanceOf(addr1.address)).to.equal(
        addr1BalA.add(amtA.div(4))
      );
      expect(await tokenB.balanceOf(addr1.address)).to.equal(
        addr1BalB.add(amtB.div(4))
      );

      const res3a = await (
        await strategy._decreaseCollateral(
          tokenId2,
          [amtA, amtB],
          owner.address,
          []
        )
      ).wait();

      checkEventData(
        res3a.events[res3a.events.length - 2],
        tokenId2,
        0,
        0,
        0,
        0,
        ONE
      );

      checkPoolEventData(
        res3a.events[res3a.events.length - 1],
        0,
        0,
        0,
        0,
        0,
        5
      );

      await checkStrategyTokenBalances(amtA.div(4), amtB.div(4));

      await (await strategy.setLiquidity(tokenId, ONE.mul(80))).wait();

      await expect(
        strategy._decreaseCollateral(tokenId, [1, 0], owner.address, [])
      ).to.be.revertedWithCustomError(strategy, "Margin");

      await expect(
        strategy._decreaseCollateral(tokenId, [0, 1], owner.address, [])
      ).to.be.revertedWithCustomError(strategy, "Margin");

      const res4 = await (
        await strategy._decreaseCollateral(tokenId, [0, 0], addr1.address, [])
      ).wait();

      checkEventData(
        res4.events[res4.events.length - 2],
        tokenId,
        amtA.div(4),
        amtB.div(4),
        ONE.mul(80),
        0,
        ONE
      );

      checkPoolEventData(res4.events[res4.events.length - 1], 0, 0, 0, 0, 0, 5);

      expect(await tokenA.balanceOf(addr1.address)).to.equal(
        addr1BalA.add(amtA.div(4))
      );
      expect(await tokenB.balanceOf(addr1.address)).to.equal(
        addr1BalB.add(amtB.div(4))
      );

      await checkStrategyTokenBalances(amtA.div(4), amtB.div(4));

      await (await strategy.setLiquidity(tokenId, ONE.mul(40))).wait();

      const res5 = await (
        await strategy._decreaseCollateral(
          tokenId,
          [amtA.div(8), amtB.div(8)],
          addr1.address,
          []
        )
      ).wait();

      checkEventData(
        res5.events[res5.events.length - 2],
        tokenId,
        amtA.div(8),
        amtB.div(8),
        ONE.mul(40),
        0,
        ONE
      );

      checkPoolEventData(res5.events[res5.events.length - 1], 0, 0, 0, 0, 0, 5);

      expect(await tokenA.balanceOf(addr1.address)).to.equal(
        addr1BalA.add(amtA.div(4)).add(amtA.div(8))
      );
      expect(await tokenB.balanceOf(addr1.address)).to.equal(
        addr1BalB.add(amtB.div(4)).add(amtB.div(8))
      );

      await checkStrategyTokenBalances(amtA.div(8), amtB.div(8));

      await (await strategy.setLiquidity(tokenId, 0)).wait();

      const res6 = await (
        await strategy._decreaseCollateral(
          tokenId,
          [amtA.div(8), amtB.div(8)],
          addr1.address,
          []
        )
      ).wait();

      checkEventData(
        res6.events[res6.events.length - 2],
        tokenId,
        0,
        0,
        0,
        0,
        ONE
      );

      checkPoolEventData(res6.events[res6.events.length - 1], 0, 0, 0, 0, 0, 5);

      expect(await tokenA.balanceOf(addr1.address)).to.equal(
        addr1BalA.add(amtA.div(2))
      );
      expect(await tokenB.balanceOf(addr1.address)).to.equal(
        addr1BalB.add(amtB.div(2))
      );

      await checkStrategyTokenBalances(0, 0);
    });

    it("Decrease Collateral, UpdateIndex", async function () {
      const res = await (await strategy.createLoan()).wait();
      const tokenId = res.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const amtA = ONE.mul(200);
      const amtB = ONE.mul(800);

      await (await strategy.setBorrowRate(ONE)).wait();

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      const ownerBalA = await tokenA.balanceOf(owner.address);
      const ownerBalB = await tokenB.balanceOf(owner.address);

      const res1 = await (
        await strategy._increaseCollateral(tokenId, [])
      ).wait();

      checkEventData(res1.events[0], tokenId, amtA, amtB, 0, 0, ONE);

      await checkStrategyTokenBalances(amtA, amtB);

      await (await strategy.setBorrowRate(ONE.mul(2))).wait();

      const res2 = await (
        await strategy._decreaseCollateral(
          tokenId,
          [amtA.div(2), amtB.div(2)],
          owner.address,
          []
        )
      ).wait();

      await checkEventData2(
        res2.events[res2.events.length - 2],
        tokenId,
        amtA.div(2),
        amtB.div(2),
        amtA,
        0,
        0,
        ONE
      );

      await checkPoolEventData(
        res2.events[res2.events.length - 1],
        0,
        0,
        0,
        0,
        0,
        5
      );

      expect(await tokenA.balanceOf(owner.address)).to.equal(
        ownerBalA.add(amtA.div(2))
      );
      expect(await tokenB.balanceOf(owner.address)).to.equal(
        ownerBalB.add(amtB.div(2))
      );

      await checkStrategyTokenBalances(amtA.div(2), amtB.div(2));
    });
  });

  describe("Calculate Origination Fee", function () {
    it("Calc Orig Fee, utilRate > emaUtilRate, discount > 0", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const twelveDec = BigNumber.from(10).pow(12);
      const emaUtilRate = ONE.mul(80).div(100).div(twelveDec); // 80%
      const borrowedInvariant = ONE.mul(1000);
      const lpInvariant = ONE.mul(1000);

      const liquidityBorrowed = ONE.mul(100);
      const tx = await (
        await strategy3.testCalcOriginationFee(
          2,
          emaUtilRate,
          85,
          65,
          16384,
          liquidityBorrowed.mul(96).div(10),
          borrowedInvariant,
          lpInvariant,
          1000
        )
      ).wait();
      const event = tx.events[tx.events.length - 1];
      expect(event.event).to.eq("DynOrigFee");
      expect(event.args.dynOrigFee).to.eq(4000);
    });

    it("Calc Orig Fee, utilRate > emaUtilRate", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const twelveDec = BigNumber.from(10).pow(12);
      const emaUtilRate = ONE.mul(80).div(100).div(twelveDec); // 80%
      const borrowedInvariant = ONE.mul(1000);
      const lpInvariant = ONE.mul(1000);

      const liquidityBorrowed = ONE.mul(100);
      const tx = await (
        await strategy3.testCalcOriginationFee(
          10,
          emaUtilRate,
          85,
          65,
          16384,
          liquidityBorrowed,
          borrowedInvariant,
          lpInvariant,
          0
        )
      ).wait();
      const event = tx.events[tx.events.length - 1];
      expect(event.event).to.eq("DynOrigFee");
      expect(event.args.dynOrigFee).to.eq(15);

      const tx1 = await (
        await strategy3.testCalcOriginationFee(
          10,
          emaUtilRate,
          85,
          65,
          16384,
          liquidityBorrowed.mul(2),
          borrowedInvariant,
          lpInvariant,
          0
        )
      ).wait();
      const event1 = tx1.events[tx1.events.length - 1];
      expect(event1.event).to.eq("DynOrigFee");
      expect(event1.args.dynOrigFee).to.eq(15);

      const tx2 = await (
        await strategy3.testCalcOriginationFee(
          10,
          emaUtilRate,
          85,
          65,
          16384,
          liquidityBorrowed.mul(5),
          borrowedInvariant,
          lpInvariant,
          0
        )
      ).wait();
      const event2 = tx2.events[tx2.events.length - 1];
      expect(event2.event).to.eq("DynOrigFee");
      expect(event2.args.dynOrigFee).to.eq(15);

      const tx3 = await (
        await strategy3.testCalcOriginationFee(
          10,
          emaUtilRate,
          85,
          65,
          16384,
          liquidityBorrowed.mul(9),
          borrowedInvariant,
          lpInvariant,
          0
        )
      ).wait();
      const event3 = tx3.events[tx3.events.length - 1];
      expect(event3.event).to.eq("DynOrigFee");
      expect(event3.args.dynOrigFee).to.eq(625);

      const tx4 = await (
        await strategy3.testCalcOriginationFee(
          2,
          emaUtilRate,
          85,
          65,
          16384,
          liquidityBorrowed.mul(8),
          borrowedInvariant,
          lpInvariant,
          0
        )
      ).wait();
      const event4 = tx4.events[tx4.events.length - 1];
      expect(event4.event).to.eq("DynOrigFee");
      expect(event4.args.dynOrigFee).to.eq(25);

      const tx5 = await (
        await strategy3.testCalcOriginationFee(
          2,
          emaUtilRate,
          85,
          65,
          16384,
          liquidityBorrowed.mul(95).div(10),
          borrowedInvariant,
          lpInvariant,
          0
        )
      ).wait();
      const event5 = tx5.events[tx5.events.length - 1];
      expect(event5.event).to.eq("DynOrigFee");
      expect(event5.args.dynOrigFee).to.eq(2500);

      const tx6 = await (
        await strategy3.testCalcOriginationFee(
          2,
          emaUtilRate,
          85,
          65,
          16384,
          liquidityBorrowed.mul(96).div(10),
          borrowedInvariant,
          lpInvariant,
          0
        )
      ).wait();
      const event6 = tx6.events[tx6.events.length - 1];
      expect(event6.event).to.eq("DynOrigFee");
      expect(event6.args.dynOrigFee).to.eq(5000);
    });

    it("Calc Orig Fee, utilRate < emaUtilRate", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const twelveDec = BigNumber.from(10).pow(12);
      const emaUtilRate = ONE.mul(95).div(100).div(twelveDec); // 80%
      const borrowedInvariant = ONE.mul(1000);
      const lpInvariant = ONE.mul(1000);

      const liquidityBorrowed = ONE.mul(100);
      const tx = await (
        await strategy3.testCalcOriginationFee(
          2,
          emaUtilRate,
          85,
          65,
          16384,
          liquidityBorrowed,
          borrowedInvariant,
          lpInvariant,
          0
        )
      ).wait();
      const event = tx.events[tx.events.length - 1];
      expect(event.event).to.eq("DynOrigFee");
      expect(event.args.dynOrigFee).to.eq(625);
    });
  });

  describe("Open & Pay Loan", function () {
    it("Check Set LP Token Balances", async function () {
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;
      const ONE = BigNumber.from(10).pow(18);
      const res2 = await strategy.getLoanChangeData(tokenId);
      expect(res2.loanLiquidity).to.equal(0);
      expect(res2.loanLpTokens).to.equal(0);
      expect(res2.borrowedInvariant).to.equal(0);
      expect(res2.lpInvariant).to.equal(0);
      expect(res2.totalInvariant).to.equal(0);
      expect(res2.lpTokenBorrowed).to.equal(0);
      expect(res2.lpTokenBalance).to.equal(0);
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(res2.lpTokenTotal).to.equal(0);
      expect(res2.lastCFMMInvariant).to.equal(0);
      expect(res2.lastCFMMTotalSupply).to.equal(0);

      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      const res3 = await strategy.getLoanChangeData(tokenId);
      expect(res3.loanLiquidity).to.equal(0);
      expect(res3.loanLpTokens).to.equal(0);
      expect(res3.borrowedInvariant).to.equal(0);
      expect(res3.lpInvariant).to.equal(startLiquidity);
      expect(res3.totalInvariant).to.equal(startLiquidity);
      expect(res3.lpTokenBorrowed).to.equal(0);
      expect(res3.lpTokenBalance).to.equal(startLpTokens);
      expect(res3.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(res3.lpTokenTotal).to.equal(startLpTokens);
      expect(res3.lastCFMMInvariant).to.equal(lastCFMMInvariant);
      expect(res3.lastCFMMTotalSupply).to.equal(lastCFMMTotalSupply);
    });

    it("Update Loan Price", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const addedLiquidity = ONE.mul(800);
      const currPrice = ONE.mul(2);
      const existingLiquidity = ONE.mul(400);
      const lastPrice = ONE.mul(3);

      const newPx = await strategy.testUpdateLoanPrice(
        addedLiquidity,
        currPrice,
        existingLiquidity,
        lastPrice
      );
      const expNewPx = updateLoanPrice(
        addedLiquidity,
        currPrice,
        existingLiquidity,
        lastPrice
      );
      expect(newPx).to.equal(expNewPx);

      const newPx1 = await strategy.testUpdateLoanPrice(
        addedLiquidity.mul(3),
        currPrice,
        existingLiquidity,
        lastPrice
      );
      const expNewPx1 = updateLoanPrice(
        addedLiquidity.mul(3),
        currPrice,
        existingLiquidity,
        lastPrice
      );
      expect(newPx1).to.equal(expNewPx1);

      const newPx2 = await strategy.testUpdateLoanPrice(
        addedLiquidity.mul(3),
        currPrice.mul(4),
        existingLiquidity,
        lastPrice
      );
      const expNewPx2 = updateLoanPrice(
        addedLiquidity.mul(3),
        currPrice.mul(4),
        existingLiquidity,
        lastPrice
      );
      expect(newPx2).to.equal(expNewPx2);
    });

    it("Open Loan", async function () {
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const lpTokens = ONE.mul(100);
      const liquidity = ONE.mul(200);
      await (await cfmm.burn(lpTokens, strategy.address)).wait();
      await (await strategy.testOpenLoan(tokenId, lpTokens)).wait();
      const res2 = await strategy.getLoanChangeData(tokenId);
      expect(res2.loanPx).to.equal(ONE);
      expect(res2.initLiquidity).to.equal(liquidity);
      expect(res2.loanLiquidity).to.equal(liquidity);
      expect(res2.loanLpTokens).to.equal(lpTokens);
      expect(res2.borrowedInvariant).to.equal(liquidity);
      expect(res2.lpInvariant).to.equal(startLiquidity.sub(liquidity));
      expect(res2.totalInvariant).to.equal(startLiquidity);
      expect(res2.lpTokenBorrowed).to.equal(lpTokens);
      expect(res2.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(lpTokens);
      expect(res2.lpTokenTotal).to.equal(startLpTokens);
      // expect(res2.lastCFMMInvariant).to.equal(lastCFMMInvariant.sub(liquidity));
      // expect(res2.lastCFMMTotalSupply).to.equal(
      //  lastCFMMTotalSupply.sub(lpTokens)
      // );

      const lpTokens1 = ONE.mul(250);
      const liquidity1 = ONE.mul(500);
      await (await cfmm.burn(lpTokens1, strategy.address)).wait();
      await (await strategy.setCurrentCFMMPrice(ONE.mul(2))).wait();
      await (await strategy.testOpenLoan(tokenId, lpTokens1)).wait();
      const res3 = await strategy.getLoanChangeData(tokenId);
      const expNewPx = updateLoanPrice(
        liquidity1,
        ONE.mul(2),
        res2.initLiquidity,
        res2.loanPx
      );
      expect(res3.loanPx).to.equal(expNewPx);
      expect(res3.initLiquidity).to.equal(liquidity.add(liquidity1));
      expect(res3.loanLiquidity).to.equal(liquidity.add(liquidity1));
      expect(res3.loanLpTokens).to.equal(lpTokens.add(lpTokens1));
      expect(res3.borrowedInvariant).to.equal(liquidity.add(liquidity1));
      expect(res3.lpInvariant).to.equal(
        startLiquidity.sub(liquidity).sub(liquidity1)
      );
      expect(res3.totalInvariant).to.equal(startLiquidity);
      expect(res3.lpTokenBorrowed).to.equal(lpTokens.add(lpTokens1));
      expect(res3.lpTokenBalance).to.equal(
        startLpTokens.sub(lpTokens).sub(lpTokens1)
      );
      expect(res3.lpTokenBorrowedPlusInterest).to.equal(
        lpTokens.add(lpTokens1)
      );
      expect(res3.lpTokenTotal).to.equal(startLpTokens);
      // expect(res3.lastCFMMInvariant).to.equal(
      //   lastCFMMInvariant.sub(liquidity.add(liquidity1))
      // );
      // expect(res3.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens.add(lpTokens1))
      // );
    });

    it("Open Loan with Origination Fee", async function () {
      strategy = strategy3;
      await (
        await strategy.testCalcOriginationFee(
          2,
          0,
          85,
          65,
          16384,
          0,
          0,
          0,
          1000
        )
      ).wait();
      await (await strategy.setOrigFeeParams(10)).wait();
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      await strategy.setOriginationFee(10);
      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(1000);
      const startLpTokens = ONE.mul(500);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const lpTokens = ONE.mul(100);
      const liquidity = ONE.mul(200);
      await (await cfmm.burn(lpTokens, strategy.address)).wait();
      await (await strategy.testOpenLoan(tokenId, lpTokens)).wait();
      const res2 = await strategy.getLoanChangeData(tokenId);

      const fee = liquidity.mul(10).div(10000);
      const feeLP = lpTokens.mul(10).div(10000);
      expect(res2.loanPx).to.equal(ONE);
      expect(res2.initLiquidity).to.equal(liquidity);
      expect(res2.loanLiquidity).to.equal(liquidity.add(fee));
      expect(res2.loanLpTokens).to.equal(lpTokens);
      expect(res2.borrowedInvariant).to.equal(liquidity.add(fee));
      expect(res2.lpInvariant).to.equal(startLiquidity.sub(liquidity));
      expect(res2.totalInvariant).to.equal(startLiquidity.add(fee));
      expect(res2.lpTokenBorrowed).to.equal(lpTokens);
      expect(res2.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(lpTokens.add(feeLP));
      expect(res2.lpTokenTotal).to.equal(startLpTokens.add(feeLP));
      // expect(res2.lastCFMMInvariant).to.equal(lastCFMMInvariant.sub(liquidity));
      // expect(res2.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens)
      // );

      const lpTokens1 = ONE.mul(300);
      const liquidity1 = ONE.mul(600);
      await (await cfmm.burn(lpTokens1, strategy.address)).wait();
      await (await strategy.setCurrentCFMMPrice(ONE.mul(3))).wait();
      await (await strategy.testOpenLoan(tokenId, lpTokens1)).wait();
      const res3 = await strategy.getLoanChangeData(tokenId);

      const fee1 = fee.add(liquidity1.mul(15).div(10000));
      const feeLP1 = feeLP.add(lpTokens1.mul(15).div(10000));

      const expNewPx = updateLoanPrice(
        liquidity1,
        ONE.mul(3),
        res2.initLiquidity,
        res2.loanPx
      );
      expect(res3.loanPx).to.equal(expNewPx);
      expect(res3.initLiquidity).to.equal(liquidity.add(liquidity1));
      expect(res3.loanLiquidity).to.equal(liquidity.add(liquidity1).add(fee1));
      expect(res3.loanLpTokens).to.equal(lpTokens.add(lpTokens1));
      expect(res3.borrowedInvariant).to.equal(
        liquidity.add(liquidity1).add(fee1)
      );
      expect(res3.lpInvariant).to.equal(
        startLiquidity.sub(liquidity).sub(liquidity1)
      );
      expect(res3.totalInvariant).to.equal(startLiquidity.add(fee1));
      expect(res3.lpTokenBorrowed).to.equal(lpTokens.add(lpTokens1));
      expect(res3.lpTokenBalance).to.equal(
        startLpTokens.sub(lpTokens).sub(lpTokens1)
      );
      expect(res3.lpTokenBorrowedPlusInterest).to.equal(
        lpTokens.add(lpTokens1).add(feeLP1)
      );
      expect(res3.lpTokenTotal).to.equal(startLpTokens.add(feeLP1));
      // expect(res3.lastCFMMInvariant).to.equal(
      //   lastCFMMInvariant.sub(liquidity.add(liquidity1))
      // );
      // expect(res3.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens.add(lpTokens1))
      // );
    });

    it("Open Loan with Origination Fee, Mint to Devs", async function () {
      strategy = strategy3;
      await (await strategy.setOrigFeeParams(10)).wait();
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      await (await factory.setOrigFeeShare2(500)).wait();
      await strategy.setOriginationFee(10);
      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(1000);
      const startLpTokens = ONE.mul(500);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      expect(await strategy.balanceOf(owner.address)).to.equal(startLpTokens);

      const poolFeeInfo = await factory.getPoolFee(strategy.address);

      const devBalance0 = await strategy.balanceOf(poolFeeInfo._feeTo);

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const lpTokens = ONE.mul(100);
      const liquidity = ONE.mul(200);
      await (await cfmm.burn(lpTokens, strategy.address)).wait();
      await (await strategy.testOpenLoan(tokenId, lpTokens)).wait();
      const res2 = await strategy.getLoanChangeData(tokenId);

      const devBalance1 = await strategy.balanceOf(poolFeeInfo._feeTo);
      expect(devBalance1).to.equal(
        devBalance0.add(lpTokens.mul(10).div(10000).div(2))
      );

      const fee = liquidity.mul(10).div(10000);
      const feeLP = lpTokens.mul(10).div(10000);
      expect(res2.loanPx).to.equal(ONE);
      expect(res2.initLiquidity).to.equal(liquidity);
      expect(res2.loanLiquidity).to.equal(liquidity.add(fee));
      expect(res2.loanLpTokens).to.equal(lpTokens);
      expect(res2.borrowedInvariant).to.equal(liquidity.add(fee));
      expect(res2.lpInvariant).to.equal(startLiquidity.sub(liquidity));
      expect(res2.totalInvariant).to.equal(startLiquidity.add(fee));
      expect(res2.lpTokenBorrowed).to.equal(lpTokens);
      expect(res2.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(lpTokens.add(feeLP));
      expect(res2.lpTokenTotal).to.equal(startLpTokens.add(feeLP));
      // expect(res2.lastCFMMInvariant).to.equal(lastCFMMInvariant.sub(liquidity));
      // expect(res2.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens)
      // );
    });

    it("Opened More Loan", async function () {
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const lpTokens = ONE.mul(100);
      const liquidity = ONE.mul(200);
      await (await cfmm.burn(lpTokens, strategy.address)).wait();
      await (await strategy.setCurrentCFMMPrice(ONE.mul(5))).wait();
      await (await strategy.testOpenLoan(tokenId, lpTokens)).wait();
      const res2 = await strategy.getLoanChangeData(tokenId);
      expect(res2.loanPx).to.equal(ONE.mul(5));
      expect(res2.initLiquidity).to.equal(liquidity);
      expect(res2.loanLiquidity).to.equal(liquidity);
      expect(res2.loanLpTokens).to.equal(lpTokens);
      expect(res2.borrowedInvariant).to.equal(liquidity);
      expect(res2.lpInvariant).to.equal(startLiquidity.sub(liquidity));
      expect(res2.totalInvariant).to.equal(startLiquidity);
      expect(res2.lpTokenBorrowed).to.equal(lpTokens);
      expect(res2.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(lpTokens);
      expect(res2.lpTokenTotal).to.equal(startLpTokens);
      // expect(res2.lastCFMMInvariant).to.equal(lastCFMMInvariant.sub(liquidity));
      // expect(res2.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens)
      // );

      const lpTokens1 = ONE.mul(250);
      const liquidity1 = ONE.mul(500);
      await (await cfmm.burn(lpTokens1.div(2), strategy.address)).wait();
      await (await strategy.setCurrentCFMMPrice(ONE.mul(7))).wait();
      await (await strategy.testOpenLoan(tokenId, lpTokens1)).wait();
      const res3 = await strategy.getLoanChangeData(tokenId);
      const expNewPx = updateLoanPrice(
        liquidity1,
        ONE.mul(7),
        res2.initLiquidity,
        res2.loanPx
      );
      expect(res3.loanPx).to.equal(expNewPx);
      expect(res3.initLiquidity).to.equal(liquidity.add(liquidity1));
      expect(res3.loanLiquidity).to.equal(liquidity.add(liquidity1));
      expect(res3.loanLpTokens).to.equal(lpTokens.add(lpTokens1));
      expect(res3.borrowedInvariant).to.equal(liquidity.add(liquidity1));
      expect(res3.lpInvariant).to.equal(
        startLiquidity.sub(liquidity).sub(liquidity1.div(2))
      );
      expect(res3.totalInvariant).to.equal(
        startLiquidity.add(liquidity1.div(2))
      );
      expect(res3.lpTokenBorrowed).to.equal(lpTokens.add(lpTokens1));
      expect(res3.lpTokenBalance).to.equal(
        startLpTokens.sub(lpTokens).sub(lpTokens1.div(2))
      );
      expect(res3.lpTokenBorrowedPlusInterest).to.equal(
        lpTokens.add(lpTokens1)
      );
      expect(res3.lpTokenTotal).to.equal(startLpTokens.add(lpTokens1.div(2)));
      // expect(res3.lastCFMMInvariant).to.equal(
      //   lastCFMMInvariant.sub(liquidity.add(liquidity1))
      // );
      // expect(res3.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens.add(lpTokens1))
      // );
    });

    it("Pay Loan", async function () {
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const lpTokens = ONE.mul(100);
      const liquidity = ONE.mul(200);
      await (await cfmm.burn(lpTokens, strategy.address)).wait();
      await (await strategy.setCurrentCFMMPrice(ONE.mul(9))).wait();
      await (await strategy.testOpenLoan(tokenId, lpTokens)).wait();
      const res2 = await strategy.getLoanChangeData(tokenId);
      expect(res2.loanPx).to.equal(ONE.mul(9));
      expect(res2.initLiquidity).to.equal(liquidity);
      expect(res2.loanLiquidity).to.equal(liquidity);
      expect(res2.loanLpTokens).to.equal(lpTokens);
      expect(res2.borrowedInvariant).to.equal(liquidity);
      expect(res2.lpInvariant).to.equal(startLiquidity.sub(liquidity));
      expect(res2.totalInvariant).to.equal(startLiquidity);
      expect(res2.lpTokenBorrowed).to.equal(lpTokens);
      expect(res2.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(lpTokens);
      expect(res2.lpTokenTotal).to.equal(startLpTokens);
      // expect(res2.lastCFMMInvariant).to.equal(lastCFMMInvariant.sub(liquidity));
      // expect(res2.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens)
      // );

      await (await cfmm.mint(lpTokens.div(2), strategy.address)).wait();

      await (await strategy.testPayLoan(tokenId, liquidity.div(2))).wait();
      const res4 = await strategy.getLoanChangeData(tokenId);
      expect(res4.loanPx).to.equal(ONE.mul(9));
      expect(res4.initLiquidity).to.equal(liquidity.div(2));
      expect(res4.loanLiquidity).to.equal(liquidity.div(2));
      expect(res4.loanLpTokens).to.equal(lpTokens.div(2));
      expect(res4.borrowedInvariant).to.equal(liquidity.div(2));
      expect(res4.lpInvariant).to.equal(startLiquidity.sub(liquidity.div(2)));
      expect(res4.totalInvariant).to.equal(startLiquidity);
      expect(res4.lpTokenBorrowed).to.equal(lpTokens.div(2));
      expect(res4.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens.div(2)));
      expect(res4.lpTokenBorrowedPlusInterest).to.equal(lpTokens.div(2));
      expect(res4.lpTokenTotal).to.equal(startLpTokens);
      // expect(res4.lastCFMMInvariant).to.equal(
      //   lastCFMMInvariant.sub(liquidity.div(2))
      // );
      // expect(res4.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens.div(2))
      // );

      await (await cfmm.mint(lpTokens.div(2), strategy.address)).wait();
      await (await strategy.setCurrentCFMMPrice(ONE.mul(7))).wait();

      await (await strategy.testPayLoan(tokenId, liquidity.div(2))).wait();
      const res5 = await strategy.getLoanChangeData(tokenId);
      expect(res5.loanPx).to.equal(0);
      expect(res5.initLiquidity).to.equal(0);
      expect(res5.loanLiquidity).to.equal(0);
      expect(res5.loanLpTokens).to.equal(0);
      expect(res5.borrowedInvariant).to.equal(0);
      expect(res5.lpInvariant).to.equal(startLiquidity);
      expect(res5.totalInvariant).to.equal(startLiquidity);
      expect(res5.lpTokenBorrowed).to.equal(0);
      expect(res5.lpTokenBalance).to.equal(startLpTokens);
      expect(res5.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(res5.lpTokenTotal).to.equal(startLpTokens);
      // expect(res5.lastCFMMInvariant).to.equal(lastCFMMInvariant);
      // expect(res5.lastCFMMTotalSupply).to.equal(lastCFMMTotalSupply);
    });

    it("Paid More Loan", async function () {
      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const lpTokens = ONE.mul(100);
      const liquidity = ONE.mul(200);
      await (await cfmm.burn(lpTokens, strategy.address)).wait();
      await (await strategy.setCurrentCFMMPrice(ONE.mul(11))).wait();
      await (await strategy.testOpenLoan(tokenId, lpTokens)).wait();
      const res2 = await strategy.getLoanChangeData(tokenId);
      expect(res2.loanPx).to.equal(ONE.mul(11));
      expect(res2.initLiquidity).to.equal(liquidity);
      expect(res2.loanLiquidity).to.equal(liquidity);
      expect(res2.loanLpTokens).to.equal(lpTokens);
      expect(res2.borrowedInvariant).to.equal(liquidity);
      expect(res2.lpInvariant).to.equal(startLiquidity.sub(liquidity));
      expect(res2.totalInvariant).to.equal(startLiquidity);
      expect(res2.lpTokenBorrowed).to.equal(lpTokens);
      expect(res2.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(lpTokens);
      expect(res2.lpTokenTotal).to.equal(startLpTokens);
      // expect(res2.lastCFMMInvariant).to.equal(lastCFMMInvariant.sub(liquidity));
      // expect(res2.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens)
      // );

      await (await cfmm.mint(lpTokens, strategy.address)).wait();

      await (await strategy.setCurrentCFMMPrice(ONE.mul(21))).wait();
      await (await strategy.testPayLoan(tokenId, liquidity.div(2))).wait();
      const res4 = await strategy.getLoanChangeData(tokenId);
      expect(res4.loanPx).to.equal(ONE.mul(11));
      expect(res4.initLiquidity).to.equal(liquidity.div(2));
      expect(res4.loanLiquidity).to.equal(liquidity.div(2));
      expect(res4.loanLpTokens).to.equal(lpTokens.div(2));
      expect(res4.borrowedInvariant).to.equal(liquidity.div(2));
      expect(res4.lpInvariant).to.equal(startLiquidity);
      expect(res4.totalInvariant).to.equal(
        startLiquidity.add(liquidity.div(2))
      );
      expect(res4.lpTokenBorrowed).to.equal(lpTokens.div(2));
      expect(res4.lpTokenBalance).to.equal(startLpTokens);
      expect(res4.lpTokenBorrowedPlusInterest).to.equal(lpTokens.div(2));
      expect(res4.lpTokenTotal).to.equal(startLpTokens.add(lpTokens.div(2)));
      // expect(res4.lastCFMMInvariant).to.equal(lastCFMMInvariant);
      // expect(res4.lastCFMMTotalSupply).to.equal(lastCFMMTotalSupply);
    });
  });

  describe("Borrow Liquidity", function () {
    it("Error Borrow Liquidity, > bal", async function () {
      await expect(
        strategy._borrowLiquidity(0, 1, [])
      ).to.be.revertedWithCustomError(strategy, "ExcessiveBorrowing");
    });

    it("Error Borrow Liquidity, FORBIDDEN", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      const res1 = await (await strategy.connect(addr2).createLoan()).wait();
      const addr3TokenId = res1.events[0].args.tokenId;
      const lpTokens = ONE;

      await expect(
        strategy._borrowLiquidity(0, 0, [])
      ).to.be.revertedWithCustomError(strategy, "LoanDoesNotExist");
      await expect(
        strategy._borrowLiquidity(0, 1, [])
      ).to.be.revertedWithCustomError(strategy, "LoanDoesNotExist");
      await expect(
        strategy._borrowLiquidity(addr3TokenId, 1, [])
      ).to.be.revertedWithCustomError(strategy, "Forbidden");
      await expect(
        strategy._borrowLiquidity(addr3TokenId, lpTokens, [])
      ).to.be.revertedWithCustomError(strategy, "Forbidden");

      await expect(
        strategy._borrowLiquidity(addr3TokenId.add(1), lpTokens, [])
      ).to.be.revertedWithCustomError(strategy, "LoanDoesNotExist");

      await expect(
        strategy._borrowLiquidity(addr3TokenId.sub(1), lpTokens, [])
      ).to.be.revertedWithCustomError(strategy, "LoanDoesNotExist");
    });

    it("Error Borrow Liquidity, > margin", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      await strategy.getLoan(tokenId);

      await strategy.getLoanChangeData(tokenId);

      const lpTokens = ONE.mul(3);

      const amtA = ONE.mul(2);
      const amtB = ONE.mul(4);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      await (await cfmm.burn(lpTokens, strategy.address)).wait();

      await expect(
        strategy._borrowLiquidity(tokenId, lpTokens, [])
      ).to.be.revertedWithCustomError(strategy, "Margin");
    });

    it("Error Borrow Liquidity, Min Borrow", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      await strategy.getLoan(tokenId);

      await strategy.getLoanChangeData(tokenId);

      const lpTokens = 499;

      const amtA = ONE.mul(2);
      const amtB = ONE.mul(4);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      await (await cfmm.burn(lpTokens, strategy.address)).wait();

      await expect(
        strategy._borrowLiquidity(tokenId, lpTokens, [])
      ).to.be.revertedWithCustomError(strategy, "MinBorrow");

      await strategy._borrowLiquidity(tokenId, lpTokens + 1, []);
    });

    it("Borrow Liquidity success", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const lpTokens = ONE;

      const amtA = ONE.mul(2);
      const amtB = ONE.mul(4);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      const expectedLiquidity = lpTokens.mul(2);

      await (await cfmm.burn(lpTokens, strategy.address)).wait();
      const res = await (
        await strategy._borrowLiquidity(tokenId, lpTokens, [])
      ).wait();

      checkEventData(
        res.events[res.events.length - 2],
        tokenId,
        amtA,
        amtB,
        expectedLiquidity,
        lpTokens,
        ONE
      );

      checkPoolEventData(
        res.events[res.events.length - 1],
        startLpTokens.sub(lpTokens),
        lpTokens,
        lpTokens,
        startLiquidity.sub(expectedLiquidity),
        expectedLiquidity,
        7
      );

      const res2 = await strategy.getLoanChangeData(tokenId);
      expect(res2.initLiquidity).to.equal(ONE.mul(2));
      expect(res2.loanLiquidity).to.equal(ONE.mul(2));
      expect(res2.loanLpTokens).to.equal(lpTokens);
      expect(res2.borrowedInvariant).to.equal(expectedLiquidity);
      expect(res2.lpInvariant).to.equal(startLiquidity.sub(expectedLiquidity));
      expect(res2.totalInvariant).to.equal(startLiquidity);
      expect(res2.lpTokenBorrowed).to.equal(lpTokens);
      expect(res2.lpTokenBalance).to.equal(startLpTokens.sub(lpTokens));
      expect(res2.lpTokenBorrowedPlusInterest).to.equal(lpTokens);
      expect(res2.lpTokenTotal).to.equal(startLpTokens);
      // expect(res2.lastCFMMInvariant).to.equal(
      //   lastCFMMInvariant.sub(ONE.mul(2))
      // );
      // expect(res2.lastCFMMTotalSupply).to.equal(
      //   lastCFMMTotalSupply.sub(lpTokens)
      // );
    });

    it("Borrow Liquidity success with ratio", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const lpTokens = ONE;

      const amtA = ONE.mul(2);
      const amtB = ONE.mul(4);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      const expectedLiquidity = lpTokens.mul(2);

      await (await cfmm.burn(lpTokens, strategy.address)).wait();
      const res = await (
        await strategy._borrowLiquidity(tokenId, lpTokens, [1000, 1000])
      ).wait();

      checkEventData(
        res.events[res.events.length - 2],
        tokenId,
        amtA,
        amtB.add(100),
        expectedLiquidity,
        lpTokens,
        ONE
      );
    });
  });

  describe("Repay Liquidity", function () {
    it.skip("Error Payment, Min Borrow", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      await strategy.getLoan(tokenId);

      await strategy.getLoanChangeData(tokenId);

      const lpTokens = 500;

      const amtA = ONE.mul(2);
      const amtB = ONE.mul(4);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      await (await cfmm.burn(lpTokens, strategy.address)).wait();

      await strategy._borrowLiquidity(tokenId, lpTokens, []);

      await expect(
        strategy._repayLiquidity(
          tokenId,
          2,
          0,
          ethers.constants.AddressZero,
          []
        )
      ).to.be.revertedWithCustomError(strategy, "MinBorrow");

      await expect(
        strategy._repayLiquidity(
          tokenId,
          999,
          0,
          ethers.constants.AddressZero,
          []
        )
      ).to.be.revertedWithCustomError(strategy, "MinBorrow");

      await (
        await strategy._repayLiquidity(
          tokenId,
          1000,
          0,
          ethers.constants.AddressZero,
          []
        )
      ).wait();
    });

    it.skip("Error Full Payment, MinBorrow", async function () {
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

      await expect(
        strategy._repayLiquidity(
          tokenId,
          loanLiquidity.mul(2),
          0,
          ethers.constants.AddressZero,
          []
        )
      ).to.be.revertedWithPanic();

      await (await tokenA.transfer(strategy.address, amtA)).wait();
      await (await tokenB.transfer(strategy.address, amtB)).wait();

      await (await strategy._increaseCollateral(tokenId, [])).wait();

      await (
        await strategy._repayLiquidity(
          tokenId,
          loanLiquidity.mul(2),
          0,
          ethers.constants.AddressZero,
          []
        )
      ).wait();

      const res2b = await strategy.getLoan(tokenId);
      const heldLiquidity2 = await strategy.squareRoot(
        res2b.tokensHeld[0].mul(res2b.tokensHeld[1]).div(ONE)
      );
      expect(res2b.poolId).to.equal(strategy.address);
      expect(res2b.tokensHeld[0]).gt(0);
      expect(res2b.tokensHeld[1]).gt(0);
      expect(res2b.heldLiquidity).to.equal(heldLiquidity2);
      expect(res2b.liquidity).to.equal(0);
      expect(res2b.lpTokens).to.equal(0);
    });

    it.skip("Partial Payment", async function () {
      const ONE = BigNumber.from(10).pow(18);

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const amtA = ONE.mul(20);
      const amtB = ONE.mul(40);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

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

      const res = await (
        await strategy._repayLiquidity(
          tokenId,
          loanLiquidity.div(2),
          0,
          ethers.constants.AddressZero,
          []
        )
      ).wait();

      checkEventData(
        res.events[res.events.length - 2],
        tokenId,
        amtA.div(2),
        amtB.div(2),
        loanLiquidity.div(2),
        loanLPTokens.div(2),
        ONE
      );

      checkPoolEventData(
        res.events[res.events.length - 1],
        startLpTokens.add(loanLPTokens.div(2)),
        loanLPTokens.div(2),
        loanLPTokens.div(2),
        startLiquidity.add(loanLiquidity.div(2)),
        loanLiquidity.div(2),
        8
      );

      const res2a = await strategy.getLoanChangeData(tokenId);
      expect(res2a.loanLiquidity).to.equal(loanLiquidity.div(2));
      expect(res2a.loanLpTokens).to.equal(loanLPTokens.div(2));
      expect(res2a.borrowedInvariant).to.equal(loanLiquidity.div(2));
      expect(res2a.lpInvariant).to.equal(
        startLiquidity.add(loanLiquidity.div(2))
      );
      expect(res2a.totalInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res2a.lpTokenBorrowed).to.equal(loanLPTokens.div(2));
      expect(res2a.lpTokenBalance).to.equal(
        startLpTokens.add(loanLPTokens.div(2))
      );
      expect(res2a.lpTokenBorrowedPlusInterest).to.equal(loanLPTokens.div(2));
      expect(res2a.lpTokenTotal).to.equal(startLpTokens.add(loanLPTokens));

      const res2b = await strategy.getLoan(tokenId);
      expect(res2b.poolId).to.equal(strategy.address);
      expect(res2b.tokensHeld[0]).to.equal(amtA.div(2));
      expect(res2b.tokensHeld[1]).to.equal(amtB.div(2));
      expect(res2b.heldLiquidity).to.equal(heldLiquidity.div(2));
      expect(res2b.liquidity).to.equal(loanLiquidity.div(2));
      expect(res2b.lpTokens).to.equal(loanLPTokens.div(2));
    });

    it.skip("Full Payment", async function () {
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

      await (await strategy.setMinPay(0)).wait();

      const res = await (
        await strategy._repayLiquidity(
          tokenId,
          loanLiquidity.mul(2),
          0,
          ethers.constants.AddressZero,
          []
        )
      ).wait();

      checkEventData(res.events[res.events.length - 2], tokenId, 0, 0, 0, 0, 0);

      checkPoolEventData(
        res.events[res.events.length - 1],
        startLpTokens.add(loanLPTokens),
        0,
        0,
        startLiquidity.add(loanLiquidity),
        0,
        8
      );

      const res2a = await strategy.getLoanChangeData(tokenId);
      expect(res2a.loanLiquidity).to.equal(0);
      expect(res2a.loanLpTokens).to.equal(0);
      expect(res2a.borrowedInvariant).to.equal(0);
      expect(res2a.lpInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res2a.totalInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res2a.lpTokenBorrowed).to.equal(0);
      expect(res2a.lpTokenBalance).to.equal(startLpTokens.add(loanLPTokens));
      expect(res2a.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(res2a.lpTokenTotal).to.equal(startLpTokens.add(loanLPTokens));

      const res2b = await strategy.getLoan(tokenId);
      expect(res2b.poolId).to.equal(strategy.address);
      expect(res2b.tokensHeld[0]).to.equal(0);
      expect(res2b.tokensHeld[1]).to.equal(0);
      expect(res2b.heldLiquidity).to.equal(0);
      expect(res2b.liquidity).to.equal(0);
      expect(res2b.lpTokens).to.equal(0);
    });

    it("Full Payment with rebalance", async function () {
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

      await strategy.setCfmmReserves([lastCFMMInvariant, lastCFMMInvariant]);

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();
      await (await strategy.setMinPay(0)).wait();

      // const beneficiary = "0x000000000000000000000000000000000000dEaD";
      const res = await (
        await strategy._repayLiquidity(
          tokenId,
          loanLiquidity,
          2,
          ethers.constants.AddressZero,
          []
        )
      ).wait();

      checkEventData(res.events[res.events.length - 2], tokenId, 0, 0, 0, 0, 0);
    });
  });

  describe("Repay Liquidity with LP", function () {
    it("Error Payment, Min Borrow", async function () {
      strategy = strategy2;
      const ONE = BigNumber.from(10).pow(18);
      const startLiquidity = ONE.mul(800);
      const startLpTokens = ONE.mul(400);
      const lastCFMMInvariant = startLiquidity.mul(2);
      const lastCFMMTotalSupply = startLpTokens.mul(2);
      await (
        await strategy.setLPTokenBalance(
          startLiquidity,
          startLpTokens,
          lastCFMMInvariant,
          lastCFMMTotalSupply
        )
      ).wait();

      await (await cfmm.mint(startLpTokens, strategy.address)).wait();
      await (await cfmm.mint(1000, owner.address)).wait();

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      await strategy.getLoan(tokenId);

      await strategy.getLoanChangeData(tokenId);

      const lpTokens = 500;

      const amtA = ONE.mul(2);
      const amtB = ONE.mul(4);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

      await (await cfmm.burn(lpTokens, strategy.address)).wait();

      await strategy._borrowLiquidity(tokenId, lpTokens, []);

      await (await cfmm.transfer(strategy.address, 1)).wait();

      await expect(
        strategy._repayLiquidityWithLP(tokenId, 0, ethers.constants.AddressZero)
      ).to.be.revertedWithCustomError(strategy, "MinBorrow");

      await (await cfmm.transfer(strategy.address, 498)).wait();

      await expect(
        strategy._repayLiquidityWithLP(tokenId, 0, ethers.constants.AddressZero)
      ).to.be.revertedWithCustomError(strategy, "MinBorrow");

      await (await cfmm.transfer(strategy.address, 1)).wait();
      await (
        await strategy._repayLiquidityWithLP(
          tokenId,
          0,
          ethers.constants.AddressZero
        )
      ).wait();
    });

    it("Error Full Payment, MinBorrow", async function () {
      strategy = strategy2;
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

      await expect(
        strategy._repayLiquidityWithLP(tokenId, 0, ethers.constants.AddressZero)
      ).to.be.revertedWithCustomError(strategy, "NotEnoughLPDeposit");

      await (await tokenA.transfer(strategy.address, amtA)).wait();
      await (await tokenB.transfer(strategy.address, amtB)).wait();

      await (await cfmm.mint(loanLiquidity, owner.address)).wait();
      await (await cfmm.transfer(strategy.address, loanLiquidity)).wait();

      await (
        await strategy._repayLiquidityWithLP(
          tokenId,
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      const res2b = await strategy.getLoan(tokenId);
      const heldLiquidity2 = await strategy.squareRoot(
        res2b.tokensHeld[0].mul(res2b.tokensHeld[1]).div(ONE)
      );
      expect(res2b.poolId).to.equal(strategy.address);
      expect(res2b.tokensHeld[0]).gt(0);
      expect(res2b.tokensHeld[1]).gt(0);
      expect(res2b.heldLiquidity).to.equal(heldLiquidity2);
      expect(res2b.liquidity).to.equal(0);
      expect(res2b.lpTokens).to.equal(0);
    });

    it("Partial Payment", async function () {
      strategy = strategy2;
      const ONE = BigNumber.from(10).pow(18);

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const amtA = ONE.mul(20);
      const amtB = ONE.mul(40);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

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

      await (await cfmm.mint(loanLiquidity.div(4), strategy.address)).wait();

      const res = await (
        await strategy._repayLiquidityWithLP(
          tokenId,
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      checkEventData(
        res.events[res.events.length - 2],
        tokenId,
        amtA.div(1),
        amtB.div(1),
        loanLiquidity.div(2),
        loanLPTokens.div(2),
        ONE
      );

      checkPoolEventData(
        res.events[res.events.length - 1],
        startLpTokens.add(loanLPTokens.div(2)),
        loanLPTokens.div(2),
        loanLPTokens.div(2),
        startLiquidity.add(loanLiquidity.div(2)),
        loanLiquidity.div(2),
        10
      );

      const res2a = await strategy.getLoanChangeData(tokenId);
      expect(res2a.loanLiquidity).to.equal(loanLiquidity.div(2));
      expect(res2a.loanLpTokens).to.equal(loanLPTokens.div(2));
      expect(res2a.borrowedInvariant).to.equal(loanLiquidity.div(2));
      expect(res2a.lpInvariant).to.equal(
        startLiquidity.add(loanLiquidity.div(2))
      );
      expect(res2a.totalInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res2a.lpTokenBorrowed).to.equal(loanLPTokens.div(2));
      expect(res2a.lpTokenBalance).to.equal(
        startLpTokens.add(loanLPTokens.div(2))
      );
      expect(res2a.lpTokenBorrowedPlusInterest).to.equal(loanLPTokens.div(2));
      expect(res2a.lpTokenTotal).to.equal(startLpTokens.add(loanLPTokens));

      const res2b = await strategy.getLoan(tokenId);
      expect(res2b.poolId).to.equal(strategy.address);
      expect(res2b.tokensHeld[0]).to.equal(amtA.div(1));
      expect(res2b.tokensHeld[1]).to.equal(amtB.div(1));
      expect(res2b.heldLiquidity).to.equal(heldLiquidity.div(1));
      expect(res2b.liquidity).to.equal(loanLiquidity.div(2));
      expect(res2b.lpTokens).to.equal(loanLPTokens.div(2));
    });

    it("Partial Payment, Withdraw", async function () {
      strategy = strategy2;
      const ONE = BigNumber.from(10).pow(18);

      const res1 = await (await strategy.createLoan()).wait();
      const tokenId = res1.events[0].args.tokenId;

      const amtA = ONE.mul(20);
      const amtB = ONE.mul(40);

      await tokenA.transfer(strategy.address, amtA);
      await tokenB.transfer(strategy.address, amtB);

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

      await (await cfmm.mint(loanLiquidity.div(4), strategy.address)).wait();

      const res = await (
        await strategy._repayLiquidityWithLP(tokenId, 0, owner.address)
      ).wait();

      checkEventData(
        res.events[res.events.length - 2],
        tokenId,
        amtA.div(2),
        amtB.div(2),
        loanLiquidity.div(2),
        loanLPTokens.div(2),
        ONE
      );

      checkPoolEventData(
        res.events[res.events.length - 1],
        startLpTokens.add(loanLPTokens.div(2)),
        loanLPTokens.div(2),
        loanLPTokens.div(2),
        startLiquidity.add(loanLiquidity.div(2)),
        loanLiquidity.div(2),
        10
      );

      const res2a = await strategy.getLoanChangeData(tokenId);
      expect(res2a.loanLiquidity).to.equal(loanLiquidity.div(2));
      expect(res2a.loanLpTokens).to.equal(loanLPTokens.div(2));
      expect(res2a.borrowedInvariant).to.equal(loanLiquidity.div(2));
      expect(res2a.lpInvariant).to.equal(
        startLiquidity.add(loanLiquidity.div(2))
      );
      expect(res2a.totalInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res2a.lpTokenBorrowed).to.equal(loanLPTokens.div(2));
      expect(res2a.lpTokenBalance).to.equal(
        startLpTokens.add(loanLPTokens.div(2))
      );
      expect(res2a.lpTokenBorrowedPlusInterest).to.equal(loanLPTokens.div(2));
      expect(res2a.lpTokenTotal).to.equal(startLpTokens.add(loanLPTokens));

      const res2b = await strategy.getLoan(tokenId);
      expect(res2b.poolId).to.equal(strategy.address);
      expect(res2b.tokensHeld[0]).to.equal(amtA.div(2));
      expect(res2b.tokensHeld[1]).to.equal(amtB.div(2));
      expect(res2b.heldLiquidity).to.equal(heldLiquidity.div(2));
      expect(res2b.liquidity).to.equal(loanLiquidity.div(2));
      expect(res2b.lpTokens).to.equal(loanLPTokens.div(2));
    });

    it("Full Payment", async function () {
      strategy = strategy2;
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

      await (await strategy.setMinPay(0)).wait();

      await (await cfmm.mint(loanLiquidity.div(2), strategy.address)).wait();

      const res = await (
        await strategy._repayLiquidityWithLP(
          tokenId,
          0,
          ethers.constants.AddressZero
        )
      ).wait();

      checkEventData(
        res.events[res.events.length - 2],
        tokenId,
        amtA,
        amtB,
        0,
        0,
        0
      );

      checkPoolEventData(
        res.events[res.events.length - 1],
        startLpTokens.add(loanLPTokens),
        0,
        0,
        startLiquidity.add(loanLiquidity),
        0,
        10
      );

      const res2a = await strategy.getLoanChangeData(tokenId);
      expect(res2a.loanLiquidity).to.equal(0);
      expect(res2a.loanLpTokens).to.equal(0);
      expect(res2a.borrowedInvariant).to.equal(0);
      expect(res2a.lpInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res2a.totalInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res2a.lpTokenBorrowed).to.equal(0);
      expect(res2a.lpTokenBalance).to.equal(startLpTokens.add(loanLPTokens));
      expect(res2a.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(res2a.lpTokenTotal).to.equal(startLpTokens.add(loanLPTokens));

      const res2b = await strategy.getLoan(tokenId);
      expect(res2b.poolId).to.equal(strategy.address);
      expect(res2b.tokensHeld[0]).to.equal(amtA);
      expect(res2b.tokensHeld[1]).to.equal(amtB);
      expect(res2b.heldLiquidity).to.equal(heldLiquidity);
      expect(res2b.liquidity).to.equal(0);
      expect(res2b.lpTokens).to.equal(0);
    });

    it("Full Payment, Withdraw", async function () {
      strategy = strategy2;
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

      await (await strategy.setMinPay(0)).wait();

      await (await cfmm.mint(loanLiquidity.div(2), strategy.address)).wait();

      const res = await (
        await strategy._repayLiquidityWithLP(tokenId, 0, owner.address)
      ).wait();

      checkEventData(res.events[res.events.length - 2], tokenId, 0, 0, 0, 0, 0);

      checkPoolEventData(
        res.events[res.events.length - 1],
        startLpTokens.add(loanLPTokens),
        0,
        0,
        startLiquidity.add(loanLiquidity),
        0,
        10
      );

      const res2a = await strategy.getLoanChangeData(tokenId);
      expect(res2a.loanLiquidity).to.equal(0);
      expect(res2a.loanLpTokens).to.equal(0);
      expect(res2a.borrowedInvariant).to.equal(0);
      expect(res2a.lpInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res2a.totalInvariant).to.equal(startLiquidity.add(loanLiquidity));
      expect(res2a.lpTokenBorrowed).to.equal(0);
      expect(res2a.lpTokenBalance).to.equal(startLpTokens.add(loanLPTokens));
      expect(res2a.lpTokenBorrowedPlusInterest).to.equal(0);
      expect(res2a.lpTokenTotal).to.equal(startLpTokens.add(loanLPTokens));

      const res2b = await strategy.getLoan(tokenId);
      expect(res2b.poolId).to.equal(strategy.address);
      expect(res2b.tokensHeld[0]).to.equal(0);
      expect(res2b.tokensHeld[1]).to.equal(0);
      expect(res2b.heldLiquidity).to.equal(0);
      expect(res2b.liquidity).to.equal(0);
      expect(res2b.lpTokens).to.equal(0);
    });
  });
});
