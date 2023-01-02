import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const UniswapV2FactoryJSON = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const UniswapV2PairJSON = require("@uniswap/v2-core/build/UniswapV2Pair.json");

const PROTOCOL_ID = 1;

describe("CPMMGammaPool", function () {
  let TestERC20: any;
  let CPMMGammaPool: any;
  let UniswapV2Factory: any;
  let UniswapV2Pair: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let pool: any;
  let gsFactoryAddress: any;
  let cfmmHash: any;
  let longStrategyAddr: any;
  let shortStrategyAddr: any;
  let liquidationStrategyAddr: any;
  let cfmm: any;
  let uniFactory: any;
  let badPool: any;
  let badPool2: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    CPMMGammaPool = await ethers.getContractFactory("CPMMGammaPool");
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    UniswapV2Factory = new ethers.ContractFactory(
      UniswapV2FactoryJSON.abi,
      UniswapV2FactoryJSON.bytecode,
      owner
    );
    UniswapV2Pair = new ethers.ContractFactory(
      UniswapV2PairJSON.abi,
      UniswapV2PairJSON.bytecode,
      owner
    );

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");

    uniFactory = await UniswapV2Factory.deploy(owner.address);

    cfmm = await createPair(tokenA, tokenB);

    // 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f UniswapV2
    // 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303 SushiSwap
    gsFactoryAddress = owner.address;
    cfmmHash =
      "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f";
    longStrategyAddr = addr1.address;
    shortStrategyAddr = addr2.address;
    liquidationStrategyAddr = addr3.address;

    pool = await CPMMGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategyAddr,
      shortStrategyAddr,
      liquidationStrategyAddr,
      uniFactory.address,
      cfmmHash
    );

    const badCfmmHash =
      "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845e";

    badPool = await CPMMGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategyAddr,
      shortStrategyAddr,
      liquidationStrategyAddr,
      uniFactory.address,
      badCfmmHash
    );

    badPool2 = await CPMMGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategyAddr,
      shortStrategyAddr,
      liquidationStrategyAddr,
      gsFactoryAddress,
      cfmmHash
    );
  });

  async function createPair(token1: any, token2: any) {
    await uniFactory.createPair(token1.address, token2.address);
    const uniPairAddress: string = await uniFactory.getPair(
      token1.address,
      token2.address
    );

    return await UniswapV2Pair.attach(
      uniPairAddress // The deployed contract address
    );
  }

  async function validateCFMM(token0: any, token1: any, cfmm: any) {
    const resp = await pool.validateCFMM(
      [token0.address, token1.address],
      cfmm.address
    );
    const bigNum0 = BigNumber.from(token0.address);
    const bigNum1 = BigNumber.from(token1.address);
    const token0Addr = bigNum0.lt(bigNum1) ? token0.address : token1.address;
    const token1Addr = bigNum0.lt(bigNum1) ? token1.address : token0.address;
    expect(resp._tokensOrdered[0]).to.equal(token0Addr);
    expect(resp._tokensOrdered[1]).to.equal(token1Addr);
    expect(resp._decimals[0]).to.equal(18);
    expect(resp._decimals[1]).to.equal(18);
  }

  describe("Deployment", function () {
    it("Should set right init params", async function () {
      expect(await pool.protocolId()).to.equal(1);
      expect(await pool.longStrategy()).to.equal(addr1.address);
      expect(await pool.shortStrategy()).to.equal(addr2.address);
      expect(await pool.liquidationStrategy()).to.equal(addr3.address);
      expect(await pool.factory()).to.equal(owner.address);
      expect(await pool.cfmmFactory()).to.equal(uniFactory.address);
      expect(await pool.cfmmInitCodeHash()).to.equal(cfmmHash);
    });
  });

  describe("Validate CFMM", function () {
    it("Error is Not Contract", async function () {
      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], owner.address)
      ).to.be.revertedWith("NotContract");
    });

    it("Error Not Right Contract", async function () {
      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], uniFactory.address)
      ).to.be.revertedWith("BadProtocol");
    });

    it("Error Not Right Tokens", async function () {
      await expect(
        pool.validateCFMM([tokenA.address, tokenC.address], cfmm.address)
      ).to.be.revertedWith("BadProtocol");
    });

    it("Error Bad Hash", async function () {
      expect(await badPool.cfmmFactory()).to.equal(uniFactory.address);
      expect(await badPool.cfmmInitCodeHash()).to.not.equal(cfmmHash);
      await expect(
        badPool.validateCFMM([tokenA.address, tokenB.address], cfmm.address)
      ).to.be.revertedWith("BadProtocol");
    });

    it("Error Bad Factory", async function () {
      expect(await badPool2.cfmmFactory()).to.not.equal(uniFactory.address);
      expect(await badPool2.cfmmInitCodeHash()).to.equal(cfmmHash);
      await expect(
        badPool2.validateCFMM([tokenA.address, tokenB.address], cfmm.address)
      ).to.be.revertedWith("BadProtocol");
    });

    it("Correct Validation", async function () {
      expect(await pool.cfmmFactory()).to.equal(uniFactory.address);
      expect(await pool.cfmmInitCodeHash()).to.equal(cfmmHash);

      await validateCFMM(tokenA, tokenB, cfmm);

      const cfmm1 = await createPair(tokenA, tokenC);
      await validateCFMM(tokenA, tokenC, cfmm1);

      const cfmm2 = await createPair(tokenB, tokenC);
      await validateCFMM(tokenB, tokenC, cfmm2);
    });
  });
});
