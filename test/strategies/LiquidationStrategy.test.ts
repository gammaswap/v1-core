import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

describe("LiquidationStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestFactory: any;
  let TestLiquidationStrategy: any;
  let tokenA: any;
  let tokenB: any;
  let factory: any;
  let cfmm: any;
  let liquidationStrategy: any;
  let owner: any;
  const ONE = BigNumber.from(10).pow(18);

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    [owner] = await ethers.getSigners();

    TestLiquidationStrategy = await ethers.getContractFactory(
      "TestLiquidationStrategy"
    );
    TestFactory = await ethers.getContractFactory("TestGammaPoolFactory2");
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    TestCFMM = await ethers.getContractFactory("TestCFMM2");

    cfmm = await TestCFMM.deploy(
      tokenA.address,
      tokenB.address,
      "Test CFMM",
      "TCFMM"
    );

    // because Uniswap's CFMM reorders tokenA and tokenB in increasing order
    const token0addr = await cfmm.token0();
    const token1addr = await cfmm.token1();
    tokenA = await TestERC20.attach(token0addr);
    tokenB = await TestERC20.attach(token1addr);

    factory = await TestFactory.deploy();
    liquidationStrategy = await TestLiquidationStrategy.deploy();
    await (
      await liquidationStrategy.initialize(
        factory.address,
        cfmm.address,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();

    const amount0 = ONE.mul(20000);
    const amount1 = ONE.mul(20000);

    await (await tokenA.transfer(cfmm.address, amount0)).wait();
    await (await tokenB.transfer(cfmm.address, amount1)).wait();
    await (await cfmm.sync()).wait();

    const invariant = sqrt(amount0.mul(amount1));

    await (await cfmm.mint(invariant, owner.address)).wait();

    await (await cfmm.transfer(liquidationStrategy.address, invariant)).wait();

    await (await tokenA.transfer(cfmm.address, amount0.div(2))).wait();
    await (await tokenB.transfer(cfmm.address, amount1.div(2))).wait();
    await (await cfmm.sync()).wait();

    await (await cfmm.mint(invariant.div(2), owner.address)).wait();

    await (await tokenA.transfer(cfmm.address, amount0.div(2))).wait();
    await (await tokenB.transfer(cfmm.address, amount1.div(2))).wait();
    await (await tokenA.transfer(cfmm.address, amount0)).wait();
    await (await tokenB.transfer(cfmm.address, amount1)).wait();
    await (await cfmm.sync()).wait();
    await (await cfmm.trade(invariant.div(2))).wait();
    await (await cfmm.trade(invariant)).wait();

    await (await liquidationStrategy.updatePoolBalances()).wait();
  });

  const borrowLiquidity = async (
    amt0: BigNumber,
    amt1: BigNumber,
    lpTokens: BigNumber,
    count: number
  ): Promise<number[]> => {
    const loanIds = [];
    while (count > 0) {
      count--;
      await (await tokenA.transfer(liquidationStrategy.address, amt0)).wait();
      await (await tokenB.transfer(liquidationStrategy.address, amt1)).wait();
      const res = await (await liquidationStrategy.createLoan(lpTokens)).wait();
      const idx = res.events.length - 1;
      expect(res.events[idx].event).to.equal("LoanCreated");
      const tokenId = res.events[idx].args.tokenId;
      loanIds.push(tokenId);
    }
    return loanIds;
  };

  const sqrt = (y: BigNumber): BigNumber => {
    let z = BigNumber.from(0);
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

  describe("Deployment", function () {
    it("checks init params", async function () {
      const res = await liquidationStrategy.getStaticParams();
      expect(await liquidationStrategy.liquidationFee()).to.equal(250);
      expect(res.factory).to.equal(factory.address);
      expect(res.cfmm).to.equal(cfmm.address);
      expect(res.tokens.length).to.equal(2);
      expect(res.tokens[0]).to.equal(tokenA.address);
      expect(res.tokens[1]).to.equal(tokenB.address);
      expect(res.tokenBalances.length).to.equal(2);
      expect(res.tokenBalances[0]).to.equal(0);
      expect(res.tokenBalances[1]).to.equal(0);

      const bal0 = await cfmm.balanceOf(owner.address);
      expect(bal0).to.equal(ONE.mul(10000));

      const bal1 = await cfmm.balanceOf(liquidationStrategy.address);
      expect(bal1).to.equal(ONE.mul(20000));

      const totalInvariaint = await cfmm.invariant();
      expect(totalInvariaint).to.equal(ONE.mul(60000));

      const totalSupply = await cfmm.totalSupply();
      expect(totalSupply).to.equal(ONE.mul(30000));

      const res1 = await liquidationStrategy.getPoolBalances();
      expect(res1.bal.LP_TOKEN_BALANCE).to.equal(bal1);
      expect(res1.bal.LP_TOKEN_BORROWED).to.equal(0);
      expect(res1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(0);
      expect(res1.bal.BORROWED_INVARIANT).to.equal(0);
      expect(res1.bal.LP_INVARIANT).to.equal(ONE.mul(40000));
      expect(res1.bal.lastCFMMInvariant).to.equal(totalInvariaint);
      expect(res1.bal.lastCFMMTotalSupply).to.equal(totalSupply);
      expect(res1.tokenBalances.length).to.equal(2);
      expect(res1.tokenBalances[0]).to.equal(0);
      expect(res1.tokenBalances[1]).to.equal(0);
    });

    it("checks Borrowing", async function () {
      const lpTokens = ONE.mul(2);
      await expect(
        liquidationStrategy.createLoan(lpTokens)
      ).to.revertedWithCustomError(liquidationStrategy, "Margin");

      const stratBalance = await cfmm.balanceOf(liquidationStrategy.address);
      const cfmmTotalInvariant = await cfmm.invariant();
      const cfmmTotalSupply = await cfmm.totalSupply();

      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);
      await (await tokenA.transfer(liquidationStrategy.address, amt0)).wait();
      await (await tokenB.transfer(liquidationStrategy.address, amt1)).wait();

      const res = await (await liquidationStrategy.createLoan(lpTokens)).wait();

      const idx = res.events.length - 1;
      expect(res.events[idx].event).to.equal("LoanCreated");
      const tokenId = res.events[idx].args.tokenId;
      const loan = await liquidationStrategy.getLoan(tokenId);
      expect(loan.poolId).to.equal(liquidationStrategy.address);
      expect(loan.heldLiquidity).to.equal(amt0.mul(5));
      expect(loan.initLiquidity).to.equal(lpTokens.mul(2));
      expect(loan.liquidity).to.equal(lpTokens.mul(2));
      expect(loan.lpTokens).to.equal(lpTokens);
      expect(loan.tokensHeld.length).to.equal(2);
      expect(loan.tokensHeld[0]).to.equal(amt0.mul(5));
      expect(loan.tokensHeld[1]).to.equal(amt1.mul(5));
      expect(loan.rateIndex).to.equal(ONE);

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const res2 = await liquidationStrategy.getPoolBalances();
      expect(res2.bal.LP_TOKEN_BALANCE).to.equal(stratBalance.sub(lpTokens));
      expect(res2.bal.LP_TOKEN_BORROWED).to.equal(lpTokens);
      expect(res2.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(lpTokens);
      expect(res2.bal.BORROWED_INVARIANT).to.equal(lpTokens.mul(2));
      expect(res2.bal.LP_INVARIANT).to.equal(stratBalance.sub(lpTokens).mul(2));

      expect(res2.bal.lastCFMMInvariant).to.equal(
        cfmmTotalInvariant.sub(lpTokens.mul(2))
      );
      expect(res2.bal.lastCFMMTotalSupply).to.equal(
        cfmmTotalSupply.sub(lpTokens)
      );
      expect(res2.tokenBalances.length).to.equal(2);
      expect(res2.tokenBalances[0]).to.equal(amt0.mul(5));
      expect(res2.tokenBalances[1]).to.equal(amt1.mul(5));

      await (await tokenA.transfer(liquidationStrategy.address, amt0)).wait();
      await (await tokenB.transfer(liquidationStrategy.address, amt1)).wait();
      const res3 = await (
        await liquidationStrategy.createLoan(lpTokens)
      ).wait();

      const idx3 = res3.events.length - 1;
      expect(res3.events[idx3].event).to.equal("LoanCreated");
      const tokenId3 = res3.events[idx3].args.tokenId;
      const loan1 = await liquidationStrategy.getLoan(tokenId3);
      expect(loan1.poolId).to.equal(liquidationStrategy.address);
      expect(loan1.heldLiquidity).to.equal(amt0.mul(5));
      expect(loan1.initLiquidity).to.equal(lpTokens.mul(2));
      expect(loan1.liquidity).to.equal(lpTokens.mul(2));
      expect(loan1.lpTokens).to.equal(lpTokens);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(amt0.mul(5));
      expect(loan1.tokensHeld[1]).to.equal(amt1.mul(5));
      expect(loan1.rateIndex).to.equal(ONE);

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const res4 = await liquidationStrategy.getPoolBalances();
      expect(res4.bal.LP_TOKEN_BALANCE).to.equal(
        stratBalance.sub(lpTokens.mul(2))
      );
      expect(res4.bal.LP_TOKEN_BORROWED).to.equal(lpTokens.mul(2));
      expect(res4.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        lpTokens.mul(2)
      );
      expect(res4.bal.BORROWED_INVARIANT).to.equal(lpTokens.mul(4));
      expect(res4.bal.LP_INVARIANT).to.equal(
        stratBalance.sub(lpTokens.mul(2)).mul(2)
      );

      expect(res4.bal.lastCFMMInvariant).to.equal(
        cfmmTotalInvariant.sub(lpTokens.mul(4))
      );
      expect(res4.bal.lastCFMMTotalSupply).to.equal(
        cfmmTotalSupply.sub(lpTokens.mul(2))
      );
      expect(res4.tokenBalances.length).to.equal(2);
      expect(res4.tokenBalances[0]).to.equal(amt0.mul(10));
      expect(res4.tokenBalances[1]).to.equal(amt1.mul(10));
    });

    it("increase invariant", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);
      await (await tokenA.transfer(liquidationStrategy.address, amt0)).wait();
      await (await tokenB.transfer(liquidationStrategy.address, amt1)).wait();

      const res = await (await liquidationStrategy.createLoan(lpTokens)).wait();

      const idx = res.events.length - 1;
      expect(res.events[idx].event).to.equal("LoanCreated");
      const tokenId = res.events[idx].args.tokenId;
      await liquidationStrategy.getLoan(tokenId);

      const res1 = await liquidationStrategy.getPoolBalances();
      expect(res1.bal.LP_TOKEN_BORROWED).to.equal(lpTokens);
      expect(res1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(lpTokens);
      expect(res1.bal.BORROWED_INVARIANT).to.equal(lpTokens.mul(2));

      await (await liquidationStrategy.incBorrowedInvariant(lpTokens)).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const res2 = await liquidationStrategy.getPoolBalances();
      expect(res2.bal.LP_TOKEN_BORROWED).to.equal(lpTokens);
      expect(res2.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        lpTokens.add(lpTokens.div(2))
      );
      expect(res2.bal.BORROWED_INVARIANT).to.equal(lpTokens.mul(3));
      expect(res2.tokenBalances.length).to.equal(2);
      expect(res2.tokenBalances[0]).to.equal(amt0.mul(5));
      expect(res2.tokenBalances[1]).to.equal(amt1.mul(5));
    });

    it("Can Liquidate", async function () {
      await expect(
        liquidationStrategy.testCanLiquidate(10001, 9500)
      ).to.be.revertedWithCustomError(liquidationStrategy, "HasMargin");

      await expect(
        liquidationStrategy.testCanLiquidate(10000, 9500)
      ).to.be.revertedWithCustomError(liquidationStrategy, "HasMargin");

      await liquidationStrategy.testCanLiquidate(9999, 9500);
    });
  });

  describe("Test refund functions", function () {
    it("write  down, payableLiquidity >= loanLiquidity", async function () {
      const payableLiquidity = ONE.add(1);
      const loanLiquidity = ONE;
      const res = await (
        await liquidationStrategy.testWriteDown(payableLiquidity, loanLiquidity)
      ).wait();
      expect(res.events[0].event).to.equal("WriteDown2");
      expect(res.events[0].args.writeDownAmt).to.equal(0);
      expect(res.events[0].args.loanLiquidity).to.equal(loanLiquidity);

      const res0 = await (
        await liquidationStrategy.testWriteDown(
          payableLiquidity,
          loanLiquidity.add(1)
        )
      ).wait();
      expect(res0.events[0].event).to.equal("WriteDown2");
      expect(res0.events[0].args.writeDownAmt).to.equal(0);
      expect(res0.events[0].args.loanLiquidity).to.equal(payableLiquidity);
    });

    it("write  down, payableLiquidity < loanLiquidity", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      await borrowLiquidity(amt0, amt1, lpTokens, 4);

      await (await tokenA.transfer(liquidationStrategy.address, amt0)).wait();
      await (await tokenB.transfer(liquidationStrategy.address, amt1)).wait();
      const res = await (await liquidationStrategy.createLoan(lpTokens)).wait();

      const idx = res.events.length - 1;
      expect(res.events[idx].event).to.equal("LoanCreated");
      const tokenId = res.events[idx].args.tokenId;

      await (
        await liquidationStrategy.incBorrowedInvariant(lpTokens.mul(10))
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      await (await liquidationStrategy.testUpdateLoan(tokenId)).wait();

      const loan = await liquidationStrategy.getLoan(tokenId);

      const res1 = await liquidationStrategy.getPoolBalances();

      const payableLiquidity = amt1.mul(5);
      const expectedWriteDown = loan.liquidity.sub(payableLiquidity);
      expect(expectedWriteDown).gt(0);

      const res2 = await (
        await liquidationStrategy.testWriteDown(
          payableLiquidity,
          loan.liquidity
        )
      ).wait();
      expect(res2.events[0].event).to.equal("WriteDown2");
      expect(res2.events[0].args.writeDownAmt).to.equal(expectedWriteDown);
      expect(res2.events[0].args.loanLiquidity).to.equal(payableLiquidity);

      const res3 = await liquidationStrategy.getPoolBalances();
      expect(res3.bal.LP_TOKEN_BORROWED).to.equal(res1.bal.LP_TOKEN_BORROWED);
      expect(res3.bal.BORROWED_INVARIANT).to.equal(
        res1.bal.BORROWED_INVARIANT.sub(expectedWriteDown)
      );
      expect(res3.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        res1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST.sub(expectedWriteDown.div(2))
      );
    });

    it("refund over payment, payLiquidity <= loanLiquidity", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      await borrowLiquidity(amt0, amt1, lpTokens, 5);

      const loanLiquidity = ONE;
      const lpDeposit = ONE.div(2).sub(1);
      const expectedPayLiquidity = lpDeposit.mul(2);

      const stratBalance0 = await cfmm.balanceOf(liquidationStrategy.address);
      const ownerBalance0 = await cfmm.balanceOf(owner.address);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpDeposit)
      ).wait();

      const res1 = await (
        await liquidationStrategy.testRefundOverPayment(
          loanLiquidity,
          lpDeposit,
          false
        )
      ).wait();

      expect(res1.events[0].event).to.equal("RefundOverPayment");
      expect(res1.events[0].args.loanLiquidity).to.equal(expectedPayLiquidity);
      expect(res1.events[0].args.lpDeposit).to.equal(lpDeposit);

      const stratBalance1 = await cfmm.balanceOf(liquidationStrategy.address);
      const ownerBalance1 = await cfmm.balanceOf(owner.address);
      expect(stratBalance1).to.equal(stratBalance0.add(lpDeposit));
      expect(ownerBalance1).to.equal(ownerBalance0.sub(lpDeposit));

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const lpDeposit1 = ONE.div(2);
      const expectedPayLiquidity1 = lpDeposit1.mul(2);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpDeposit1)
      ).wait();

      const res2 = await (
        await liquidationStrategy.testRefundOverPayment(
          loanLiquidity,
          lpDeposit1,
          false
        )
      ).wait();

      expect(res2.events[0].event).to.equal("RefundOverPayment");
      expect(res2.events[0].args.loanLiquidity).to.equal(expectedPayLiquidity1);
      expect(res2.events[0].args.lpDeposit).to.equal(lpDeposit1);

      const stratBalance2 = await cfmm.balanceOf(liquidationStrategy.address);
      const ownerBalance2 = await cfmm.balanceOf(owner.address);
      expect(stratBalance2).to.equal(stratBalance1.add(lpDeposit1));
      expect(ownerBalance2).to.equal(ownerBalance1.sub(lpDeposit1));
    });

    it("refund over payment, payLiquidity > loanLiquidity", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      await borrowLiquidity(amt0, amt1, lpTokens, 5);

      const loanLiquidity = ONE;
      const lpDeposit = ONE.mul(2);
      const expectedPayLiquidity = loanLiquidity;
      const expectedLpDeposit = ONE.div(2);
      const lpDepositChange = lpDeposit.sub(expectedLpDeposit);

      const stratBalance0 = await cfmm.balanceOf(liquidationStrategy.address);
      const ownerBalance0 = await cfmm.balanceOf(owner.address);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpDepositChange)
      ).wait();

      const res1 = await (
        await liquidationStrategy.testRefundOverPayment(
          loanLiquidity,
          lpDeposit,
          true
        )
      ).wait();

      expect(res1.events[1].event).to.equal("RefundOverPayment");
      expect(res1.events[1].args.loanLiquidity).to.equal(expectedPayLiquidity);
      expect(res1.events[1].args.lpDeposit).to.equal(expectedLpDeposit);

      const stratBalance1 = await cfmm.balanceOf(liquidationStrategy.address);
      const ownerBalance1 = await cfmm.balanceOf(owner.address);
      expect(stratBalance1).to.equal(stratBalance0.add(expectedLpDeposit));
      expect(ownerBalance1).to.equal(ownerBalance0.sub(expectedLpDeposit));
    });

    it("refund liquidator, 25%", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(amt0, amt1, lpTokens, 1);

      const loan = await liquidationStrategy.getLoan(tokenIds[0]);

      const payLiquidity = loan.liquidity.div(4);
      const expectedRefund0 = amt0.mul(5).div(4);
      const expectedRefund1 = amt1.mul(5).div(4);
      const expectedTokensHeld0 = amt0.mul(5).sub(expectedRefund0);
      const expectedTokensHeld1 = amt1.mul(5).sub(expectedRefund1);

      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);

      const poolBal0 = await liquidationStrategy.getPoolBalances();
      expect(poolBal0.tokenBalances.length).to.equal(2);
      expect(poolBal0.tokenBalances[0]).to.equal(amt0.mul(5));
      expect(poolBal0.tokenBalances[1]).to.equal(amt1.mul(5));

      const res = await (
        await liquidationStrategy.testRefundLiquidator(
          tokenIds[0],
          payLiquidity,
          loan.liquidity
        )
      ).wait();

      expect(res.events[2].event).to.equal("RefundLiquidator");
      expect(res.events[2].args.tokensHeld.length).to.equal(2);
      expect(res.events[2].args.tokensHeld[0]).to.equal(expectedTokensHeld0);
      expect(res.events[2].args.tokensHeld[1]).to.equal(expectedTokensHeld1);
      expect(res.events[2].args.refund.length).to.equal(2);
      expect(res.events[2].args.refund[0]).to.equal(expectedRefund0);
      expect(res.events[2].args.refund[1]).to.equal(expectedRefund1);

      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);

      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(expectedRefund0));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(expectedRefund1));
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(expectedRefund0));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(expectedRefund1));

      const poolBal1 = await liquidationStrategy.getPoolBalances();
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances[0]).to.equal(
        amt0.mul(5).sub(expectedRefund0)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        amt1.mul(5).sub(expectedRefund1)
      );
    });

    it("refund liquidator, 50%", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(amt0, amt1, lpTokens, 1);

      const loan = await liquidationStrategy.getLoan(tokenIds[0]);

      const payLiquidity = loan.liquidity.div(2);
      const expectedRefund0 = amt0.mul(5).div(2);
      const expectedRefund1 = amt1.mul(5).div(2);
      const expectedTokensHeld0 = amt0.mul(5).sub(expectedRefund0);
      const expectedTokensHeld1 = amt1.mul(5).sub(expectedRefund1);

      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);

      const poolBal0 = await liquidationStrategy.getPoolBalances();
      expect(poolBal0.tokenBalances.length).to.equal(2);
      expect(poolBal0.tokenBalances[0]).to.equal(amt0.mul(5));
      expect(poolBal0.tokenBalances[1]).to.equal(amt1.mul(5));

      const res = await (
        await liquidationStrategy.testRefundLiquidator(
          tokenIds[0],
          payLiquidity,
          loan.liquidity
        )
      ).wait();

      expect(res.events[2].event).to.equal("RefundLiquidator");
      expect(res.events[2].args.tokensHeld.length).to.equal(2);
      expect(res.events[2].args.tokensHeld[0]).to.equal(expectedTokensHeld0);
      expect(res.events[2].args.tokensHeld[1]).to.equal(expectedTokensHeld1);
      expect(res.events[2].args.refund.length).to.equal(2);
      expect(res.events[2].args.refund[0]).to.equal(expectedRefund0);
      expect(res.events[2].args.refund[1]).to.equal(expectedRefund1);

      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);

      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(expectedRefund0));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(expectedRefund1));
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(expectedRefund0));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(expectedRefund1));

      const poolBal1 = await liquidationStrategy.getPoolBalances();
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances[0]).to.equal(
        amt0.mul(5).sub(expectedRefund0)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        amt1.mul(5).sub(expectedRefund1)
      );
    });

    it("refund liquidator, 75%", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(amt0, amt1, lpTokens, 1);

      const loan = await liquidationStrategy.getLoan(tokenIds[0]);

      const payLiquidity = loan.liquidity.mul(3).div(4);
      const expectedRefund0 = amt0.mul(5).mul(3).div(4);
      const expectedRefund1 = amt1.mul(5).mul(3).div(4);
      const expectedTokensHeld0 = amt0.mul(5).sub(expectedRefund0);
      const expectedTokensHeld1 = amt1.mul(5).sub(expectedRefund1);

      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);

      const poolBal0 = await liquidationStrategy.getPoolBalances();
      expect(poolBal0.tokenBalances.length).to.equal(2);
      expect(poolBal0.tokenBalances[0]).to.equal(amt0.mul(5));
      expect(poolBal0.tokenBalances[1]).to.equal(amt1.mul(5));

      const res = await (
        await liquidationStrategy.testRefundLiquidator(
          tokenIds[0],
          payLiquidity,
          loan.liquidity
        )
      ).wait();

      expect(res.events[2].event).to.equal("RefundLiquidator");
      expect(res.events[2].args.tokensHeld.length).to.equal(2);
      expect(res.events[2].args.tokensHeld[0]).to.equal(expectedTokensHeld0);
      expect(res.events[2].args.tokensHeld[1]).to.equal(expectedTokensHeld1);
      expect(res.events[2].args.refund.length).to.equal(2);
      expect(res.events[2].args.refund[0]).to.equal(expectedRefund0);
      expect(res.events[2].args.refund[1]).to.equal(expectedRefund1);

      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);

      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(expectedRefund0));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(expectedRefund1));
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(expectedRefund0));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(expectedRefund1));

      const poolBal1 = await liquidationStrategy.getPoolBalances();
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances[0]).to.equal(
        amt0.mul(5).sub(expectedRefund0)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        amt1.mul(5).sub(expectedRefund1)
      );
    });

    it("refund liquidator, 100%", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(amt0, amt1, lpTokens, 1);

      const loan = await liquidationStrategy.getLoan(tokenIds[0]);

      const payLiquidity = loan.liquidity;
      const expectedRefund0 = amt0.mul(5);
      const expectedRefund1 = amt1.mul(5);
      const expectedTokensHeld0 = amt0.mul(5).sub(expectedRefund0);
      const expectedTokensHeld1 = amt1.mul(5).sub(expectedRefund1);

      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);

      const poolBal0 = await liquidationStrategy.getPoolBalances();
      expect(poolBal0.tokenBalances.length).to.equal(2);
      expect(poolBal0.tokenBalances[0]).to.equal(amt0.mul(5));
      expect(poolBal0.tokenBalances[1]).to.equal(amt1.mul(5));

      const res = await (
        await liquidationStrategy.testRefundLiquidator(
          tokenIds[0],
          payLiquidity,
          loan.liquidity
        )
      ).wait();

      expect(res.events[2].event).to.equal("RefundLiquidator");
      expect(res.events[2].args.tokensHeld.length).to.equal(2);
      expect(res.events[2].args.tokensHeld[0]).to.equal(expectedTokensHeld0);
      expect(res.events[2].args.tokensHeld[1]).to.equal(expectedTokensHeld1);
      expect(res.events[2].args.refund.length).to.equal(2);
      expect(res.events[2].args.refund[0]).to.equal(expectedRefund0);
      expect(res.events[2].args.refund[1]).to.equal(expectedRefund1);

      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);

      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(expectedRefund0));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(expectedRefund1));
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(expectedRefund0));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(expectedRefund1));

      const poolBal1 = await liquidationStrategy.getPoolBalances();
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances[0]).to.equal(
        amt0.mul(5).sub(expectedRefund0)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        amt1.mul(5).sub(expectedRefund1)
      );
    });

    it("sum liquidity", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(amt0, amt1, lpTokens, 5);

      const res0 = await liquidationStrategy.getPoolBalances();
      expect(res0.bal.LP_TOKEN_BORROWED).to.equal(lpTokens.mul(5));
      expect(res0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        lpTokens.mul(5)
      );
      expect(res0.bal.BORROWED_INVARIANT).to.equal(lpTokens.mul(10));
      expect(res0.tokenBalances.length).to.equal(2);
      expect(res0.tokenBalances[0]).to.equal(amt0.mul(25));
      expect(res0.tokenBalances[1]).to.equal(amt1.mul(25));

      await (
        await liquidationStrategy.incBorrowedInvariant(lpTokens.mul(2))
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const res1 = await liquidationStrategy.getPoolBalances();
      expect(res1.bal.LP_TOKEN_BORROWED).to.equal(lpTokens.mul(5));
      expect(res1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        lpTokens.mul(6)
      );
      expect(res1.bal.BORROWED_INVARIANT).to.equal(lpTokens.mul(12));
      expect(res1.tokenBalances.length).to.equal(2);
      expect(res1.tokenBalances[0]).to.equal(amt0.mul(25));
      expect(res1.tokenBalances[1]).to.equal(amt1.mul(25));

      const res2 = await (
        await liquidationStrategy.testSumLiquidity(tokenIds)
      ).wait();
      const lastIdx = res2.events.length - 1;
      expect(res2.events[lastIdx].event).to.equal("BatchLiquidations");
      expect(res2.events[lastIdx].args.liquidityTotal).to.equal(
        lpTokens.mul(12)
      );
      expect(res2.events[lastIdx].args.collateralTotal).to.equal(ONE.mul(25));
      expect(res2.events[lastIdx].args.lpTokensPrincipalTotal).to.equal(
        lpTokens.mul(5)
      );
      const amt0Fee = amt0.mul(5).mul(250).div(10000);
      const amt1Fee = amt1.mul(5).mul(250).div(10000);
      const amt0PostFee = amt0.mul(4).add(ONE.mul(8).div(10)).add(amt0Fee);
      const amt1PostFee = amt1.mul(4).add(ONE.mul(8).div(10)).add(amt1Fee);
      const amt0Remain = amt0.mul(5).sub(amt0PostFee);
      const amt1Remain = amt1.mul(5).sub(amt1PostFee);
      expect(res2.events[lastIdx].args.tokenIds.length).to.equal(5);
      expect(res2.events[lastIdx].args.tokenIds[0]).to.equal(tokenIds[0]);
      expect(res2.events[lastIdx].args.tokenIds[1]).to.equal(tokenIds[1]);
      expect(res2.events[lastIdx].args.tokenIds[2]).to.equal(tokenIds[2]);
      expect(res2.events[lastIdx].args.tokenIds[3]).to.equal(tokenIds[3]);
      expect(res2.events[lastIdx].args.tokenIds[4]).to.equal(tokenIds[4]);
      expect(res2.events[lastIdx].args.tokensHeldTotal.length).to.equal(2);
      expect(res2.events[lastIdx].args.tokensHeldTotal[0]).to.equal(
        amt0PostFee.mul(5)
      );
      expect(res2.events[lastIdx].args.tokensHeldTotal[1]).to.equal(
        amt1PostFee.mul(5)
      );

      for (let i = 0; i < tokenIds.length; i++) {
        const loan1 = await liquidationStrategy.getLoan(tokenIds[i]);
        expect(loan1.id).to.equal(i + 1);
        expect(loan1.poolId).to.equal(liquidationStrategy.address);
        expect(loan1.initLiquidity).to.equal(0);
        expect(loan1.liquidity).to.equal(0);
        expect(loan1.lpTokens).to.equal(0);
        expect(loan1.rateIndex).to.equal(0);
        expect(loan1.heldLiquidity).to.equal(sqrt(amt0Remain.mul(amt1Remain)));
        expect(loan1.tokensHeld.length).to.equal(2);
        expect(loan1.tokensHeld[0]).to.equal(amt0Remain);
        expect(loan1.tokensHeld[1]).to.equal(amt1Remain);
      }
    });

    it("sum liquidity, can't liquidate", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(amt0, amt1, lpTokens, 4);

      const tokenIds2 = await borrowLiquidity(
        amt0.mul(10),
        amt1.mul(10),
        lpTokens,
        1
      );
      tokenIds.push(tokenIds2[0]);

      const res0 = await liquidationStrategy.getPoolBalances();
      expect(res0.bal.LP_TOKEN_BORROWED).to.equal(lpTokens.mul(5));
      expect(res0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        lpTokens.mul(5)
      );
      expect(res0.bal.BORROWED_INVARIANT).to.equal(lpTokens.mul(10));
      expect(res0.tokenBalances.length).to.equal(2);
      expect(res0.tokenBalances[0]).to.equal(amt0.mul(34));
      expect(res0.tokenBalances[1]).to.equal(amt1.mul(34));

      await (
        await liquidationStrategy.incBorrowedInvariant(lpTokens.mul(10))
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const res1 = await liquidationStrategy.getPoolBalances();
      expect(res1.bal.LP_TOKEN_BORROWED).to.equal(lpTokens.mul(5));
      expect(res1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        lpTokens.mul(10)
      );
      expect(res1.bal.BORROWED_INVARIANT).to.equal(lpTokens.mul(20));
      expect(res1.tokenBalances.length).to.equal(2);
      expect(res1.tokenBalances[0]).to.equal(amt0.mul(34));
      expect(res1.tokenBalances[1]).to.equal(amt1.mul(34));

      const tx = await (
        await liquidationStrategy.testSumLiquidity(tokenIds)
      ).wait();

      const maxColl = amt0.mul(5);
      const fee = maxColl.mul(250).div(10000);
      const liquidityAfterWriteDown = maxColl.sub(fee);
      const lastIdx = tx.events.length - 1;
      expect(tx.events[lastIdx].event).to.eq("BatchLiquidations");
      expect(tx.events[lastIdx].args.liquidityTotal).to.eq(
        liquidityAfterWriteDown.mul(4)
      );
      expect(tx.events[lastIdx].args.collateralTotal).to.eq(maxColl.mul(4));
      expect(tx.events[lastIdx].args.lpTokensPrincipalTotal).to.eq(
        lpTokens.mul(4)
      );
      expect(tx.events[lastIdx].args.tokensHeldTotal.length).to.eq(2);
      expect(tx.events[lastIdx].args.tokensHeldTotal[0]).to.eq(
        amt0.mul(5).mul(4)
      );
      expect(tx.events[lastIdx].args.tokensHeldTotal[1]).to.eq(
        amt1.mul(5).mul(4)
      );
      expect(tx.events[lastIdx].args.tokenIds.length).to.eq(5);
      expect(tx.events[lastIdx].args.tokenIds[0]).to.eq(tokenIds[0]);
      expect(tx.events[lastIdx].args.tokenIds[1]).to.eq(tokenIds[1]);
      expect(tx.events[lastIdx].args.tokenIds[2]).to.eq(tokenIds[2]);
      expect(tx.events[lastIdx].args.tokenIds[3]).to.eq(tokenIds[3]);
      expect(tx.events[lastIdx].args.tokenIds[4]).to.eq(0);
    });
  });

  describe("liquidate with LP", function () {
    it("error has margin", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokens.mul(12))
      ).wait();

      await expect(
        liquidationStrategy._liquidateWithLP(tokenIds[0])
      ).to.be.revertedWithCustomError(liquidationStrategy, "HasMargin");
    });

    it("error, loan does not exist", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );

      await expect(
        liquidationStrategy._liquidateWithLP(BigNumber.from(tokenIds[0]).add(1))
      ).to.be.revertedWithCustomError(liquidationStrategy, "LoanDoesNotExist");
    });

    it("error InsufficientDeposit", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );

      await (await liquidationStrategy.incBorrowedInvariant(ONE)).wait();

      await expect(
        liquidationStrategy._liquidateWithLP(tokenIds[0])
      ).to.be.revertedWithCustomError(
        liquidationStrategy,
        "InsufficientDeposit"
      );
    });

    it("error partial liquidation", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );
      const invariantGrowth = ONE.mul(85).div(100);

      await (
        await liquidationStrategy.incBorrowedInvariant(invariantGrowth)
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      await (await liquidationStrategy.testUpdateLoan(tokenIds[0])).wait();

      const loan0 = await liquidationStrategy.getLoan(tokenIds[0]);
      const lpTokenPayment = loan0.liquidity.div(4); // paying half the lp token debt

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokenPayment)
      ).wait();

      const _lastCFMMTotalSupply = await cfmm.totalSupply();
      const _reserves = await cfmm.getReserves();
      const _lastCFMMInvariant = sqrt(_reserves[0].mul(_reserves[1]));
      const _bal0 = (await liquidationStrategy.getPoolBalances()).bal;
      expect(_lastCFMMTotalSupply).to.equal(_bal0.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(_bal0.lastCFMMInvariant);

      await expect(
        liquidationStrategy._liquidateWithLP(tokenIds[0])
      ).to.be.revertedWithCustomError(
        liquidationStrategy,
        "InsufficientDeposit"
      );
    });

    it("full liquidation, no write down", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );
      const invariantGrowth = ONE.mul(85).div(100);

      await (
        await liquidationStrategy.incBorrowedInvariant(invariantGrowth)
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const poolBal0 = await liquidationStrategy.getPoolBalances();

      await (await liquidationStrategy.testUpdateLoan(tokenIds[0])).wait();

      const loan0 = await liquidationStrategy.getLoan(tokenIds[0]);
      const lpTokenPayment = loan0.liquidity.div(2); // paying half the lp token debt
      const payLiquidity = lpTokenPayment.mul(2);
      const leftLiquidity = loan0.liquidity.sub(payLiquidity);
      const initLiquidityPaid = payLiquidity
        .mul(loan0.initLiquidity)
        .div(loan0.liquidity);
      const lpTokensPaid = payLiquidity
        .mul(loan0.lpTokens)
        .div(loan0.liquidity);
      const leftInitLiquidity = loan0.initLiquidity.sub(initLiquidityPaid);
      const leftLpTokens = loan0.lpTokens.sub(lpTokensPaid);
      const tokenAChange = payLiquidity.mul(amt0.mul(5)).div(loan0.liquidity);
      const tokenBChange = payLiquidity.mul(amt1.mul(5)).div(loan0.liquidity);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokenPayment)
      ).wait();

      const ownerCFMMBal0 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal0 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      const _lastCFMMTotalSupply = await cfmm.totalSupply();
      const _reserves = await cfmm.getReserves();
      const _lastCFMMInvariant = sqrt(_reserves[0].mul(_reserves[1]));
      const _bal0 = (await liquidationStrategy.getPoolBalances()).bal;
      expect(_lastCFMMTotalSupply).to.equal(_bal0.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(_bal0.lastCFMMInvariant);

      const res = await (
        await liquidationStrategy._liquidateWithLP(tokenIds[0])
      ).wait();

      const collateral = sqrt(tokenAChange.mul(tokenBChange));
      const fee = loan0.liquidity.mul(250).div(10000);
      const debtPlusFee = loan0.liquidity.add(fee);
      const _tokenAChange = debtPlusFee.mul(tokenAChange).div(collateral);
      const _tokenBChange = debtPlusFee.mul(tokenBChange).div(collateral);
      expect(res.events[res.events.length - 3].event).to.equal("Liquidation");
      expect(res.events[res.events.length - 3].args.liquidity).to.equal(
        payLiquidity
      );
      expect(res.events[res.events.length - 3].args.collateral).to.equal(
        collateral
      );
      expect(res.events[res.events.length - 3].args.writeDownAmt).to.equal(0);
      expect(res.events[res.events.length - 3].args.txType).to.equal(12);

      const ownerCFMMBal1 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal1 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      expect(ownerCFMMBal0).to.equal(ownerCFMMBal1);
      expect(stratCFMMBal0).to.equal(stratCFMMBal1);

      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(_tokenAChange));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(_tokenBChange));
      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(_tokenAChange));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(_tokenBChange));

      const loan1 = await liquidationStrategy.getLoan(tokenIds[0]);

      expect(loan1.liquidity).to.equal(leftLiquidity);
      expect(loan1.initLiquidity).to.equal(leftInitLiquidity);
      expect(loan1.lpTokens).to.equal(leftLpTokens);
      expect(loan1.rateIndex).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(
        loan0.tokensHeld[0].sub(_tokenAChange)
      );
      expect(loan1.tokensHeld[1]).to.equal(
        loan0.tokensHeld[1].sub(_tokenBChange)
      );

      const poolBal1 = await liquidationStrategy.getPoolBalances();

      // must check also pool token balances and LP Balances and invariant, etc.
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances.length).to.equal(
        poolBal0.tokenBalances.length
      );
      expect(poolBal1.tokenBalances[0]).to.equal(
        poolBal0.tokenBalances[0].sub(_tokenAChange)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        poolBal0.tokenBalances[1].sub(_tokenBChange)
      );
      expect(poolBal1.bal.LP_TOKEN_BALANCE).to.equal(
        poolBal0.bal.LP_TOKEN_BALANCE.add(lpTokenPayment)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED.sub(lpTokensPaid)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST.sub(lpTokenPayment)
      );
      expect(poolBal1.bal.BORROWED_INVARIANT).to.equal(
        poolBal0.bal.BORROWED_INVARIANT.sub(payLiquidity)
      );
      expect(poolBal1.bal.LP_INVARIANT).to.equal(
        poolBal0.bal.LP_INVARIANT.add(payLiquidity)
      );

      expect(_lastCFMMTotalSupply).to.equal(poolBal1.bal.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(poolBal1.bal.lastCFMMInvariant);

      const refundLiq = sqrt(_tokenAChange.mul(_tokenBChange));
      const refundGain = refundLiq.sub(payLiquidity);
      const refundGainPerc = refundGain.mul(ONE).div(payLiquidity);
      const expGainPerc = ONE.mul(5).div(200);
      expect(refundGainPerc).eq(expGainPerc);
      expect(tokenAChange.mul(1)).to.equal(amt0.mul(5));
      expect(tokenBChange.mul(1)).to.equal(amt1.mul(5));
    });

    it("full liquidation, write down", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );
      const invariantGrowth = ONE;

      await (
        await liquidationStrategy.incBorrowedInvariant(invariantGrowth)
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const poolBal0 = await liquidationStrategy.getPoolBalances();

      await (await liquidationStrategy.testUpdateLoan(tokenIds[0])).wait();

      const loan0 = await liquidationStrategy.getLoan(tokenIds[0]);

      const collateral = sqrt(loan0.tokensHeld[0].mul(loan0.tokensHeld[1]));
      const adjLiquidity = collateral.mul(9750).div(10000);
      const lpTokenPayment = adjLiquidity.div(2); // paying full lp token debt
      const payLiquidity = lpTokenPayment.mul(2);
      const payableLiquidity = adjLiquidity.lt(loan0.liquidity)
        ? adjLiquidity
        : loan0.liquidity;
      const writeDownAmt = loan0.liquidity.sub(payableLiquidity);
      const loanLiquidity = loan0.liquidity.sub(writeDownAmt);

      const leftLiquidity = loanLiquidity.sub(payLiquidity);
      const initLiquidityPaid = payLiquidity
        .mul(loan0.initLiquidity)
        .div(loanLiquidity);
      const lpTokensPaid = payLiquidity.mul(loan0.lpTokens).div(loanLiquidity);
      const leftInitLiquidity = loan0.initLiquidity.sub(initLiquidityPaid);
      const leftLpTokens = loan0.lpTokens.sub(lpTokensPaid);
      const tokenAChange = payLiquidity.mul(amt0.mul(5)).div(loanLiquidity);
      const tokenBChange = payLiquidity.mul(amt1.mul(5)).div(loanLiquidity);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokenPayment)
      ).wait();

      const ownerCFMMBal0 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal0 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      const _lastCFMMTotalSupply = await cfmm.totalSupply();
      const _reserves = await cfmm.getReserves();
      const _lastCFMMInvariant = sqrt(_reserves[0].mul(_reserves[1]));
      const _bal0 = (await liquidationStrategy.getPoolBalances()).bal;
      expect(_lastCFMMTotalSupply).to.equal(_bal0.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(_bal0.lastCFMMInvariant);

      const res = await (
        await liquidationStrategy._liquidateWithLP(tokenIds[0])
      ).wait();

      expect(res.events[res.events.length - 3].event).to.equal("Liquidation");
      expect(res.events[res.events.length - 3].args.liquidity).to.equal(
        payLiquidity
      );
      expect(res.events[res.events.length - 3].args.collateral).to.equal(
        sqrt(tokenAChange.mul(tokenBChange))
      );
      expect(res.events[res.events.length - 3].args.writeDownAmt).to.equal(
        writeDownAmt
      );
      expect(res.events[res.events.length - 3].args.txType).to.equal(12);

      const ownerCFMMBal1 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal1 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      expect(ownerCFMMBal0).to.equal(ownerCFMMBal1);
      expect(stratCFMMBal0).to.equal(stratCFMMBal1);
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(tokenAChange));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(tokenBChange));
      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(tokenAChange));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(tokenBChange));

      const loan1 = await liquidationStrategy.getLoan(tokenIds[0]);

      expect(loan1.liquidity).to.equal(leftLiquidity);
      expect(loan1.initLiquidity).to.equal(leftInitLiquidity);
      expect(loan1.lpTokens).to.equal(leftLpTokens);
      expect(loan1.rateIndex).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(
        loan0.tokensHeld[0].sub(tokenAChange)
      );
      expect(loan1.tokensHeld[1]).to.equal(
        loan0.tokensHeld[1].sub(tokenBChange)
      );

      const poolBal1 = await liquidationStrategy.getPoolBalances();

      // must check also pool token balances and LP Balances and invariant, etc.
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances.length).to.equal(
        poolBal0.tokenBalances.length
      );
      expect(poolBal1.tokenBalances[0]).to.equal(
        poolBal0.tokenBalances[0].sub(tokenAChange)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        poolBal0.tokenBalances[1].sub(tokenBChange)
      );
      expect(poolBal1.bal.LP_TOKEN_BALANCE).to.equal(
        poolBal0.bal.LP_TOKEN_BALANCE.add(lpTokenPayment)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED.sub(lpTokensPaid)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST.sub(lpTokenPayment).sub(
          writeDownAmt.div(2)
        )
      );
      expect(poolBal1.bal.BORROWED_INVARIANT).to.equal(
        poolBal0.bal.BORROWED_INVARIANT.sub(payLiquidity).sub(writeDownAmt)
      );
      expect(poolBal1.bal.LP_INVARIANT).to.equal(
        poolBal0.bal.LP_INVARIANT.add(payLiquidity)
      );

      expect(_lastCFMMTotalSupply).to.equal(poolBal1.bal.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(poolBal1.bal.lastCFMMInvariant);

      const refundLiq = sqrt(tokenAChange.mul(tokenBChange));
      const refundGain = refundLiq.sub(payLiquidity);
      const refundGainPerc = refundGain.mul(ONE).div(payLiquidity);
      const denominator = ONE.mul(4875).div(1000);
      const numerator = ONE.mul(125).div(1000);
      const expGainPerc = numerator.mul(ONE).div(denominator);
      expect(refundGainPerc).to.equal(expGainPerc);

      // const collateral1 = sqrt(loan1.tokensHeld[0].mul(loan1.tokensHeld[1]));
      // const ltvRatio = loan1.liquidity.mul(ONE).div(collateral1);
      // expect(ltvRatio).lte(ONE.mul(975).div(1000));
      // expect(ltvRatio).gt(ONE.mul(974999).div(1000000));
      // expect(tokenAChange.mul(2)).to.equal(amt0.mul(5));
      // expect(tokenBChange.mul(2)).to.equal(amt1.mul(5));
    });

    it("full liquidation & refund, no write down", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );
      const invariantGrowth = ONE.mul(85).div(100);

      await (
        await liquidationStrategy.incBorrowedInvariant(invariantGrowth)
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const poolBal0 = await liquidationStrategy.getPoolBalances();

      await (await liquidationStrategy.testUpdateLoan(tokenIds[0])).wait();

      const loan0 = await liquidationStrategy.getLoan(tokenIds[0]);
      const lpTokenPayment = loan0.liquidity.div(2); // paying the full lp token debt
      const payLiquidity = lpTokenPayment.mul(2);
      const leftLiquidity = loan0.liquidity.sub(payLiquidity);
      const initLiquidityPaid = payLiquidity
        .mul(loan0.initLiquidity)
        .div(loan0.liquidity);
      const lpTokensPaid = payLiquidity
        .mul(loan0.lpTokens)
        .div(loan0.liquidity);
      const leftInitLiquidity = loan0.initLiquidity.sub(initLiquidityPaid);
      const leftLpTokens = loan0.lpTokens.sub(lpTokensPaid);
      const tokenAChange = payLiquidity.mul(amt0.mul(5)).div(loan0.liquidity);
      const tokenBChange = payLiquidity.mul(amt1.mul(5)).div(loan0.liquidity);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokenPayment.mul(2))
      ).wait();

      const ownerCFMMBal0 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal0 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      const _lastCFMMTotalSupply = await cfmm.totalSupply();
      const _reserves = await cfmm.getReserves();
      const _lastCFMMInvariant = sqrt(_reserves[0].mul(_reserves[1]));
      const _bal0 = (await liquidationStrategy.getPoolBalances()).bal;
      expect(_lastCFMMTotalSupply).to.equal(_bal0.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(_bal0.lastCFMMInvariant);

      const res = await (
        await liquidationStrategy._liquidateWithLP(tokenIds[0])
      ).wait();

      const collateral = sqrt(tokenAChange.mul(tokenBChange));
      const fee = loan0.liquidity.mul(250).div(10000);
      const debtPlusFee = loan0.liquidity.add(fee);
      const _tokenAChange = debtPlusFee.mul(tokenAChange).div(collateral);
      const _tokenBChange = debtPlusFee.mul(tokenBChange).div(collateral);

      expect(res.events[res.events.length - 3].event).to.equal("Liquidation");
      expect(res.events[res.events.length - 3].args.liquidity).to.equal(
        payLiquidity
      );
      expect(res.events[res.events.length - 3].args.collateral).to.equal(
        collateral
      );
      expect(res.events[res.events.length - 3].args.writeDownAmt).to.equal(0);
      expect(res.events[res.events.length - 3].args.txType).to.equal(12);
      const ownerCFMMBal1 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal1 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      expect(ownerCFMMBal1).to.equal(ownerCFMMBal0.add(lpTokenPayment));
      expect(stratCFMMBal1).to.equal(stratCFMMBal0.sub(lpTokenPayment));
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(_tokenAChange));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(_tokenBChange));
      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(_tokenAChange));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(_tokenBChange));

      const loan1 = await liquidationStrategy.getLoan(tokenIds[0]);

      expect(loan1.liquidity).to.equal(leftLiquidity);
      expect(loan1.initLiquidity).to.equal(leftInitLiquidity);
      expect(loan1.lpTokens).to.equal(leftLpTokens);
      expect(loan1.rateIndex).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(
        loan0.tokensHeld[0].sub(_tokenAChange)
      );
      expect(loan1.tokensHeld[1]).to.equal(
        loan0.tokensHeld[1].sub(_tokenBChange)
      );

      const poolBal1 = await liquidationStrategy.getPoolBalances();

      // must check also pool token balances and LP Balances and invariant, etc.
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances.length).to.equal(
        poolBal0.tokenBalances.length
      );
      expect(poolBal1.tokenBalances[0]).to.equal(
        poolBal0.tokenBalances[0].sub(_tokenAChange)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        poolBal0.tokenBalances[1].sub(_tokenBChange)
      );
      expect(poolBal1.bal.LP_TOKEN_BALANCE).to.equal(
        poolBal0.bal.LP_TOKEN_BALANCE.add(lpTokenPayment)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED.sub(lpTokensPaid)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST.sub(lpTokenPayment)
      );
      expect(poolBal1.bal.BORROWED_INVARIANT).to.equal(
        poolBal0.bal.BORROWED_INVARIANT.sub(payLiquidity)
      );
      expect(poolBal1.bal.LP_INVARIANT).to.equal(
        poolBal0.bal.LP_INVARIANT.add(payLiquidity)
      );

      expect(_lastCFMMTotalSupply).to.equal(poolBal1.bal.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(poolBal1.bal.lastCFMMInvariant);

      const refundLiq = sqrt(_tokenAChange.mul(_tokenBChange));
      const refundGain = refundLiq.sub(payLiquidity);
      const refundGainPerc = refundGain.mul(ONE).div(payLiquidity);
      const expGainPerc = ONE.mul(5).div(200);
      expect(refundGainPerc).eq(expGainPerc);
      expect(tokenAChange.mul(1)).to.equal(amt0.mul(5));
      expect(tokenBChange.mul(1)).to.equal(amt1.mul(5));
    });

    it("full liquidation & refund, write down", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );
      const invariantGrowth = ONE;

      await (
        await liquidationStrategy.incBorrowedInvariant(invariantGrowth)
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const poolBal0 = await liquidationStrategy.getPoolBalances();

      await (await liquidationStrategy.testUpdateLoan(tokenIds[0])).wait();

      const loan0 = await liquidationStrategy.getLoan(tokenIds[0]);

      const collateral = sqrt(loan0.tokensHeld[0].mul(loan0.tokensHeld[1]));
      const adjLiquidity = collateral.mul(9750).div(10000);
      const lpTokenPayment = adjLiquidity.div(2); // paying full lp token debt
      const payLiquidity = lpTokenPayment.mul(2);
      const payableLiquidity = adjLiquidity.lt(loan0.liquidity)
        ? adjLiquidity
        : loan0.liquidity;
      const writeDownAmt = loan0.liquidity.sub(payableLiquidity);
      const loanLiquidity = loan0.liquidity.sub(writeDownAmt);

      const leftLiquidity = loanLiquidity.sub(payLiquidity);
      const initLiquidityPaid = payLiquidity
        .mul(loan0.initLiquidity)
        .div(loanLiquidity);
      const lpTokensPaid = payLiquidity.mul(loan0.lpTokens).div(loanLiquidity);
      const leftInitLiquidity = loan0.initLiquidity.sub(initLiquidityPaid);
      const leftLpTokens = loan0.lpTokens.sub(lpTokensPaid);
      const tokenAChange = payLiquidity.mul(amt0.mul(5)).div(loanLiquidity);
      const tokenBChange = payLiquidity.mul(amt1.mul(5)).div(loanLiquidity);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokenPayment.mul(2))
      ).wait();

      const ownerCFMMBal0 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal0 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      const _lastCFMMTotalSupply = await cfmm.totalSupply();
      const _reserves = await cfmm.getReserves();
      const _lastCFMMInvariant = sqrt(_reserves[0].mul(_reserves[1]));
      const _bal0 = (await liquidationStrategy.getPoolBalances()).bal;
      expect(_lastCFMMTotalSupply).to.equal(_bal0.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(_bal0.lastCFMMInvariant);

      const res = await (
        await liquidationStrategy._liquidateWithLP(tokenIds[0])
      ).wait();

      expect(res.events[res.events.length - 3].event).to.equal("Liquidation");
      expect(res.events[res.events.length - 3].args.liquidity).to.equal(
        payLiquidity
      );
      expect(res.events[res.events.length - 3].args.collateral).to.equal(
        sqrt(tokenAChange.mul(tokenBChange))
      );
      expect(res.events[res.events.length - 3].args.writeDownAmt).to.equal(
        writeDownAmt
      );
      expect(res.events[res.events.length - 3].args.txType).to.equal(12);

      const ownerCFMMBal1 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal1 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      expect(ownerCFMMBal1).to.equal(ownerCFMMBal0.add(lpTokenPayment));
      expect(stratCFMMBal1).to.equal(stratCFMMBal0.sub(lpTokenPayment));
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(tokenAChange));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(tokenBChange));
      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(tokenAChange));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(tokenBChange));

      const loan1 = await liquidationStrategy.getLoan(tokenIds[0]);

      expect(loan1.liquidity).to.equal(leftLiquidity);
      expect(loan1.initLiquidity).to.equal(leftInitLiquidity);
      expect(loan1.lpTokens).to.equal(leftLpTokens);
      expect(loan1.rateIndex).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(2);
      expect(loan1.tokensHeld[0]).to.equal(
        loan0.tokensHeld[0].sub(tokenAChange)
      );
      expect(loan1.tokensHeld[1]).to.equal(
        loan0.tokensHeld[1].sub(tokenBChange)
      );

      const poolBal1 = await liquidationStrategy.getPoolBalances();

      // must check also pool token balances and LP Balances and invariant, etc.
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances.length).to.equal(
        poolBal0.tokenBalances.length
      );
      expect(poolBal1.tokenBalances[0]).to.equal(
        poolBal0.tokenBalances[0].sub(tokenAChange)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        poolBal0.tokenBalances[1].sub(tokenBChange)
      );
      expect(poolBal1.bal.LP_TOKEN_BALANCE).to.equal(
        poolBal0.bal.LP_TOKEN_BALANCE.add(lpTokenPayment)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED.sub(lpTokensPaid)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST.sub(lpTokenPayment).sub(
          writeDownAmt.div(2)
        )
      );
      expect(poolBal1.bal.BORROWED_INVARIANT).to.equal(
        poolBal0.bal.BORROWED_INVARIANT.sub(payLiquidity).sub(writeDownAmt)
      );
      expect(poolBal1.bal.LP_INVARIANT).to.equal(
        poolBal0.bal.LP_INVARIANT.add(payLiquidity)
      );

      expect(_lastCFMMTotalSupply).to.equal(poolBal1.bal.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(poolBal1.bal.lastCFMMInvariant);

      const refundLiq = sqrt(tokenAChange.mul(tokenBChange));
      const refundGain = refundLiq.sub(payLiquidity);
      const refundGainPerc = refundGain.mul(ONE).div(payLiquidity);
      const denominator = ONE.mul(4875).div(1000);
      const numerator = ONE.mul(125).div(1000);
      const expGainPerc = numerator.mul(ONE).div(denominator);
      expect(refundGainPerc).to.equal(expGainPerc);

      // const collateral1 = sqrt(loan1.tokensHeld[0].mul(loan1.tokensHeld[1]));
      // const ltvRatio = loan1.liquidity.mul(ONE).div(collateral1);
      // expect(ltvRatio).lte(ONE.mul(975).div(1000));
      // expect(ltvRatio).gt(ONE.mul(974999).div(1000000));
      // expect(tokenAChange.mul(2)).to.equal(amt0.mul(5));
      // expect(tokenBChange.mul(2)).to.equal(amt1.mul(5));
    });
  });

  describe("batch liquidations", function () {
    it("returns error no liquidity to liquidate", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokens.mul(12))
      ).wait();

      await expect(
        liquidationStrategy._batchLiquidations(tokenIds)
      ).to.be.revertedWithCustomError(liquidationStrategy, "NoLiquidityDebt");
    });

    it("returns error InsufficientDeposit", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );

      await (await liquidationStrategy.incBorrowedInvariant(ONE)).wait();

      await expect(
        liquidationStrategy._batchLiquidations(tokenIds)
      ).to.be.revertedWithCustomError(
        liquidationStrategy,
        "InsufficientDeposit"
      );
    });

    it("liquidation, no write down", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        5
      );

      const invariantGrowth = ONE.mul(425).div(100);

      await (
        await liquidationStrategy.incBorrowedInvariant(invariantGrowth)
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const poolBal0 = await liquidationStrategy.getPoolBalances();

      const payLiquidity = ONE.mul(485).div(100).mul(5);
      const lpTokenPayment = payLiquidity.div(2); // paying half the lp token debt

      const tokenAChange = amt0.mul(25);
      const tokenBChange = amt1.mul(25);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokenPayment)
      ).wait();

      const ownerCFMMBal0 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal0 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      const _lastCFMMTotalSupply = await cfmm.totalSupply();
      const _reserves = await cfmm.getReserves();
      const _lastCFMMInvariant = sqrt(_reserves[0].mul(_reserves[1]));
      const _bal0 = (await liquidationStrategy.getPoolBalances()).bal;
      expect(_lastCFMMTotalSupply).to.equal(_bal0.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(_bal0.lastCFMMInvariant);

      const res = await (
        await liquidationStrategy._batchLiquidations(tokenIds)
      ).wait();

      const collateral = sqrt(tokenAChange.mul(tokenBChange));
      const fee = collateral.mul(250).div(10000);
      const debtPlusFee = payLiquidity.add(fee);
      const _tokenAChange = debtPlusFee.mul(tokenAChange).div(collateral);
      const _tokenBChange = debtPlusFee.mul(tokenBChange).div(collateral);

      for (let i = 0; i < tokenIds.length; i++) {
        expect(res.events[i].event).to.equal("LoanUpdated");
        expect(res.events[i].args.tokenId).to.equal(tokenIds[i]);
      }
      expect(res.events[res.events.length - 2].event).to.equal("Liquidation");
      expect(res.events[res.events.length - 2].args.liquidity).to.equal(
        payLiquidity
      );
      expect(res.events[res.events.length - 2].args.collateral).to.equal(
        sqrt(tokenAChange.mul(tokenBChange))
      );
      expect(res.events[res.events.length - 2].args.writeDownAmt).to.equal(0);
      expect(res.events[res.events.length - 2].args.txType).to.equal(13);

      const ownerCFMMBal1 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal1 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      expect(ownerCFMMBal1).to.equal(ownerCFMMBal0);
      expect(stratCFMMBal1).to.equal(stratCFMMBal0);
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(_tokenAChange));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(_tokenBChange));
      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(_tokenAChange));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(_tokenBChange));

      const remainAmt0 = amt0.mul(5).sub(_tokenAChange.div(5));
      const remainAmt1 = amt1.mul(5).sub(_tokenBChange.div(5));
      for (let i = 0; i < tokenIds.length; i++) {
        const loan1 = await liquidationStrategy.getLoan(tokenIds[i]);
        expect(loan1.poolId).to.equal(liquidationStrategy.address);
        expect(loan1.id).to.equal(i + 1);
        expect(loan1.liquidity).to.equal(0);
        expect(loan1.initLiquidity).to.equal(0);
        expect(loan1.lpTokens).to.equal(0);
        expect(loan1.rateIndex).to.equal(0);
        expect(loan1.heldLiquidity).to.equal(sqrt(remainAmt0.mul(remainAmt1)));
        expect(loan1.tokensHeld.length).to.equal(2);
        expect(loan1.tokensHeld[0]).to.equal(remainAmt0);
        expect(loan1.tokensHeld[1]).to.equal(remainAmt1);
      }

      const poolBal1 = await liquidationStrategy.getPoolBalances();

      // must check also pool token balances and LP Balances and invariant, etc.
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances.length).to.equal(
        poolBal0.tokenBalances.length
      );
      expect(poolBal1.tokenBalances[0]).to.equal(
        poolBal0.tokenBalances[0].sub(_tokenAChange)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        poolBal0.tokenBalances[1].sub(_tokenBChange)
      );
      expect(poolBal1.bal.LP_TOKEN_BALANCE).to.equal(
        poolBal0.bal.LP_TOKEN_BALANCE.add(lpTokenPayment)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED.sub(lpTokens.mul(5))
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST.sub(lpTokenPayment)
      );
      expect(poolBal1.bal.BORROWED_INVARIANT).to.equal(
        poolBal0.bal.BORROWED_INVARIANT.sub(payLiquidity)
      );
      expect(poolBal1.bal.LP_INVARIANT).to.equal(
        poolBal0.bal.LP_INVARIANT.add(payLiquidity)
      );

      expect(_lastCFMMTotalSupply).to.equal(poolBal1.bal.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(poolBal1.bal.lastCFMMInvariant);

      const refundLiq = sqrt(_tokenAChange.mul(_tokenBChange));
      const refundGain = refundLiq.sub(payLiquidity);
      const refundGainPerc = refundGain.mul(ONE).div(payLiquidity);
      const expGainPerc = ONE.mul(5).div(200);
      expect(refundGainPerc).gt(expGainPerc);
      expect(tokenAChange.mul(1)).to.equal(amt0.mul(25));
      expect(tokenBChange.mul(1)).to.equal(amt1.mul(25));
    });

    it("liquidation, write down", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        5
      );

      const invariantGrowth = ONE.mul(5);

      await (
        await liquidationStrategy.incBorrowedInvariant(invariantGrowth)
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const poolBal0 = await liquidationStrategy.getPoolBalances();

      const writeDownAmtPerLoan = ONE.mul(5).mul(25).div(1000);
      const writeDownTotal = writeDownAmtPerLoan.mul(5);
      const loanLiquidityTotal = ONE.mul(25);
      const payLiquidity = loanLiquidityTotal.sub(writeDownTotal);
      const lpTokenPayment = payLiquidity.div(2); // paying half the lp token debt

      const tokenAChange = amt0.mul(25);
      const tokenBChange = amt1.mul(25);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokenPayment)
      ).wait();

      const ownerCFMMBal0 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal0 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      const _lastCFMMTotalSupply = await cfmm.totalSupply();
      const _reserves = await cfmm.getReserves();
      const _lastCFMMInvariant = sqrt(_reserves[0].mul(_reserves[1]));
      const _bal0 = (await liquidationStrategy.getPoolBalances()).bal;
      expect(_lastCFMMTotalSupply).to.equal(_bal0.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(_bal0.lastCFMMInvariant);

      const res = await (
        await liquidationStrategy._batchLiquidations(tokenIds)
      ).wait();

      for (let i = 0; i < tokenIds.length; i++) {
        expect(res.events[i].event).to.equal("LoanUpdated");
        expect(res.events[i].args.tokenId).to.equal(tokenIds[i]);
      }
      expect(res.events[res.events.length - 2].event).to.equal("Liquidation");
      expect(res.events[res.events.length - 2].args.liquidity).to.equal(
        payLiquidity
      );
      expect(res.events[res.events.length - 2].args.collateral).to.equal(
        sqrt(tokenAChange.mul(tokenBChange))
      );
      expect(res.events[res.events.length - 2].args.writeDownAmt).to.equal(
        writeDownTotal
      );
      expect(res.events[res.events.length - 2].args.txType).to.equal(13);

      const ownerCFMMBal1 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal1 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      expect(ownerCFMMBal1).to.equal(ownerCFMMBal0);
      expect(stratCFMMBal1).to.equal(stratCFMMBal0);
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(tokenAChange));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(tokenBChange));
      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(tokenAChange));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(tokenBChange));

      for (let i = 0; i < tokenIds.length; i++) {
        const loan1 = await liquidationStrategy.getLoan(tokenIds[i]);
        expect(loan1.poolId).to.equal(liquidationStrategy.address);
        expect(loan1.id).to.equal(i + 1);
        expect(loan1.liquidity).to.equal(0);
        expect(loan1.initLiquidity).to.equal(0);
        expect(loan1.lpTokens).to.equal(0);
        expect(loan1.rateIndex).to.equal(0);
        expect(loan1.heldLiquidity).to.equal(0);
        expect(loan1.tokensHeld.length).to.equal(2);
        expect(loan1.tokensHeld[0]).to.equal(0);
        expect(loan1.tokensHeld[1]).to.equal(0);
      }

      const poolBal1 = await liquidationStrategy.getPoolBalances();

      // must check also pool token balances and LP Balances and invariant, etc.
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances.length).to.equal(
        poolBal0.tokenBalances.length
      );
      expect(poolBal1.tokenBalances[0]).to.equal(
        poolBal0.tokenBalances[0].sub(tokenAChange)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        poolBal0.tokenBalances[1].sub(tokenBChange)
      );
      expect(poolBal1.bal.LP_TOKEN_BALANCE).to.equal(
        poolBal0.bal.LP_TOKEN_BALANCE.add(lpTokenPayment)
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED.sub(lpTokens.mul(5))
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST.sub(
          loanLiquidityTotal.div(2)
        )
      );
      expect(poolBal1.bal.BORROWED_INVARIANT).to.equal(
        poolBal0.bal.BORROWED_INVARIANT.sub(loanLiquidityTotal)
      );
      expect(poolBal1.bal.LP_INVARIANT).to.equal(
        poolBal0.bal.LP_INVARIANT.add(payLiquidity)
      );

      expect(_lastCFMMTotalSupply).to.equal(poolBal1.bal.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(poolBal1.bal.lastCFMMInvariant);

      const refundLiq = sqrt(tokenAChange.mul(tokenBChange));
      const refundGain = refundLiq.sub(payLiquidity);
      const refundGainPerc = refundGain.mul(ONE).div(payLiquidity);
      const expGainPerc = ONE.mul(5).div(200);
      expect(refundGainPerc).gt(expGainPerc);
      expect(tokenAChange.mul(1)).to.equal(amt0.mul(25));
      expect(tokenBChange.mul(1)).to.equal(amt1.mul(25));
    });

    it("liquidation & refund, no write down", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        5
      );

      const invariantGrowth = ONE.mul(425).div(100);

      await (
        await liquidationStrategy.incBorrowedInvariant(invariantGrowth)
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const poolBal0 = await liquidationStrategy.getPoolBalances();

      const loanLiquidityTotal = ONE.mul(485).div(100).mul(5);
      const payLiquidity = ONE.mul(25);
      const lpTokenPayment = payLiquidity.div(2); // paying half the lp token debt

      const tokenAChange = amt0.mul(25);
      const tokenBChange = amt1.mul(25);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokenPayment)
      ).wait();

      const ownerCFMMBal0 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal0 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );
      const lpTokenRefund = payLiquidity.sub(loanLiquidityTotal).div(2);

      const _lastCFMMTotalSupply = await cfmm.totalSupply();
      const _reserves = await cfmm.getReserves();
      const _lastCFMMInvariant = sqrt(_reserves[0].mul(_reserves[1]));
      const _bal0 = (await liquidationStrategy.getPoolBalances()).bal;
      expect(_lastCFMMTotalSupply).to.equal(_bal0.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(_bal0.lastCFMMInvariant);

      const res = await (
        await liquidationStrategy._batchLiquidations(tokenIds)
      ).wait();

      const collateral = sqrt(tokenAChange.mul(tokenBChange));
      const fee = collateral.mul(250).div(10000);
      const debtPlusFee = loanLiquidityTotal.add(fee);
      const _tokenAChange = debtPlusFee.mul(tokenAChange).div(collateral);
      const _tokenBChange = debtPlusFee.mul(tokenBChange).div(collateral);

      for (let i = 0; i < tokenIds.length; i++) {
        expect(res.events[i].event).to.equal("LoanUpdated");
        expect(res.events[i].args.tokenId).to.equal(tokenIds[i]);
      }
      expect(res.events[res.events.length - 2].event).to.equal("Liquidation");
      expect(res.events[res.events.length - 2].args.liquidity).to.equal(
        loanLiquidityTotal
      );
      expect(res.events[res.events.length - 2].args.collateral).to.equal(
        sqrt(tokenAChange.mul(tokenBChange))
      );
      expect(res.events[res.events.length - 2].args.writeDownAmt).to.equal(0);
      expect(res.events[res.events.length - 2].args.txType).to.equal(13);

      const ownerCFMMBal1 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal1 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      expect(ownerCFMMBal1).to.equal(ownerCFMMBal0.add(lpTokenRefund));
      expect(stratCFMMBal1).to.equal(stratCFMMBal0.sub(lpTokenRefund));
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(_tokenAChange));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(_tokenBChange));
      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(_tokenAChange));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(_tokenBChange));

      const remainAmt0 = amt0.mul(5).sub(_tokenAChange.div(5));
      const remainAmt1 = amt1.mul(5).sub(_tokenBChange.div(5));
      for (let i = 0; i < tokenIds.length; i++) {
        const loan1 = await liquidationStrategy.getLoan(tokenIds[i]);
        expect(loan1.poolId).to.equal(liquidationStrategy.address);
        expect(loan1.id).to.equal(i + 1);
        expect(loan1.liquidity).to.equal(0);
        expect(loan1.initLiquidity).to.equal(0);
        expect(loan1.lpTokens).to.equal(0);
        expect(loan1.rateIndex).to.equal(0);
        expect(loan1.heldLiquidity).to.equal(sqrt(remainAmt0.mul(remainAmt1)));
        expect(loan1.tokensHeld.length).to.equal(2);
        expect(loan1.tokensHeld[0]).to.equal(remainAmt0);
        expect(loan1.tokensHeld[1]).to.equal(remainAmt1);
      }

      const poolBal1 = await liquidationStrategy.getPoolBalances();

      // must check also pool token balances and LP Balances and invariant, etc.
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances.length).to.equal(
        poolBal0.tokenBalances.length
      );
      expect(poolBal1.tokenBalances[0]).to.equal(
        poolBal0.tokenBalances[0].sub(_tokenAChange)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        poolBal0.tokenBalances[1].sub(_tokenBChange)
      );
      expect(poolBal1.bal.LP_TOKEN_BALANCE).to.equal(
        poolBal0.bal.LP_TOKEN_BALANCE.add(lpTokenPayment.sub(lpTokenRefund))
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED.sub(lpTokens.mul(5))
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST.sub(
          lpTokenPayment.sub(lpTokenRefund)
        )
      );
      expect(poolBal1.bal.BORROWED_INVARIANT).to.equal(
        poolBal0.bal.BORROWED_INVARIANT.sub(
          lpTokenPayment.sub(lpTokenRefund).mul(2)
        )
      );
      expect(poolBal1.bal.LP_INVARIANT).to.equal(
        poolBal0.bal.LP_INVARIANT.add(lpTokenPayment.sub(lpTokenRefund).mul(2))
      );

      expect(_lastCFMMTotalSupply).to.equal(poolBal1.bal.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(poolBal1.bal.lastCFMMInvariant);

      const payLiquidityAfterRefund = lpTokenPayment.sub(lpTokenRefund).mul(2);
      const refundLiq = sqrt(_tokenAChange.mul(_tokenBChange));
      const refundGain = refundLiq.sub(payLiquidityAfterRefund);
      const refundGainPerc = refundGain.mul(ONE).div(payLiquidityAfterRefund);
      const expGainPerc = ONE.mul(5).div(200);
      expect(refundGainPerc).gt(expGainPerc);
      expect(tokenAChange.mul(1)).to.equal(amt0.mul(25));
      expect(tokenBChange.mul(1)).to.equal(amt1.mul(25));
    });

    it("liquidation & refund, write down", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        5
      );

      const invariantGrowth = ONE.mul(5);

      await (
        await liquidationStrategy.incBorrowedInvariant(invariantGrowth)
      ).wait();

      await (await liquidationStrategy.updatePoolBalances()).wait();

      const poolBal0 = await liquidationStrategy.getPoolBalances();

      const writeDownAmtPerLoan = ONE.mul(5).mul(25).div(1000);
      const writeDownTotal = writeDownAmtPerLoan.mul(5);
      const loanLiquidityTotal = ONE.mul(25);
      const payLiquidity = loanLiquidityTotal;
      const lpTokenPayment = payLiquidity.div(2); // paying half the lp token debt
      const lpTokenRefund = writeDownTotal.div(2);

      const tokenAChange = amt0.mul(25);
      const tokenBChange = amt1.mul(25);

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokenPayment)
      ).wait();

      const ownerCFMMBal0 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal0 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal0 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal0 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal0 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal0 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      const _lastCFMMTotalSupply = await cfmm.totalSupply();
      const _reserves = await cfmm.getReserves();
      const _lastCFMMInvariant = sqrt(_reserves[0].mul(_reserves[1]));
      const _bal0 = (await liquidationStrategy.getPoolBalances()).bal;
      expect(_lastCFMMTotalSupply).to.equal(_bal0.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(_bal0.lastCFMMInvariant);

      const res = await (
        await liquidationStrategy._batchLiquidations(tokenIds)
      ).wait();

      for (let i = 0; i < tokenIds.length; i++) {
        expect(res.events[i].event).to.equal("LoanUpdated");
        expect(res.events[i].args.tokenId).to.equal(tokenIds[i]);
      }

      expect(res.events[res.events.length - 2].event).to.equal("Liquidation");
      expect(res.events[res.events.length - 2].args.liquidity).to.equal(
        loanLiquidityTotal.sub(writeDownTotal)
      );
      expect(res.events[res.events.length - 2].args.collateral).to.equal(
        sqrt(tokenAChange.mul(tokenBChange))
      );
      expect(res.events[res.events.length - 2].args.writeDownAmt).to.equal(
        writeDownTotal
      );
      expect(res.events[res.events.length - 2].args.txType).to.equal(13);

      const ownerCFMMBal1 = await cfmm.balanceOf(owner.address);
      const ownerTokenABal1 = await tokenA.balanceOf(owner.address);
      const ownerTokenBBal1 = await tokenB.balanceOf(owner.address);
      const stratCFMMBal1 = await cfmm.balanceOf(liquidationStrategy.address);
      const stratTokenABal1 = await tokenA.balanceOf(
        liquidationStrategy.address
      );
      const stratTokenBBal1 = await tokenB.balanceOf(
        liquidationStrategy.address
      );

      expect(ownerCFMMBal1).to.equal(ownerCFMMBal0.add(lpTokenRefund));
      expect(stratCFMMBal1).to.equal(stratCFMMBal0.sub(lpTokenRefund));
      expect(ownerTokenABal1).to.equal(ownerTokenABal0.add(tokenAChange));
      expect(ownerTokenBBal1).to.equal(ownerTokenBBal0.add(tokenBChange));
      expect(stratTokenABal1).to.equal(stratTokenABal0.sub(tokenAChange));
      expect(stratTokenBBal1).to.equal(stratTokenBBal0.sub(tokenBChange));

      for (let i = 0; i < tokenIds.length; i++) {
        const loan1 = await liquidationStrategy.getLoan(tokenIds[i]);
        expect(loan1.poolId).to.equal(liquidationStrategy.address);
        expect(loan1.id).to.equal(i + 1);
        expect(loan1.liquidity).to.equal(0);
        expect(loan1.initLiquidity).to.equal(0);
        expect(loan1.lpTokens).to.equal(0);
        expect(loan1.rateIndex).to.equal(0);
        expect(loan1.heldLiquidity).to.equal(0);
        expect(loan1.tokensHeld.length).to.equal(2);
        expect(loan1.tokensHeld[0]).to.equal(0);
        expect(loan1.tokensHeld[1]).to.equal(0);
      }

      const poolBal1 = await liquidationStrategy.getPoolBalances();

      // must check also pool token balances and LP Balances and invariant, etc.
      expect(poolBal1.tokenBalances.length).to.equal(2);
      expect(poolBal1.tokenBalances.length).to.equal(
        poolBal0.tokenBalances.length
      );
      expect(poolBal1.tokenBalances[0]).to.equal(
        poolBal0.tokenBalances[0].sub(tokenAChange)
      );
      expect(poolBal1.tokenBalances[1]).to.equal(
        poolBal0.tokenBalances[1].sub(tokenBChange)
      );
      expect(poolBal1.bal.LP_TOKEN_BALANCE).to.equal(
        poolBal0.bal.LP_TOKEN_BALANCE.add(lpTokenPayment.sub(lpTokenRefund))
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED.sub(lpTokens.mul(5))
      );
      expect(poolBal1.bal.LP_TOKEN_BORROWED_PLUS_INTEREST).to.equal(
        poolBal0.bal.LP_TOKEN_BORROWED_PLUS_INTEREST.sub(
          loanLiquidityTotal.div(2)
        )
      );
      expect(poolBal1.bal.BORROWED_INVARIANT).to.equal(
        poolBal0.bal.BORROWED_INVARIANT.sub(loanLiquidityTotal)
      );
      expect(poolBal1.bal.LP_INVARIANT).to.equal(
        poolBal0.bal.LP_INVARIANT.add(lpTokenPayment.sub(lpTokenRefund).mul(2))
      );

      expect(_lastCFMMTotalSupply).to.equal(poolBal1.bal.lastCFMMTotalSupply);
      expect(_lastCFMMInvariant).to.equal(poolBal1.bal.lastCFMMInvariant);

      const actualLiquidityPaid = lpTokenPayment.sub(lpTokenRefund).mul(2);
      const refundLiq = sqrt(tokenAChange.mul(tokenBChange));
      const refundGain = refundLiq.sub(actualLiquidityPaid);
      const refundGainPerc = refundGain.mul(ONE).div(actualLiquidityPaid);
      const expGainPerc = ONE.mul(5).div(200);
      expect(refundGainPerc).gt(expGainPerc);
      expect(tokenAChange.mul(1)).to.equal(amt0.mul(25));
      expect(tokenBChange.mul(1)).to.equal(amt1.mul(25));
    });
  });

  describe("liquidate with collateral", function () {
    it("returns error HasMargin", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );

      await (
        await cfmm.transfer(liquidationStrategy.address, lpTokens.mul(12))
      ).wait();

      // function _liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external override lock virtual returns(uint256[] memory refund)
      await expect(
        liquidationStrategy._liquidate(tokenIds[0])
      ).to.be.revertedWithCustomError(liquidationStrategy, "HasMargin");
      await expect(
        liquidationStrategy._liquidate(tokenIds[0])
      ).to.be.revertedWithCustomError(liquidationStrategy, "HasMargin");
    });

    it("error, loan does not exist", async function () {
      const lpTokens = ONE.mul(2);
      const amt0 = ONE.mul(1);
      const amt1 = ONE.mul(1);

      const tokenIds = await borrowLiquidity(
        amt0.mul(1),
        amt1.mul(1),
        lpTokens,
        1
      );

      await expect(
        liquidationStrategy._liquidate(BigNumber.from(tokenIds[0]).add(1))
      ).to.be.revertedWithCustomError(liquidationStrategy, "LoanDoesNotExist");
    });
  });
});
