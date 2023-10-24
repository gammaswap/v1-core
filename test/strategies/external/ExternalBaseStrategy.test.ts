import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe("ExternalBaseStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let TestFactory: any;
  let TestCalleeEmpty: any;
  let TestCallee: any;
  let TestCallee2: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let strategy: any;
  let factory: any;
  let owner: any;
  let addr1: any;
  let calleeEmpty: any;
  let callee: any;
  let callee2: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCFMM = await ethers.getContractFactory("TestCFMM");
    TestStrategy = await ethers.getContractFactory("TestExternalBaseStrategy");
    TestCalleeEmpty = await ethers.getContractFactory(
      "TestExternalCalleeEmpty"
    );
    TestCallee = await ethers.getContractFactory("TestExternalCallee");
    TestCallee2 = await ethers.getContractFactory("TestExternalCallee2");
    TestFactory = await ethers.getContractFactory("TestGammaPoolFactory2");
    [owner, addr1] = await ethers.getSigners();

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    cfmm = await TestCFMM.deploy(
      tokenA.address,
      tokenB.address,
      "Test CFMM",
      "TCFMM"
    );

    calleeEmpty = await TestCalleeEmpty.deploy();
    callee = await TestCallee.deploy();
    callee2 = await TestCallee2.deploy();

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

    const ONE = BigNumber.from(10).pow(18);
    await (await tokenA.transfer(cfmm.address, ONE.mul(200))).wait();
    await (await tokenB.transfer(cfmm.address, ONE.mul(400))).wait();
    await (await cfmm.mint(ONE.mul(200), owner.address)).wait();
    await (await cfmm.transfer(strategy.address, ONE.mul(100))).wait();
    await (await strategy.updatePoolBalances()).wait();
  });

  function calcExpectedFee(
    liquiditySwapped: BigNumber,
    loanLiquidity: BigNumber,
    fee: any
  ) {
    return liquiditySwapped.sub(loanLiquidity).mul(fee).div(10000);
  }

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

  async function createLoan(
    amount0: BigNumber,
    amount1: BigNumber,
    liquidity: BigNumber
  ) {
    await (await tokenA.transfer(strategy.address, amount0)).wait();
    await (await tokenB.transfer(strategy.address, amount1)).wait();

    const res = await (await strategy.createLoan(liquidity)).wait();
    expect(res.events[0].event).to.equal("LoanCreated");
    return res.events[0].args.tokenId;
  }

  function getLPShare(
    amount: BigNumber,
    lastCFMMTotalSupply: BigNumber,
    reserve: BigNumber
  ) {
    if (ethers.constants.Zero.eq(amount)) {
      return ethers.constants.Zero;
    }
    return amount.mul(lastCFMMTotalSupply).div(reserve);
  }

  function calcCollateralAsLPTokens(
    amounts: any[],
    lastCFMMTotalSupply: BigNumber,
    reserve: any[]
  ) {
    let lpShares = ethers.constants.Zero;
    for (let i = 0; i < amounts.length; i++) {
      const tmpLpShares = getLPShare(
        amounts[i],
        lastCFMMTotalSupply.div(amounts.length),
        reserve[i]
      );
      lpShares = lpShares.add(tmpLpShares);
    }
    return lpShares;
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set right init params", async function () {
      const params = await strategy.getParameters();
      expect(params.cfmm).to.equal(cfmm.address);
      expect(params.tokens[0]).to.equal(tokenA.address);
      expect(params.tokens[1]).to.equal(tokenB.address);
      expect(params._protocolId).to.equal(PROTOCOL_ID);

      const ONE = BigNumber.from(10).pow(18);
      const poolBalances = await strategy.getPoolBalances();
      const amount0 = ONE.mul(200);
      const amount1 = ONE.mul(400);
      const invariant = sqrt(amount0.mul(amount1));
      expect(poolBalances.lastCFMMInvariant).to.equal(invariant);
      expect(poolBalances.lastCFMMTotalSupply).to.equal(ONE.mul(200));
      expect(poolBalances.cfmmReserves[0]).to.equal(amount0);
      expect(poolBalances.cfmmReserves[1]).to.equal(amount1);
      expect(poolBalances.tokenBalances[0]).to.equal(0);
      expect(poolBalances.tokenBalances[1]).to.equal(0);
      expect(poolBalances.lpTokenBalance).to.equal(ONE.mul(100));
      expect(poolBalances.lpInvariant).to.equal(invariant.div(2));
      expect(await cfmm.balanceOf(strategy.address)).to.equal(ONE.mul(100));

      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);

      expect(await cfmm.balanceOf(owner.address)).to.equal(ONE.mul(100));
    });

    it("Create Test Loan", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      const loan = await strategy.getLoan(tokenId);
      expect(loan.tokensHeld.length).to.equal(2);
      expect(loan.tokensHeld[0]).to.equal(amount0);
      expect(loan.tokensHeld[1]).to.equal(amount1);
      const heldLiquidity = sqrt(amount0.mul(amount1));
      expect(loan.heldLiquidity).to.equal(heldLiquidity);
      expect(loan.liquidity).to.equal(liquidity);
      expect(loan.lpTokens).to.equal(heldLiquidity.div(2));
      expect(loan.rateIndex).to.equal(ONE);

      const poolBalances = await strategy.getPoolBalances();
      expect(poolBalances.tokenBalances[0]).to.equal(amount0);
      expect(poolBalances.tokenBalances[1]).to.equal(amount1);
    });
  });

  describe("Helper functions", function () {
    it("Error Send & Calc Collateral Tokens", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      await createLoan(amount0, amount1, liquidity);
      const poolBalances = await strategy.getPoolBalances();

      await expect(
        strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          [0, amount1.add(1)],
          poolBalances.lastCFMMTotalSupply
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughBalance");

      await expect(
        strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          [amount0.add(1), 0],
          poolBalances.lastCFMMTotalSupply
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughBalance");

      await expect(
        strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          [amount0, amount1.add(1)],
          poolBalances.lastCFMMTotalSupply
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughBalance");

      await expect(
        strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          [amount0.add(1), amount1],
          poolBalances.lastCFMMTotalSupply
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughBalance");

      await expect(
        strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          [amount0.add(1), amount1.add(1)],
          poolBalances.lastCFMMTotalSupply
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughBalance");
    });

    it("Send & Calc Collateral Tokens, tokenA", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      await createLoan(amount0, amount1, liquidity);
      const poolBalances = await strategy.getPoolBalances();
      const amounts = [amount0.div(2), 0];

      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA0 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB0 = await tokenB.balanceOf(addr1.address);
      const reserves = poolBalances.cfmmReserves;
      const collateralAsLPTokens = calcCollateralAsLPTokens(
        amounts,
        poolBalances.lastCFMMTotalSupply,
        reserves
      );
      const res = await (
        await strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          amounts,
          poolBalances.lastCFMMTotalSupply
        )
      ).wait();
      const events = res.events;
      const idx = events.length - 1;
      expect(events[idx].event).to.equal("SwapCollateral");
      expect(events[idx].args.collateral).to.equal(collateralAsLPTokens);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA1 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB1 = await tokenB.balanceOf(addr1.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amounts[0]));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amounts[1]));
      expect(addr1BalanceA1).to.equal(addr1BalanceA0.add(amounts[0]));
      expect(addr1BalanceB1).to.equal(addr1BalanceB0.add(amounts[1]));
    });

    it("Send & Calc Collateral Tokens, tokenB", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      await createLoan(amount0, amount1, liquidity);
      const poolBalances = await strategy.getPoolBalances();
      const amounts = [0, amount1.div(2)];

      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA0 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB0 = await tokenB.balanceOf(addr1.address);
      const reserves = poolBalances.cfmmReserves;
      const collateralAsLPTokens = calcCollateralAsLPTokens(
        amounts,
        poolBalances.lastCFMMTotalSupply,
        reserves
      );
      const res = await (
        await strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          amounts,
          poolBalances.lastCFMMTotalSupply
        )
      ).wait();
      const events = res.events;
      const idx = events.length - 1;
      expect(events[idx].event).to.equal("SwapCollateral");
      expect(events[idx].args.collateral).to.equal(collateralAsLPTokens);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA1 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB1 = await tokenB.balanceOf(addr1.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amounts[0]));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amounts[1]));
      expect(addr1BalanceA1).to.equal(addr1BalanceA0.add(amounts[0]));
      expect(addr1BalanceB1).to.equal(addr1BalanceB0.add(amounts[1]));
    });

    it("Send & Calc Collateral Tokens, tokenA & tokenB", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      await createLoan(amount0, amount1, liquidity);
      const poolBalances = await strategy.getPoolBalances();
      const amounts = [amount0.div(2), amount1.div(2)];

      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA0 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB0 = await tokenB.balanceOf(addr1.address);
      const reserves = poolBalances.cfmmReserves;
      const collateralAsLPTokens = calcCollateralAsLPTokens(
        amounts,
        poolBalances.lastCFMMTotalSupply,
        reserves
      );
      const res = await (
        await strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          amounts,
          poolBalances.lastCFMMTotalSupply
        )
      ).wait();
      const events = res.events;
      const idx = events.length - 1;
      expect(events[idx].event).to.equal("SwapCollateral");
      expect(events[idx].args.collateral).to.equal(collateralAsLPTokens);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA1 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB1 = await tokenB.balanceOf(addr1.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amounts[0]));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amounts[1]));
      expect(addr1BalanceA1).to.equal(addr1BalanceA0.add(amounts[0]));
      expect(addr1BalanceB1).to.equal(addr1BalanceB0.add(amounts[1]));
    });

    it("Send & Calc Collateral Tokens, tokenA different amount", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      await createLoan(amount0, amount1, liquidity);
      const poolBalances = await strategy.getPoolBalances();

      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA0 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB0 = await tokenB.balanceOf(addr1.address);
      const reserves = poolBalances.cfmmReserves;
      const amounts = [amount0.div(2), amount1.div(2)];
      const collateralAsLPTokens = calcCollateralAsLPTokens(
        amounts,
        poolBalances.lastCFMMTotalSupply,
        reserves
      );
      const res = await (
        await strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          amounts,
          poolBalances.lastCFMMTotalSupply
        )
      ).wait();
      const events = res.events;
      const idx = events.length - 1;
      expect(events[idx].event).to.equal("SwapCollateral");
      expect(events[idx].args.collateral).to.equal(collateralAsLPTokens);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA1 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB1 = await tokenB.balanceOf(addr1.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amounts[0]));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amounts[1]));
      expect(addr1BalanceA1).to.equal(addr1BalanceA0.add(amounts[0]));
      expect(addr1BalanceB1).to.equal(addr1BalanceB0.add(amounts[1]));
    });

    it("Send & Calc Collateral Tokens, tokenB different amount", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      await createLoan(amount0, amount1, liquidity);
      const poolBalances = await strategy.getPoolBalances();

      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA0 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB0 = await tokenB.balanceOf(addr1.address);
      const reserves = poolBalances.cfmmReserves;
      const amounts = [amount0.div(2), amount1.div(2)];
      const collateralAsLPTokens = calcCollateralAsLPTokens(
        amounts,
        poolBalances.lastCFMMTotalSupply,
        reserves
      );
      const res = await (
        await strategy.testSendAndCalcCollateralLPTokens(
          addr1.address,
          amounts,
          poolBalances.lastCFMMTotalSupply
        )
      ).wait();
      const events = res.events;
      const idx = events.length - 1;
      expect(events[idx].event).to.equal("SwapCollateral");
      expect(events[idx].args.collateral).to.equal(collateralAsLPTokens);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const addr1BalanceA1 = await tokenA.balanceOf(addr1.address);
      const addr1BalanceB1 = await tokenB.balanceOf(addr1.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amounts[0]));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amounts[1]));
      expect(addr1BalanceA1).to.equal(addr1BalanceA0.add(amounts[0]));
      expect(addr1BalanceB1).to.equal(addr1BalanceB0.add(amounts[1]));
    });

    it("External swap fee is zero", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const liquiditySwapped = ONE.mul(100);
      const loanLiquidity = ONE.mul(200);
      expect(
        await strategy.testCalcExternalSwapFee(liquiditySwapped, loanLiquidity)
      ).to.equal(0);

      expect(
        await strategy.testCalcExternalSwapFee(
          liquiditySwapped,
          liquiditySwapped
        )
      ).to.equal(0);

      expect(
        await strategy.testCalcExternalSwapFee(loanLiquidity, loanLiquidity)
      ).to.equal(0);
    });

    it("External swap fee is gt zero", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const liquiditySwapped = ONE.mul(200);
      const loanLiquidity = ONE.mul(100);
      expect(
        await strategy.testCalcExternalSwapFee(liquiditySwapped, loanLiquidity)
      ).to.equal(0);

      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);

      expect(calcExpectedFee(liquiditySwapped, loanLiquidity, 10)).gt(0);

      expect(
        await strategy.testCalcExternalSwapFee(liquiditySwapped, loanLiquidity)
      ).to.equal(calcExpectedFee(liquiditySwapped, loanLiquidity, 10));

      expect(
        await strategy.testCalcExternalSwapFee(
          liquiditySwapped.mul(2),
          loanLiquidity
        )
      ).to.equal(calcExpectedFee(liquiditySwapped.mul(2), loanLiquidity, 10));

      expect(await strategy.swapFee()).to.equal(10);
      await strategy.setExternalSwapFee(20);
      expect(await strategy.swapFee()).to.equal(20);

      expect(
        await strategy.testCalcExternalSwapFee(
          liquiditySwapped.mul(3),
          loanLiquidity.mul(2)
        )
      ).to.equal(
        calcExpectedFee(liquiditySwapped.mul(3), loanLiquidity.mul(2), 20)
      );

      expect(
        await strategy.testCalcExternalSwapFee(
          liquiditySwapped.mul(4),
          loanLiquidity.mul(2)
        )
      ).to.equal(
        calcExpectedFee(liquiditySwapped.mul(4), loanLiquidity.mul(2), 20)
      );

      expect(
        await strategy.testCalcExternalSwapFee(
          liquiditySwapped.mul(4),
          loanLiquidity.mul(3)
        )
      ).to.equal(
        calcExpectedFee(liquiditySwapped.mul(4), loanLiquidity.mul(3), 20)
      );

      expect(
        await strategy.testCalcExternalSwapFee(
          liquiditySwapped.mul(4),
          loanLiquidity.mul(4)
        )
      ).to.equal(
        calcExpectedFee(liquiditySwapped.mul(4), loanLiquidity.mul(4), 20)
      );

      expect(
        await strategy.testCalcExternalSwapFee(
          liquiditySwapped.mul(4),
          loanLiquidity.mul(8)
        )
      ).to.equal(0);
    });

    it("Error Send CFMM LP Tokens", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount = ONE.mul(100).add(1);
      await expect(
        strategy.testSendCFMMLPTokens(cfmm.address, addr1.address, amount)
      ).to.be.revertedWithCustomError(strategy, "NotEnoughBalance");
    });

    it("Send CFMM LP Tokens", async function () {
      const ONE = BigNumber.from(10).pow(18);

      const strategyBalance = await cfmm.balanceOf(strategy.address);
      const addr1Balance = await cfmm.balanceOf(addr1.address);

      const amount = ONE.mul(10);
      const res = await (
        await strategy.testSendCFMMLPTokens(cfmm.address, addr1.address, amount)
      ).wait();

      const events = res.events;
      expect(events[0].event).to.equal("Transfer");
      expect(events[0].args.from).to.equal(strategy.address);
      expect(events[0].args.to).to.equal(addr1.address);
      expect(events[0].args.amount).to.equal(amount);
      expect(events[1].event).to.equal("SendLPTokens");
      expect(events[1].args.lpTokens).to.equal(amount);

      const strategyBalance1 = await cfmm.balanceOf(strategy.address);
      const addr1Balance1 = await cfmm.balanceOf(addr1.address);
      expect(strategyBalance1).to.equal(strategyBalance.sub(amount));
      expect(addr1Balance1).to.equal(addr1Balance.add(amount));
    });
  });

  describe("External Swap", function () {
    it("Error External swap non-contract", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      const amounts = [amount0.div(2), amount1.div(2)];
      const lpTokens = ONE.mul(20);

      const data = ethers.utils.defaultAbiCoder.encode([], []);

      await expect(
        strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts,
          lpTokens,
          addr1.address,
          data
        )
      ).to.be.revertedWithoutReason();
    });

    it("Error External swap WrongLPTokenBalance", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      const amounts = [amount0.div(2), amount1.div(2)];
      const lpTokens = ONE.mul(20);

      const data = ethers.utils.defaultAbiCoder.encode([], []);
      await expect(
        strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts,
          lpTokens,
          calleeEmpty.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "WrongLPTokenBalance");
    });

    it("External swap function no change", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      const loan0 = await strategy.getLoan(tokenId);
      const poolBalances0 = await strategy.getPoolBalances();

      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const data = ethers.utils.defaultAbiCoder.encode([], []);
      await (
        await strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          [],
          0,
          calleeEmpty.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).to.equal(
        poolBalances0.lpTokenBalance
      );
      expect(poolBalances1.lpInvariant).to.equal(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).to.equal(
        poolBalances0.tokenBalances[0]
      );
      expect(poolBalances1.tokenBalances[1]).to.equal(
        poolBalances0.tokenBalances[1]
      );
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(loan0.liquidity);
      expect(loan1.initLiquidity).to.equal(loan0.initLiquidity);
      expect(loan1.lpTokens).to.equal(loan0.lpTokens);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(loan0.tokensHeld[0]);
      expect(loan1.tokensHeld[1]).to.equal(loan0.tokensHeld[1]);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0);
      expect(strategyBalanceB1).to.equal(strategyBalanceB0);
      expect(strategyCfmmBalance1).to.equal(strategyCfmmBalance0);
    });

    it("External swap function return same amounts", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      const loan0 = await strategy.getLoan(tokenId);
      const poolBalances0 = await strategy.getPoolBalances();
      const amounts = [amount0.div(2), amount1.div(2)];

      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: 0,
        amount1: 0,
        lpTokens: 0,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );
      await (
        await strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts,
          0,
          callee.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).to.equal(
        poolBalances0.lpTokenBalance
      );
      expect(poolBalances1.lpInvariant).to.equal(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).to.equal(
        poolBalances0.tokenBalances[0]
      );
      expect(poolBalances1.tokenBalances[1]).to.equal(
        poolBalances0.tokenBalances[1]
      );
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(loan0.liquidity);
      expect(loan1.initLiquidity).to.equal(loan0.initLiquidity);
      expect(loan1.lpTokens).to.equal(loan0.lpTokens);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(loan0.tokensHeld[0]);
      expect(loan1.tokensHeld[1]).to.equal(loan0.tokensHeld[1]);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0);
      expect(strategyBalanceB1).to.equal(strategyBalanceB0);
      expect(strategyCfmmBalance1).to.equal(strategyCfmmBalance0);
    });

    it("External swap function return same lpTokens", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      const loan0 = await strategy.getLoan(tokenId);
      const poolBalances0 = await strategy.getPoolBalances();

      const lpTokens = ONE.mul(20);
      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: 0,
        amount1: 0,
        lpTokens: 0,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );
      await (
        await strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          [],
          lpTokens,
          callee.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).to.equal(
        poolBalances0.lpTokenBalance
      );
      expect(poolBalances1.lpInvariant).to.equal(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).to.equal(
        poolBalances0.tokenBalances[0]
      );
      expect(poolBalances1.tokenBalances[1]).to.equal(
        poolBalances0.tokenBalances[1]
      );
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(loan0.liquidity);
      expect(loan1.initLiquidity).to.equal(loan0.initLiquidity);
      expect(loan1.lpTokens).to.equal(loan0.lpTokens);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(loan0.tokensHeld[0]);
      expect(loan1.tokensHeld[1]).to.equal(loan0.tokensHeld[1]);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0);
      expect(strategyBalanceB1).to.equal(strategyBalanceB0);
      expect(strategyCfmmBalance1).to.equal(strategyCfmmBalance0);
    });

    it("External swap function return same amounts & lpTokens", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      const loan0 = await strategy.getLoan(tokenId);
      const poolBalances0 = await strategy.getPoolBalances();

      const amounts = [amount0, amount1];
      const lpTokens = ONE.mul(20);
      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: 0,
        amount1: 0,
        lpTokens: 0,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );
      await (
        await strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts,
          lpTokens,
          callee.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).to.equal(
        poolBalances0.lpTokenBalance
      );
      expect(poolBalances1.lpInvariant).to.equal(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).to.equal(
        poolBalances0.tokenBalances[0]
      );
      expect(poolBalances1.tokenBalances[1]).to.equal(
        poolBalances0.tokenBalances[1]
      );
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(loan0.liquidity);
      expect(loan1.initLiquidity).to.equal(loan0.initLiquidity);
      expect(loan1.lpTokens).to.equal(loan0.lpTokens);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(loan0.tokensHeld[0]);
      expect(loan1.tokensHeld[1]).to.equal(loan0.tokensHeld[1]);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0);
      expect(strategyBalanceB1).to.equal(strategyBalanceB0);
      expect(strategyCfmmBalance1).to.equal(strategyCfmmBalance0);
    });

    it("Error External swap function rebalance amounts, NotEnoughBalance", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      await strategy.getLoan(tokenId);
      await strategy.getPoolBalances();

      await (await tokenA.transfer(strategy.address, amount0)).wait();
      await (await tokenB.transfer(strategy.address, amount1)).wait();

      const amounts = [amount0.add(1), amount1];
      const lpTokens = ONE.mul(20);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amount0.div(2),
        amount1: amount1.div(2),
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await expect(
        strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughBalance");

      const amounts1 = [amount0, amount1.add(1)];
      await expect(
        strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts1,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughBalance");
    });

    it("Error External swap function rebalance amounts, NotEnoughCollateral", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      await strategy.getLoan(tokenId);
      await strategy.getPoolBalances();

      await (await tokenA.transfer(strategy.address, amount0)).wait();
      await (await tokenB.transfer(strategy.address, amount1)).wait();
      await createLoan(amount0, amount1, liquidity);

      const lpTokens = ONE.mul(20);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: 0,
        amount1: amount1,
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );
      const amounts = [amount0.add(1), amount1];

      await expect(
        strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughCollateral");

      const swapData1 = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amount0,
        amount1: 0,
        lpTokens: lpTokens,
      };
      const data1 = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData1]
      );
      const amounts1 = [amount0, amount1.add(1)];
      await expect(
        strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts1,
          lpTokens,
          callee2.address,
          data1
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughCollateral");
    });

    it("External swap function rebalance amounts, one loan", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      const loan0 = await strategy.getLoan(tokenId);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0]).to.equal(loan0.tokensHeld[0]);
      expect(poolBalances0.tokenBalances[1]).to.equal(loan0.tokensHeld[1]);

      const amounts = [amount0, amount1];
      const lpTokens = ONE.mul(20);
      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amount0.div(2),
        amount1: amount1.div(2),
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );
      await (
        await strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).to.equal(
        poolBalances0.lpTokenBalance
      );
      expect(poolBalances1.lpInvariant).to.equal(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).to.equal(
        poolBalances0.tokenBalances[0].sub(amount0.div(2))
      );
      expect(poolBalances1.tokenBalances[1]).to.equal(
        poolBalances0.tokenBalances[1].sub(amount1.div(2))
      );
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(loan0.liquidity);
      expect(loan1.initLiquidity).to.equal(loan0.initLiquidity);
      expect(loan1.lpTokens).to.equal(loan0.lpTokens);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(
        loan0.tokensHeld[0].sub(amount0.div(2))
      );
      expect(loan1.tokensHeld[1]).to.equal(
        loan0.tokensHeld[1].sub(amount1.div(2))
      );

      expect(poolBalances1.tokenBalances[0]).to.equal(loan1.tokensHeld[0]);
      expect(poolBalances1.tokenBalances[1]).to.equal(loan1.tokensHeld[1]);

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0.div(2)));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1.div(2)));
      expect(strategyCfmmBalance1).to.equal(strategyCfmmBalance0);
    });

    it("External swap function rebalance amounts, two loans", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE.mul(10);
      const tokenId = await createLoan(amount0, amount1, liquidity);
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [amount0, amount1];
      const lpTokens = ONE.mul(20);
      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amount0.div(2),
        amount1: amount1.div(2),
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );
      await (
        await strategy.testExternalSwap(
          tokenId,
          cfmm.address,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).to.equal(
        poolBalances0.lpTokenBalance
      );
      expect(poolBalances1.lpInvariant).to.equal(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).to.equal(
        poolBalances0.tokenBalances[0].sub(amount0.div(2))
      );
      expect(poolBalances1.tokenBalances[1]).to.equal(
        poolBalances0.tokenBalances[1].sub(amount1.div(2))
      );
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(loan0.liquidity);
      expect(loan1.initLiquidity).to.equal(loan0.initLiquidity);
      expect(loan1.lpTokens).to.equal(loan0.lpTokens);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(
        loan0.tokensHeld[0].sub(amount0.div(2))
      );
      expect(loan1.tokensHeld[1]).to.equal(
        loan0.tokensHeld[1].sub(amount1.div(2))
      );

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0.div(2)));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1.div(2)));
      expect(strategyCfmmBalance1).to.equal(strategyCfmmBalance0);
    });
  });
});
