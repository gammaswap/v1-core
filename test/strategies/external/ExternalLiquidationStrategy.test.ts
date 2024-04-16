import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe("ExternalLiquidationStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let TestCallee2: any;
  let TestFactory: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let strategy: any;
  let factory: any;
  let owner: any;
  let callee2: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCFMM = await ethers.getContractFactory("TestCFMM");
    TestStrategy = await ethers.getContractFactory(
      "TestExternalLiquidationStrategy"
    );
    TestCallee2 = await ethers.getContractFactory("TestExternalCallee2");
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
    callee2 = await TestCallee2.deploy();

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

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set right init params", async function () {
      expect(await strategy.liquidationFee()).to.equal(250);
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
      expect(loan.liquidity).to.equal(
        liquidity.add(liquidity.mul(2).div(10000)) // 2bps fee
      );
      expect(loan.lpTokens).to.equal(heldLiquidity.div(2));
      expect(loan.rateIndex).to.equal(ONE);

      const poolBalances = await strategy.getPoolBalances();
      expect(poolBalances.tokenBalances[0]).to.equal(amount0);
      expect(poolBalances.tokenBalances[1]).to.equal(amount1);
    });
  });

  // You can nest describe calls to create subsections.
  describe("Successful Liquidations", function () {
    it("Deposit LP tokens, no swaps", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [0, 0];
      const lpTokens = 0;
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
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();
      await (
        await strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).gt(poolBalances0.lpTokenBalance);
      expect(poolBalances1.lpInvariant).gt(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).lt(poolBalances0.tokenBalances[0]);
      expect(poolBalances1.tokenBalances[1]).lt(poolBalances0.tokenBalances[1]);
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(0);
      expect(loan1.initLiquidity).to.equal(0);
      expect(loan1.lpTokens).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(0);
      expect(loan1.tokensHeld[1]).to.equal(0);

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1));
      expect(strategyCfmmBalance1).gt(strategyCfmmBalance0);
    });

    it("Deposit LP tokens, swap only CFMM LP tokens", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [0, 0];
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
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();
      await (
        await strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).gt(poolBalances0.lpTokenBalance);
      expect(poolBalances1.lpInvariant).gt(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).lt(poolBalances0.tokenBalances[0]);
      expect(poolBalances1.tokenBalances[1]).lt(poolBalances0.tokenBalances[1]);
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(0);
      expect(loan1.initLiquidity).to.equal(0);
      expect(loan1.lpTokens).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(0);
      expect(loan1.tokensHeld[1]).to.equal(0);

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1));
      expect(strategyCfmmBalance1).gt(strategyCfmmBalance0);
    });

    it("Deposit LP tokens, withdraw tokenA", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [amount0.mul(2), amount1.mul(0)];
      const lpTokens = 0;
      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amounts[0],
        amount1: amounts[1],
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();
      await (
        await strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).gt(poolBalances0.lpTokenBalance);
      expect(poolBalances1.lpInvariant).gt(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).lt(poolBalances0.tokenBalances[0]);
      expect(poolBalances1.tokenBalances[1]).lt(poolBalances0.tokenBalances[1]);
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(0);
      expect(loan1.initLiquidity).to.equal(0);
      expect(loan1.lpTokens).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(0);
      expect(loan1.tokensHeld[1]).to.equal(0);

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1));
      expect(strategyCfmmBalance1).gt(strategyCfmmBalance0);
    });

    it("Deposit LP tokens, withdraw tokenB", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [amount0.mul(0), amount1.mul(2)];
      const lpTokens = 0;
      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amounts[0],
        amount1: amounts[1],
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();
      await (
        await strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).gt(poolBalances0.lpTokenBalance);
      expect(poolBalances1.lpInvariant).gt(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).lt(poolBalances0.tokenBalances[0]);
      expect(poolBalances1.tokenBalances[1]).lt(poolBalances0.tokenBalances[1]);
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(0);
      expect(loan1.initLiquidity).to.equal(0);
      expect(loan1.lpTokens).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(0);
      expect(loan1.tokensHeld[1]).to.equal(0);

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1));
      expect(strategyCfmmBalance1).gt(strategyCfmmBalance0);
    });

    it("Deposit LP tokens, withdraw both tokens", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [amount0.mul(2), amount1.mul(2)];
      const lpTokens = 0;
      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amounts[0],
        amount1: amounts[1],
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();
      await (
        await strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).gt(poolBalances0.lpTokenBalance);
      expect(poolBalances1.lpInvariant).gt(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).lt(poolBalances0.tokenBalances[0]);
      expect(poolBalances1.tokenBalances[1]).lt(poolBalances0.tokenBalances[1]);
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(0);
      expect(loan1.initLiquidity).to.equal(0);
      expect(loan1.lpTokens).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(0);
      expect(loan1.tokensHeld[1]).to.equal(0);

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1));
      expect(strategyCfmmBalance1).gt(strategyCfmmBalance0);
    });

    it("Deposit LP tokens, withdraw both tokens and CFMM LP tokens", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [amount0.mul(2), amount1.mul(2)];
      const lpTokens = ONE.mul(20);
      const strategyBalanceA0 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB0 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance0 = await cfmm.balanceOf(strategy.address);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amounts[0],
        amount1: amounts[1],
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();
      await (
        await strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).gt(poolBalances0.lpTokenBalance);
      expect(poolBalances1.lpInvariant).gt(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).lt(poolBalances0.tokenBalances[0]);
      expect(poolBalances1.tokenBalances[1]).lt(poolBalances0.tokenBalances[1]);
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(0);
      expect(loan1.initLiquidity).to.equal(0);
      expect(loan1.lpTokens).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(0);
      expect(loan1.tokensHeld[1]).to.equal(0);

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1));
      expect(strategyCfmmBalance1).gt(strategyCfmmBalance0);
    });

    it("Deposit LP tokens, withdraw both tokens and CFMM LP tokens, don't return all collateral tokens", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
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
        amount0: amounts[0].sub(1),
        amount1: amounts[1],
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();

      await expect(
        strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "CollateralShortfall");

      swapData.amount0 = amounts[0];
      swapData.amount1 = amounts[1].sub(1);

      const data1 = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await expect(
        strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data1
        )
      ).to.be.revertedWithCustomError(strategy, "CollateralShortfall");

      swapData.amount0 = amounts[0];
      swapData.amount1 = amounts[1];

      const data2 = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (
        await strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data2
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).gt(poolBalances0.lpTokenBalance);
      expect(poolBalances1.lpInvariant).gt(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).lt(poolBalances0.tokenBalances[0]);
      expect(poolBalances1.tokenBalances[1]).lt(poolBalances0.tokenBalances[1]);
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(0);
      expect(loan1.initLiquidity).to.equal(0);
      expect(loan1.lpTokens).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(0);
      expect(loan1.tokensHeld[1]).to.equal(0);

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1));
      expect(strategyCfmmBalance1).gt(strategyCfmmBalance0);
    });

    it("Deposit LP tokens, withdraw both tokens and CFMM LP tokens, don't return collateral and LP tokens", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
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
        amount0: amounts[0],
        amount1: amounts[1],
        lpTokens: 0,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(21))).wait();
      await (
        await strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).gt(poolBalances0.lpTokenBalance);
      expect(poolBalances1.lpInvariant).gt(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).lt(poolBalances0.tokenBalances[0]);
      expect(poolBalances1.tokenBalances[1]).lt(poolBalances0.tokenBalances[1]);
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(0);
      expect(loan1.initLiquidity).to.equal(0);
      expect(loan1.lpTokens).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(0);
      expect(loan1.tokensHeld[1]).to.equal(0);

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1));
      expect(strategyCfmmBalance1).gt(strategyCfmmBalance0);
    });

    it("No Deposit LP tokens, withdraw both tokens and CFMM LP tokens, Deposit LP tokens", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
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
        amount0: amounts[0],
        amount1: amounts[1],
        lpTokens: lpTokens.add(ONE),
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(callee2.address, ONE)).wait();
      await (
        await strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).wait();

      const poolBalances1 = await strategy.getPoolBalances();
      expect(poolBalances1.lpTokenBalance).gt(poolBalances0.lpTokenBalance);
      expect(poolBalances1.lpInvariant).gt(poolBalances0.lpInvariant);
      expect(poolBalances1.tokenBalances.length).to.equal(
        poolBalances0.tokenBalances.length
      );
      expect(poolBalances1.tokenBalances[0]).lt(poolBalances0.tokenBalances[0]);
      expect(poolBalances1.tokenBalances[1]).lt(poolBalances0.tokenBalances[1]);
      expect(poolBalances1.lastCFMMTotalSupply).to.equal(
        poolBalances0.lastCFMMTotalSupply
      );
      expect(poolBalances1.lastCFMMInvariant).to.equal(
        poolBalances0.lastCFMMInvariant
      );

      const loan1 = await strategy.getLoan(tokenId);
      expect(loan1.liquidity).to.equal(0);
      expect(loan1.initLiquidity).to.equal(0);
      expect(loan1.lpTokens).to.equal(0);
      expect(loan1.tokensHeld.length).to.equal(loan0.tokensHeld.length);
      expect(loan1.tokensHeld[0]).to.equal(0);
      expect(loan1.tokensHeld[1]).to.equal(0);

      expect(poolBalances1.tokenBalances[0].sub(amount0)).to.equal(
        loan1.tokensHeld[0]
      );
      expect(poolBalances1.tokenBalances[1].sub(amount1)).to.equal(
        loan1.tokensHeld[1]
      );

      const strategyBalanceA1 = await tokenA.balanceOf(strategy.address);
      const strategyBalanceB1 = await tokenB.balanceOf(strategy.address);
      const strategyCfmmBalance1 = await cfmm.balanceOf(strategy.address);
      expect(strategyBalanceA1).to.equal(strategyBalanceA0.sub(amount0));
      expect(strategyBalanceB1).to.equal(strategyBalanceB0.sub(amount1));
      expect(strategyCfmmBalance1).gt(strategyCfmmBalance0);
    });
  });

  describe("Unsuccessful Liquidations", function () {
    it("error, loan does not exist", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE;
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

      const amounts = [0, 0];
      const lpTokens = ONE.mul(20);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: 0,
        amount1: 0,
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );
      await expect(
        strategy._liquidateExternally(
          tokenId.add(1),
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "LoanDoesNotExist");
      await expect(
        strategy._liquidateExternally(
          tokenId.sub(1),
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "LoanDoesNotExist");
    });

    it("Has margin", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(10);
      const amount1 = ONE.mul(20);
      const liquidity = ONE;
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

      const amounts = [0, 0];
      const lpTokens = ONE.mul(20);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: 0,
        amount1: 0,
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );
      await expect(
        strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "HasMargin");
    });

    it("No lp tokens deposited", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [0, 0];
      const lpTokens = ONE.mul(20);

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: 0,
        amount1: 0,
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );
      await expect(
        strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "InsufficientDeposit");
    });

    it("Deposit LP tokens, withdrew tokenA, NotEnoughCollateral", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [amount0.mul(2), amount1.mul(2)];
      const lpTokens = 0;

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amount0.sub(1),
        amount1: amount1,
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();
      await expect(
        strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughCollateral");
    });

    it("Deposit LP tokens, withdrew tokenB, NotEnoughCollateral", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
      const loan0 = await strategy.getLoan(tokenId);

      await createLoan(amount0, amount1, liquidity);

      const poolBalances0 = await strategy.getPoolBalances();
      expect(poolBalances0.tokenBalances[0].sub(amount0)).to.equal(
        loan0.tokensHeld[0]
      );
      expect(poolBalances0.tokenBalances[1].sub(amount1)).to.equal(
        loan0.tokensHeld[1]
      );

      const amounts = [amount0.mul(2), amount1.mul(2)];
      const lpTokens = 0;

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amount0,
        amount1: amount1.sub(1),
        lpTokens: lpTokens,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();
      await expect(
        strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "NotEnoughCollateral");
    });

    it("Deposit LP tokens, withdrew both tokens, no liquidity provided", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
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

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amounts[0],
        amount1: amounts[1],
        lpTokens: 0,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(20))).wait();
      await expect(
        strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "InsufficientDeposit");
    });

    it("Deposit LP tokens, withdrew both tokens, negative LP token change", async function () {
      expect(await strategy.swapFee()).to.equal(0);
      await strategy.setExternalSwapFee(10);
      expect(await strategy.swapFee()).to.equal(10);
      const ONE = BigNumber.from(10).pow(18);
      const amount0 = ONE.mul(1);
      const amount1 = ONE.mul(2);
      const liquidity = ONE;
      const tokenId = await createLoan(amount0, amount1, liquidity.mul(2));
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

      const swapData = {
        strategy: strategy.address,
        cfmm: cfmm.address,
        token0: tokenA.address,
        token1: tokenB.address,
        amount0: amounts[0],
        amount1: amounts[1],
        lpTokens: 0,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        [
          "tuple(address strategy, address cfmm, address token0, address token1, uint256 amount0, uint256 amount1, uint256 lpTokens)",
        ],
        [swapData]
      );

      await (await cfmm.transfer(strategy.address, amount0.mul(10))).wait();
      await expect(
        strategy._liquidateExternally(
          tokenId,
          amounts,
          lpTokens,
          callee2.address,
          data
        )
      ).to.be.revertedWithCustomError(strategy, "LPBalanceShortfall");
    });
  });
});
