import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const _Vault = require("@balancer-labs/v2-deployments/dist/tasks/20210418-vault/artifact/Vault.json");
const _WeightedPoolFactoryAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPoolFactory.json");
const _WeightedPoolFactoryBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPoolFactory.json");
const _WeightedPoolAbi = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/abi/WeightedPool.json");
const _WeightedPoolBytecode = require("@balancer-labs/v2-deployments/dist/tasks/20210418-weighted-pool/bytecode/WeightedPool.json");

// Protocol ID for Balancer
const PROTOCOL_ID = 2;

describe("BalancerGammaPool", function () {
  let TestERC20: any;
  let BalancerGammaPool: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let tokenD: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let pool: any;
  let gsFactoryAddress: any;
  let longStrategyAddr: any;
  let shortStrategyAddr: any;
  let liquidationStrategyAddr: any;
  let cfmm: any;
  let badPool: any;
  let badPool2: any;
  let badPoolID: any;
  let badVaultAddress: any;
  let badFactoryAddress: any;
  let secondVault: any;
  let weightedPool: any;
  let weighted3Pool: any;
  let badWeightedPool: any;

  let BalancerVault: any;
  let WeightedPoolFactory: any;
  let WeightedPool: any;
  let vault: any;
  let factory: any;
  let poolId: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    BalancerGammaPool = await ethers.getContractFactory("BalancerGammaPool");
    
    [owner] = await ethers.getSigners();

    // Get contract factory for WeightedPool: '@balancer-labs/v2-pool-weighted/WeightedPoolFactory'
    WeightedPoolFactory = new ethers.ContractFactory(
      _WeightedPoolFactoryAbi,
      _WeightedPoolFactoryBytecode.creationCode,
      owner
    );

    WeightedPool = new ethers.ContractFactory(
      _WeightedPoolAbi,
      _WeightedPoolBytecode.creationCode,
      owner
    );

    // Get contract factory for Vault: '@balancer-labs/v2-vault/contracts/Vault'
    BalancerVault = new ethers.ContractFactory(
      _Vault.abi,
      _Vault.bytecode,
      owner
    );

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    
    const HOUR = 60 * 60;
    const DAY = HOUR * 24;
    const MONTH = DAY * 30;

    // Deploy the Vault contract
    vault = await BalancerVault.deploy(owner.address, tokenA.address, MONTH, MONTH);
    
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");
    tokenD = await TestERC20.deploy("Test Token D", "TOKD");

    // Deploy the WeightedPoolFactory contract
    factory = await WeightedPoolFactory.deploy(
        vault.address, // The vault address is given to the factory so it can create pools with the correct vault
    );
    
    // Create a WeightedPool using the WeightedPoolFactory
    cfmm = await createPair(tokenA, tokenB);

    // Create a 3 token WeightedPool using the WeightedPoolFactory
    weighted3Pool = await create3Pool(tokenA, tokenB, tokenC);

    // Create a bad WeightedPool using the WeightedPoolFactory
    badWeightedPool = await createPair(tokenA, tokenC);

    weightedPool = WeightedPool.attach(cfmm);
    poolId = await weightedPool.getPoolId();

    gsFactoryAddress = owner.address;

    // Mock addresses for strategies
    longStrategyAddr = addr1.address;
    shortStrategyAddr = addr2.address;
    liquidationStrategyAddr = addr3.address;

    badPoolID = "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845e";
    badVaultAddress = "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845e";

    // Deploy a different Balancer Vault to check the vault address check works correctly
    secondVault = await BalancerVault.deploy(owner.address, tokenB.address, MONTH, MONTH);

    // Currently unused, will be used in future tests once we have a hash for the contract address check
    badFactoryAddress = "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845e";

    pool = await BalancerGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategyAddr,
      shortStrategyAddr,
      liquidationStrategyAddr,
      vault.address, // Address of the Balancer Vault associated with the pool
      factory.address, // Address of the WeightedPoolFactory used to create the pool
      poolId // Pool ID of the WeightedPool
    );

    badPool = await BalancerGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategyAddr,
      shortStrategyAddr,
      liquidationStrategyAddr,
      secondVault.address, // Address a different Balancer Vault which is not associated with the pool
      factory.address, // Address of the WeightedPoolFactory used to create the pool
      poolId // Pool ID of the WeightedPool
    );

    badPool2 = await BalancerGammaPool.deploy(
      PROTOCOL_ID,
      owner.address,
      longStrategyAddr,
      shortStrategyAddr,
      liquidationStrategyAddr,
      vault.address, // Address of the Balancer Vault associated with the pool
      factory.address, // Address of the WeightedPoolFactory used to create the pool
      badPoolID // Incorrect pool ID for the WeightedPool
    );
  });


  async function createPair(token1: any, token2: any) {
    const NAME = 'TESTPOOL';
    const SYMBOL = 'TP';
    let TOKENS: any;
    let WEIGHTS: any;

    if (BigNumber.from(token2.address).lt(BigNumber.from(token1.address))) {
      TOKENS = [token2.address, token1.address];
    }
    else {
      TOKENS = [token1.address, token2.address];
    }
    const HUNDRETH = BigNumber.from(10).pow(16);
    WEIGHTS = [BigNumber.from(50).mul(HUNDRETH), BigNumber.from(50).mul(HUNDRETH)];
    const FEE_PERCENTAGE = HUNDRETH;

    const poolReturnData = await factory.create(
      NAME, SYMBOL, TOKENS, WEIGHTS, FEE_PERCENTAGE, owner.address
    );

    const receipt = await poolReturnData.wait();
    const events = receipt.events.filter((e: any) => e.event === 'PoolCreated');
    const poolAddress = events[0].args.pool;
    return poolAddress
  }

  async function create3Pool(token1: any, token2: any, token3: any) {
    const NAME = 'TESTPOOL';
    const SYMBOL = 'TP';
    let TOKENS: any;
    let WEIGHTS: any;

    // Sort the token addresses in order
    if (BigNumber.from(token2.address).lt(BigNumber.from(token1.address))) {
      TOKENS = [token2.address, token1.address];
    } else {
      TOKENS = [token1.address, token2.address];
    }

    if (BigNumber.from(token3.address).gt(BigNumber.from(TOKENS[1]))) {
      TOKENS = [...TOKENS, token3.address];
    } else {
      if (BigNumber.from(token3.address).lt(BigNumber.from(TOKENS[0]))) {
        TOKENS = [token3.address, ...TOKENS];
      } else {
        TOKENS = [TOKENS[0], token3.address, TOKENS[1]];
      }
    }

    const HUNDRETH = BigNumber.from(10).pow(16);
    WEIGHTS = [BigNumber.from(10).mul(HUNDRETH), BigNumber.from(10).mul(HUNDRETH), BigNumber.from(10).pow(18).sub(BigNumber.from(20).mul(HUNDRETH))];
    
    const FEE_PERCENTAGE = HUNDRETH;

    const poolReturnData = await factory.create(
      NAME, SYMBOL, TOKENS, WEIGHTS, FEE_PERCENTAGE, owner.address
    );

    const receipt = await poolReturnData.wait();
    const events = receipt.events.filter((e: any) => e.event === 'PoolCreated');
    const poolAddress = events[0].args.pool;
    return poolAddress
  }

  async function validateCFMM(token0: any, token1: any, cfmm: any, gammaPool: any) {
    const resp = await gammaPool.validateCFMM(
      [token0.address, token1.address],
      cfmm
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
      expect(await pool.protocolId()).to.equal(2);
      expect(await pool.longStrategy()).to.equal(addr1.address);
      expect(await pool.shortStrategy()).to.equal(addr2.address);
      expect(await pool.liquidationStrategy()).to.equal(addr3.address);
      expect(await pool.factory()).to.equal(owner.address);
      expect(await pool.balancerVault()).to.equal(vault.address);
      expect(await pool.poolFactory()).to.equal(factory.address);
      expect(await pool.poolId()).to.equal(poolId);
    });
  });

  describe("Validate CFMM", function () {
    it("Error Not Contract", async function () {
      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], owner.address)
      ).to.be.revertedWith("NotContract");
    });

    it("Error Bad Vault Address", async function () {
      // The vault given in the constructor is not the same as the vault associated with the pool
      await expect(
        badPool.validateCFMM([tokenA.address, tokenB.address], cfmm)
      ).to.be.revertedWith("BadVaultAddress");
    });

    it("Error Bad Pool ID", async function () {
      // The pool ID given in the constructor is not the same as the pool ID associated with the pool
      await expect(
        badPool2.validateCFMM([tokenA.address, tokenC.address], cfmm)
      ).to.be.revertedWith("BadPoolId");
    });

    it("Error Incorrect Token Length", async function () {
      // The WeightedPool given has more than 2 tokens
      await expect(
        pool.validateCFMM([tokenA.address, tokenB.address], weighted3Pool)
      ).to.be.revertedWith("IncorrectTokenLength");
    });

    it("Error Incorrect Tokens", async function () {
      // The WeightedPool given has the wrong tokens
      await expect(
        pool.validateCFMM([tokenA.address, tokenC.address], cfmm)
      ).to.be.revertedWith("IncorrectTokens");
    });

    it("Correct Validation #1", async function () {
      await validateCFMM(tokenA, tokenB, cfmm, pool);
    });

    it("Correct Validation #2", async function () {
      const testCFMM = await createPair(tokenA, tokenD);

      let testWeightedPool: any;
      let testPoolId: any;

      testWeightedPool = WeightedPool.attach(testCFMM);
      testPoolId = await testWeightedPool.getPoolId();

      let testPool: any;

      testPool = await BalancerGammaPool.deploy(
        PROTOCOL_ID,
        owner.address,
        longStrategyAddr,
        shortStrategyAddr,
        liquidationStrategyAddr,
        vault.address, // Address of the Balancer Vault associated with the pool
        factory.address, // Address of the WeightedPoolFactory used to create the pool
        testPoolId // Pool ID of the WeightedPool
      );

      await validateCFMM(tokenA, tokenD, testCFMM, testPool);
    });
  });
});
