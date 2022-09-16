import { ethers } from "hardhat";
import { expect } from "chai";

describe("GammaPool", function () {
  let TestERC20: any;
  let TestAddressCalculator: any;
  let TestAbstractProtocol: any;
  let TestLongStrategy: any;
  let TestShortStrategy: any;
  let GammaPool: any;
  let TestGammaPoolFactory: any;
  let factory: any;
  let addressCalculator: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let longStrategy: any;
  let shortStrategy: any;
  let gammaPool: any;
  let protocol: any;
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

    TestAbstractProtocol = await ethers.getContractFactory(
      "TestAbstractProtocol"
    );

    TestLongStrategy = await ethers.getContractFactory("TestLongStrategy");

    TestShortStrategy = await ethers.getContractFactory("TestShortStrategy");

    GammaPool = await ethers.getContractFactory("GammaPool");
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    cfmm = await TestERC20.deploy("Test CFMM", "CFMM");
    longStrategy = await TestLongStrategy.deploy();
    shortStrategy = await TestShortStrategy.deploy();
    addressCalculator = await TestAddressCalculator.deploy();

    tokens = [tokenA.address, tokenB.address];

    factory = await TestGammaPoolFactory.deploy(
      cfmm.address,
      1,
      tokens,
      ethers.constants.AddressZero
    );
    protocol = await TestAbstractProtocol.deploy(
      factory.address,
      1,
      longStrategy.address,
      shortStrategy.address,
      2,
      3
    );
    await factory.setProtocol(protocol.address);

    await deployGammaPool();
  });

  async function deployGammaPool() {
    await (await factory.createPool()).wait();

    const key = await addressCalculator.getGammaPoolKey(cfmm.address, 1);
    const pool = await factory.getPool(key);

    gammaPool = await GammaPool.attach(
      pool // The deployed contract address
    );
  }
  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    // `it` is another Mocha function. This is the one you use to define your
    // tests. It receives the test name, and a callback function.

    it("Should be right INIT_CODE_HASH", async function () {
      const COMPUTED_INIT_CODE_HASH = ethers.utils.keccak256(
        GammaPool.bytecode
      );
      expect(COMPUTED_INIT_CODE_HASH).to.equal(
        await addressCalculator.getInitCodeHash()
      );
    });

    it("Check Init Params", async function () {
      expect(await gammaPool.cfmm()).to.equal(cfmm.address);
      expect(await gammaPool.protocolId()).to.equal(1);
      expect(await gammaPool.protocol()).to.equal(protocol.address);

      const tokens = await gammaPool.tokens();
      expect(tokens.length).to.equal(2);
      expect(tokens[0]).to.equal(tokenA.address);
      expect(tokens[1]).to.equal(tokenB.address);

      expect(await gammaPool.factory()).to.equal(factory.address);
      expect(await gammaPool.longStrategy()).to.equal(longStrategy.address);
      expect(await gammaPool.shortStrategy()).to.equal(shortStrategy.address);

      const tokenBalances = await gammaPool.tokenBalances();
      expect(tokenBalances.length).to.equal(2);
      expect(tokenBalances[0]).to.equal(0);
      expect(tokenBalances[1]).to.equal(0);

      expect(await gammaPool.lpTokenBalance()).to.equal(0);
      expect(await gammaPool.lpTokenBorrowed()).to.equal(0);
      expect(await gammaPool.lpTokenBorrowedPlusInterest()).to.equal(0);
      expect(await gammaPool.lpTokenTotal()).to.equal(0);
      expect(await gammaPool.borrowedInvariant()).to.equal(0);
      expect(await gammaPool.lpInvariant()).to.equal(0);
      expect(await gammaPool.totalInvariant()).to.equal(0);

      const cfmmReserves = await gammaPool.cfmmReserves();
      expect(cfmmReserves.length).to.equal(2);
      expect(cfmmReserves[0]).to.equal(0);
      expect(cfmmReserves[1]).to.equal(0);

      expect(await gammaPool.borrowRate()).to.equal(0);

      const ONE = ethers.BigNumber.from(10).pow(18);
      expect(await gammaPool.accFeeIndex()).to.equal(ONE);
      expect(await gammaPool.lastFeeIndex()).to.equal(ONE);
      expect(await gammaPool.lastCFMMFeeIndex()).to.equal(ONE);
      expect(await gammaPool.lastCFMMInvariant()).to.equal(0);
      expect(await gammaPool.lastCFMMTotalSupply()).to.equal(0);
      expect(await gammaPool.lastBlockNumber()).to.gt(0);
    });
  });

  // You can nest describe calls to create subsections.
  describe("Short Gamma", function () {
    it("ERC4626 Functions in GammaPool", async function () {
      const ONE = ethers.BigNumber.from(10).pow(18);
      expect(await gammaPool.totalAssets()).to.equal(ONE.mul(1000));

      const res0 = await (
        await gammaPool.deposit(ONE.mul(2), addr1.address)
      ).wait();
      expect(res0.events[0].args.caller).to.eq(owner.address);
      expect(res0.events[0].args.to).to.eq(addr1.address);
      expect(res0.events[0].args.assets).to.eq(ONE.mul(2));
      expect(res0.events[0].args.shares).to.eq(ONE.mul(3));

      const res1 = await (
        await gammaPool.mint(ONE.mul(3), addr2.address)
      ).wait();
      expect(res1.events[0].args.caller).to.eq(owner.address);
      expect(res1.events[0].args.to).to.eq(addr2.address);
      expect(res1.events[0].args.assets).to.eq(ONE.mul(4));
      expect(res1.events[0].args.shares).to.eq(ONE.mul(3));

      const res2 = await (
        await gammaPool.withdraw(ONE.mul(4), addr2.address, addr3.address)
      ).wait();
      expect(res2.events[0].args.caller).to.eq(owner.address);
      expect(res2.events[0].args.to).to.eq(addr2.address);
      expect(res2.events[0].args.from).to.eq(addr3.address);
      expect(res2.events[0].args.assets).to.eq(ONE.mul(4));
      expect(res2.events[0].args.shares).to.eq(ONE.mul(5));

      const res3 = await (
        await gammaPool.redeem(ONE.mul(5), addr2.address, addr1.address)
      ).wait();
      expect(res3.events[0].args.caller).to.eq(owner.address);
      expect(res3.events[0].args.to).to.eq(addr2.address);
      expect(res3.events[0].args.from).to.eq(addr1.address);
      expect(res3.events[0].args.assets).to.eq(ONE.mul(6));
      expect(res3.events[0].args.shares).to.eq(ONE.mul(5));
    });

    it("Non ERC4626 Functions", async function () {
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
      expect(loan.liquidity).to.eq(0);
      expect(loan.rateIndex).to.eq(ethers.BigNumber.from(10).pow(18));
      expect(loan.blockNum).to.gt(0);
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
      expect(res0.events[0].args.tokensHeld[1]).to.eq(tokenId);
      expect(res0.events[0].args.heldLiquidity).to.eq(10);
      expect(res0.events[0].args.liquidity).to.eq(11);
      expect(res0.events[0].args.lpTokens).to.eq(12);
      expect(res0.events[0].args.rateIndex).to.eq(13);

      const res1 = await (
        await gammaPool.decreaseCollateral(tokenId, [100, 200], addr1.address)
      ).wait();
      expect(res1.events[0].args.tokenId).to.eq(tokenId);
      expect(res1.events[0].args.tokensHeld.length).to.eq(2);
      expect(res1.events[0].args.tokensHeld[0]).to.eq(100);
      expect(res1.events[0].args.tokensHeld[1]).to.eq(200);
      expect(res1.events[0].args.heldLiquidity).to.eq(20);
      expect(res1.events[0].args.liquidity).to.eq(21);
      expect(res1.events[0].args.lpTokens).to.eq(22);
      expect(res1.events[0].args.rateIndex).to.eq(23);

      const res2 = await (await gammaPool.borrowLiquidity(tokenId, 300)).wait();
      expect(res2.events[0].args.tokenId).to.eq(tokenId);
      expect(res2.events[0].args.tokensHeld.length).to.eq(2);
      expect(res2.events[0].args.tokensHeld[0]).to.eq(tokenId);
      expect(res2.events[0].args.tokensHeld[1]).to.eq(300);
      expect(res2.events[0].args.heldLiquidity).to.eq(30);
      expect(res2.events[0].args.liquidity).to.eq(31);
      expect(res2.events[0].args.lpTokens).to.eq(32);
      expect(res2.events[0].args.rateIndex).to.eq(33);

      const res3 = await (await gammaPool.repayLiquidity(tokenId, 400)).wait();
      expect(res3.events[0].args.tokenId).to.eq(tokenId);
      expect(res3.events[0].args.tokensHeld.length).to.eq(2);
      expect(res3.events[0].args.tokensHeld[0]).to.eq(9);
      expect(res3.events[0].args.tokensHeld[1]).to.eq(10);
      expect(res3.events[0].args.heldLiquidity).to.eq(tokenId);
      expect(res3.events[0].args.liquidity).to.eq(400);
      expect(res3.events[0].args.lpTokens).to.eq(42);
      expect(res3.events[0].args.rateIndex).to.eq(43);

      const res4 = await (
        await gammaPool.rebalanceCollateral(tokenId, [500, 600])
      ).wait();
      expect(res4.events[0].args.tokenId).to.eq(tokenId);
      expect(res4.events[0].args.tokensHeld.length).to.eq(2);
      expect(res4.events[0].args.tokensHeld[0]).to.eq(500);
      expect(res4.events[0].args.tokensHeld[1]).to.eq(600);
      expect(res4.events[0].args.heldLiquidity).to.eq(tokenId);
      expect(res4.events[0].args.liquidity).to.eq(51);
      expect(res4.events[0].args.lpTokens).to.eq(52);
      expect(res4.events[0].args.rateIndex).to.eq(53);

      const res5 = await (
        await gammaPool.rebalanceCollateralWithLiquidity(tokenId, 700)
      ).wait();
      expect(res5.events[0].args.tokenId).to.eq(tokenId);
      expect(res5.events[0].args.tokensHeld.length).to.eq(2);
      expect(res5.events[0].args.tokensHeld[0]).to.eq(tokenId);
      expect(res5.events[0].args.tokensHeld[1]).to.eq(700);
      expect(res5.events[0].args.heldLiquidity).to.eq(701);
      expect(res5.events[0].args.liquidity).to.eq(61);
      expect(res5.events[0].args.lpTokens).to.eq(62);
      expect(res5.events[0].args.rateIndex).to.eq(63);
    });
  });
});
