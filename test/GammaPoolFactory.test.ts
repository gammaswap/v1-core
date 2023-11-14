import { ethers } from "hardhat";
import { expect } from "chai";

const PROTOCOL_ID = 1;
const PROTOCOL_EXTERNAL_ID = 2;

describe("GammaPoolFactory", function () {
  let TestERC20: any;
  let TestAddressCalculator: any;
  let TestRateModel: any;
  let GammaPool: any;
  let GammaPoolExternal: any;
  let PoolViewer: any;
  let GammaPoolFactory: any;
  let factory: any;
  let addressCalculator: any;
  let poolViewer: any;
  let rateModel: any;
  let protocol: any;
  let protocolZero: any;
  let protocolExternal: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let tokenD: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let addr4: any;
  let addr5: any;
  let addr6: any;
  let addr7: any;
  let addr8: any;
  let addr9: any;
  let addr10: any;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestRateModel = await ethers.getContractFactory("TestRateModel");
    PoolViewer = await ethers.getContractFactory("PoolViewer");
    GammaPool = await ethers.getContractFactory("TestGammaPool");
    GammaPoolExternal = await ethers.getContractFactory(
      "TestGammaPoolExternal"
    );
    GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
    TestAddressCalculator = await ethers.getContractFactory(
      "TestAddressCalculator"
    );
    [
      owner,
      addr1,
      addr2,
      addr3,
      addr4,
      addr5,
      addr6,
      addr7,
      addr8,
      addr9,
      addr10,
    ] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");
    tokenD = await TestERC20.deploy("Test Token D", "TOKD");
    factory = await GammaPoolFactory.deploy(owner.address);
    poolViewer = await PoolViewer.deploy();
    rateModel = await TestRateModel.deploy(owner.address);

    protocol = await GammaPool.deploy(
      PROTOCOL_ID,
      factory.address,
      addr1.address,
      addr9.address,
      addr10.address,
      addr2.address,
      addr5.address,
      addr5.address,
      poolViewer.address
    );

    addressCalculator = await TestAddressCalculator.deploy();

    protocolZero = await GammaPool.deploy(
      0,
      factory.address,
      addr1.address,
      addr9.address,
      addr10.address,
      addr2.address,
      addr5.address,
      addr5.address,
      poolViewer.address
    );

    protocolExternal = await GammaPoolExternal.deploy(
      PROTOCOL_EXTERNAL_ID,
      factory.address,
      addr1.address,
      addr9.address,
      addr10.address,
      addr2.address,
      addr5.address,
      addr5.address,
      poolViewer.address,
      addr5.address,
      addr5.address
    );

    // We can interact with the contract by calling `hardhatToken.method()`
    await tokenA.deployed();
    await tokenB.deployed();
    await factory.deployed();
    await protocol.deployed();
    await protocolExternal.deployed();
  });

  function createPoolParamsObj(cfmmAddress: any, tokenA: any, tokenB: any) {
    const params = {
      protocolId: 1,
      cfmm: cfmmAddress,
    };

    const createPoolParams = {
      protocolId: 1,
      cfmm: cfmmAddress,
      tokens: [tokenA.address, tokenB.address],
    };

    const data = ethers.utils.defaultAbiCoder.encode(
      ["tuple(uint16 protocolId, address cfmm)"],
      [params]
    );
    return { createPoolParams: createPoolParams, data: data };
  }
  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set the right initial fields", async function () {
      expect(await factory.owner()).to.equal(owner.address);
      expect(await factory.feeToSetter()).to.equal(owner.address);
      const feeInfo = await factory.feeInfo();
      expect(feeInfo._feeTo).to.equal(owner.address);
      const fee = 10000;
      expect(feeInfo._fee).to.equal(fee);
      expect(await tokenA.owner()).to.equal(owner.address);
      expect(await tokenB.owner()).to.equal(owner.address);

      const ownerBalanceA = await tokenA.balanceOf(owner.address);
      expect(await tokenA.totalSupply()).to.equal(ownerBalanceA);
      const ownerBalanceB = await tokenB.balanceOf(owner.address);
      expect(await tokenB.totalSupply()).to.equal(ownerBalanceB);
    });
  });

  describe("Create Pool", function () {
    it("Add & Remove Protocol", async function () {
      expect(await factory.getProtocol(0)).to.equal(
        ethers.constants.AddressZero
      );
      expect(await factory.getProtocol(1)).to.equal(
        ethers.constants.AddressZero
      );
      await (await factory.addProtocol(protocol.address)).wait();
      expect(await factory.getProtocol(0)).to.equal(
        ethers.constants.AddressZero
      );
      expect(await factory.getProtocol(1)).to.equal(protocol.address);

      await (await factory.removeProtocol(1)).wait();
      expect(await factory.getProtocol(1)).to.equal(
        ethers.constants.AddressZero
      );

      await (await factory.addProtocol(protocol.address)).wait();
      await expect(
        factory.addProtocol(protocol.address)
      ).to.be.revertedWithCustomError(factory, "ProtocolExists");

      await expect(
        factory.addProtocol(protocolZero.address)
      ).to.be.revertedWithCustomError(factory, "ZeroProtocol");

      await expect(
        factory.connect(addr1).addProtocol(addr2.address)
      ).to.be.revertedWith("Forbidden");
      await expect(factory.connect(addr1).removeProtocol(1)).to.be.revertedWith(
        "Forbidden"
      );
    });

    it("Restrict Protocol", async function () {
      await factory.addProtocol(protocol.address);

      expect(await factory.isProtocolRestricted(1)).to.equal(false);

      await factory.setIsProtocolRestricted(1, true);

      expect(await factory.isProtocolRestricted(1)).to.equal(true);
      await expect(
        factory.connect(addr1).setIsProtocolRestricted(1, false)
      ).to.be.revertedWith("Forbidden");
    });

    it("Create Pool", async function () {
      await (await factory.addProtocol(protocol.address)).wait();
      expect(await factory.allPoolsLength()).to.equal(0);

      const params = createPoolParamsObj(addr3.address, tokenA, tokenB);

      await factory.createPool(
        params.createPoolParams.protocolId,
        params.createPoolParams.cfmm,
        params.createPoolParams.tokens,
        params.data
      );

      const key = await addressCalculator.getGammaPoolKey(addr3.address, 1);
      const pool = await factory.getPool(key);
      expect(pool).to.not.equal(ethers.constants.AddressZero);
      expect(key).to.equal(await factory.getKey(pool));

      // Precalculated address
      const expectedPoolAddress = await addressCalculator.calcAddress(
        factory.address,
        1,
        key
      );
      expect(pool).to.equal(expectedPoolAddress);
      expect(await factory.allPoolsLength()).to.equal(1);

      const params2 = createPoolParamsObj(addr4.address, tokenA, tokenC);

      await factory.createPool(
        params2.createPoolParams.protocolId,
        params2.createPoolParams.cfmm,
        params2.createPoolParams.tokens,
        params2.data
      );
      const key2 = await addressCalculator.getGammaPoolKey(addr4.address, 1);
      const pool2 = await factory.getPool(key2);
      expect(pool2).to.not.equal(ethers.constants.AddressZero);
      expect(key2).to.equal(await factory.getKey(pool2));

      // Precalculated address
      const expectedPoolAddress2 = await addressCalculator.calcAddress(
        factory.address,
        1,
        key2
      );
      expect(pool2).to.equal(expectedPoolAddress2);
      expect(await factory.allPoolsLength()).to.equal(2);
    });

    it("Create Pool Errors", async function () {
      await factory.removeProtocol(1);
      const createPoolParams = {
        cfmm: addr3.address,
        protocolId: 1,
        tokens: [tokenA.address, tokenB.address],
      };
      const params = {
        protocolId: 1,
        cfmm: addr3.address,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        ["tuple(uint16 protocolId, address cfmm)"],
        [params]
      );
      await expect(
        factory.createPool(
          createPoolParams.protocolId,
          createPoolParams.cfmm,
          createPoolParams.tokens,
          data
        )
      ).to.be.revertedWithCustomError(factory, "ProtocolNotSet");
      await factory.addProtocol(protocol.address);

      await expect(
        factory.createPool(
          createPoolParams.protocolId,
          owner.address,
          createPoolParams.tokens,
          data
        )
      ).to.be.revertedWith("Validation");

      await factory.createPool(
        createPoolParams.protocolId,
        createPoolParams.cfmm,
        createPoolParams.tokens,
        data
      );
      await expect(
        factory.createPool(
          createPoolParams.protocolId,
          createPoolParams.cfmm,
          createPoolParams.tokens,
          data
        )
      ).to.be.revertedWithCustomError(factory, "PoolExists");

      await factory.setIsProtocolRestricted(1, true);

      const createPoolParams2 = {
        cfmm: addr4.address,
        protocolId: 1,
        tokens: [tokenA.address, tokenC.address],
      };
      const params2 = {
        protocolId: 1,
        cfmm: addr4.address,
      };
      const data2 = ethers.utils.defaultAbiCoder.encode(
        ["tuple(uint16 protocolId, address cfmm)"],
        [params2]
      );
      await expect(
        factory
          .connect(addr1)
          .createPool(
            createPoolParams2.protocolId,
            createPoolParams2.cfmm,
            createPoolParams2.tokens,
            data2
          )
      ).to.be.revertedWithCustomError(factory, "ProtocolRestricted");

      await factory.setIsProtocolRestricted(1, false);

      await factory
        .connect(addr1)
        .createPool(
          createPoolParams2.protocolId,
          createPoolParams2.cfmm,
          createPoolParams2.tokens,
          data2
        );

      await expect(
        factory.createPool(
          createPoolParams2.protocolId,
          createPoolParams2.cfmm,
          createPoolParams2.tokens,
          data2
        )
      ).to.be.revertedWithCustomError(factory, "PoolExists");
    });

    it("Query Pools", async function () {
      await (await factory.addProtocol(protocol.address)).wait();
      expect(await factory.allPoolsLength()).to.equal(0);

      const params = createPoolParamsObj(addr3.address, tokenA, tokenB);
      await factory.createPool(
        params.createPoolParams.protocolId,
        params.createPoolParams.cfmm,
        params.createPoolParams.tokens,
        params.data
      );

      const params2 = createPoolParamsObj(addr4.address, tokenA, tokenC);
      await factory.createPool(
        params2.createPoolParams.protocolId,
        params2.createPoolParams.cfmm,
        params2.createPoolParams.tokens,
        params2.data
      );

      const params3 = createPoolParamsObj(addr5.address, tokenA, tokenD);
      await factory.createPool(
        params3.createPoolParams.protocolId,
        params3.createPoolParams.cfmm,
        params3.createPoolParams.tokens,
        params3.data
      );

      const params4 = createPoolParamsObj(addr6.address, tokenB, tokenC);
      await factory.createPool(
        params4.createPoolParams.protocolId,
        params4.createPoolParams.cfmm,
        params4.createPoolParams.tokens,
        params4.data
      );

      const params5 = createPoolParamsObj(addr7.address, tokenB, tokenD);
      await factory.createPool(
        params5.createPoolParams.protocolId,
        params5.createPoolParams.cfmm,
        params5.createPoolParams.tokens,
        params5.data
      );

      const params6 = createPoolParamsObj(addr8.address, tokenC, tokenD);
      await factory.createPool(
        params6.createPoolParams.protocolId,
        params6.createPoolParams.cfmm,
        params6.createPoolParams.tokens,
        params6.data
      );

      expect(await factory.allPoolsLength()).to.equal(6);
      const resp1 = await factory.getPools(0, 0);
      expect(resp1.length).to.equal(1);
      expect(resp1[0]).to.equal(await factory.allPools(0));

      const resp2 = await factory.getPools(0, 2);
      expect(resp2.length).to.equal(3);
      expect(resp2[0]).to.equal(await factory.allPools(0));
      expect(resp2[1]).to.equal(await factory.allPools(1));
      expect(resp2[2]).to.equal(await factory.allPools(2));

      const resp3 = await factory.getPools(0, 5);
      expect(resp3.length).to.equal(await factory.allPoolsLength());
      expect(resp3[0]).to.equal(await factory.allPools(0));
      expect(resp3[1]).to.equal(await factory.allPools(1));
      expect(resp3[2]).to.equal(await factory.allPools(2));
      expect(resp3[3]).to.equal(await factory.allPools(3));
      expect(resp3[4]).to.equal(await factory.allPools(4));
      expect(resp3[5]).to.equal(await factory.allPools(5));

      const resp4 = await factory.getPools(0, 100);
      expect(resp4.length).to.equal(await factory.allPoolsLength());
      expect(resp4[0]).to.equal(await factory.allPools(0));
      expect(resp4[1]).to.equal(await factory.allPools(1));
      expect(resp4[2]).to.equal(await factory.allPools(2));
      expect(resp4[3]).to.equal(await factory.allPools(3));
      expect(resp4[4]).to.equal(await factory.allPools(4));
      expect(resp4[5]).to.equal(await factory.allPools(5));

      const resp5 = await factory.getPools(2, 4);
      expect(resp5.length).to.equal(3);
      expect(resp5[0]).to.equal(await factory.allPools(2));
      expect(resp5[1]).to.equal(await factory.allPools(3));
      expect(resp5[2]).to.equal(await factory.allPools(4));

      const resp6 = await factory.getPools(3, 100);
      expect(resp6.length).to.equal(3);
      expect(resp6[0]).to.equal(await factory.allPools(3));
      expect(resp6[1]).to.equal(await factory.allPools(4));
      expect(resp6[2]).to.equal(await factory.allPools(5));
    });
  });

  describe("Setting Fees", function () {
    it("Set Fee", async function () {
      expect(await factory.fee()).to.equal(10000);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      await expect(
        factory.connect(addr1).setFee(1)
      ).to.be.revertedWithCustomError(factory, "Forbidden");
      const feeTo = await factory.feeTo();
      const res = await (await factory.connect(owner).setFee(1)).wait();
      expect(await factory.fee()).to.equal(1);

      expect(res.events[0].event).to.equal("FeeUpdate");
      expect(res.events[0].args.pool).to.equal(ethers.constants.AddressZero);
      expect(res.events[0].args.to).to.equal(feeTo);
      expect(res.events[0].args.protocolFee).to.equal(1);
      expect(res.events[0].args.isSet).to.equal(false);

      const feeInfo = await factory.connect(owner).feeInfo();
      expect(feeInfo._feeTo).to.equal(owner.address);
      expect(feeInfo._fee).to.equal(1);
    });

    it("Set Fee To", async function () {
      expect(await factory.feeTo()).to.equal(owner.address);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      await expect(
        factory.connect(addr1).setFeeTo(addr2.address)
      ).to.be.revertedWithCustomError(factory, "Forbidden");
      const res = await (
        await factory.connect(owner).setFeeTo(addr2.address)
      ).wait();
      expect(await factory.feeTo()).to.equal(addr2.address);

      expect(res.events[0].event).to.equal("FeeUpdate");
      expect(res.events[0].args.pool).to.equal(ethers.constants.AddressZero);
      expect(res.events[0].args.to).to.equal(addr2.address);
      expect(res.events[0].args.protocolFee).to.equal(10000);
      expect(res.events[0].args.isSet).to.equal(false);

      const feeInfo = await factory.connect(owner).feeInfo();
      expect(feeInfo._feeTo).to.equal(addr2.address);
      expect(feeInfo._fee).to.equal(10000);
    });

    it("Set Fee for Pool", async function () {
      const poolFee = await factory.getPoolFee(addr1.address);
      expect(poolFee._to).to.equal(owner.address);
      expect(poolFee._protocolFee).to.equal(10000);
      expect(poolFee._origFeeShare).to.equal(600);
      expect(poolFee._isSet).to.equal(false);
      const res = await (
        await factory.setPoolFee(addr1.address, addr2.address, 20000, 700, true)
      ).wait();

      expect(res.events[0].event).to.equal("FeeUpdate");
      expect(res.events[0].args.pool).to.equal(addr1.address);
      expect(res.events[0].args.to).to.equal(addr2.address);
      expect(res.events[0].args.protocolFee).to.equal(20000);
      expect(res.events[0].args.origFeeShare).to.equal(700);
      expect(res.events[0].args.isSet).to.equal(true);

      const poolFee1 = await factory.getPoolFee(addr1.address);
      expect(poolFee1._to).to.equal(addr2.address);
      expect(poolFee1._protocolFee).to.equal(20000);
      expect(poolFee1._origFeeShare).to.equal(700);
      expect(poolFee1._isSet).to.equal(true);

      const res1 = await (
        await factory.setPoolFee(
          addr1.address,
          addr2.address,
          50000,
          500,
          false
        )
      ).wait();

      expect(res1.events[0].event).to.equal("FeeUpdate");
      expect(res1.events[0].args.pool).to.equal(addr1.address);
      expect(res1.events[0].args.to).to.equal(addr2.address);
      expect(res1.events[0].args.protocolFee).to.equal(50000);
      expect(res1.events[0].args.origFeeShare).to.equal(500);
      expect(res1.events[0].args.isSet).to.equal(false);

      const poolFee2 = await factory.getPoolFee(addr1.address);
      expect(poolFee2._to).to.equal(owner.address);
      expect(poolFee2._protocolFee).to.equal(10000);
      expect(poolFee2._origFeeShare).to.equal(600);
      expect(poolFee2._isSet).to.equal(false);
    });

    it("Set Fee To Setter", async function () {
      expect(await factory.feeToSetter()).to.equal(owner.address);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);

      await expect(
        factory.connect(addr1).setFeeToSetter(addr2.address)
      ).to.be.revertedWith("Forbidden");
      await expect(
        factory.connect(owner).setFeeToSetter(ethers.constants.AddressZero)
      ).to.be.revertedWithCustomError(factory, "ZeroAddress");

      await factory.connect(owner).setFeeToSetter(addr1.address);
      expect(await factory.feeToSetter()).to.equal(addr1.address);

      await expect(
        factory.connect(addr1).setFeeToSetter(addr2.address)
      ).to.be.revertedWith("Forbidden");

      await factory.connect(owner).setFeeToSetter(addr2.address);
      expect(await factory.feeToSetter()).to.equal(addr2.address);

      await expect(
        factory.connect(addr1).setFeeTo(ethers.constants.AddressZero)
      ).to.be.revertedWithCustomError(factory, "Forbidden");

      await expect(
        factory
          .connect(addr1)
          .setPoolFee(addr4.address, addr2.address, 20000, 20, false)
      ).to.be.revertedWithCustomError(factory, "Forbidden");

      await factory.connect(addr2).setFeeTo(ethers.constants.AddressZero);
      expect(await factory.feeTo()).to.equal(ethers.constants.AddressZero);

      await (
        await factory
          .connect(addr2)
          .setPoolFee(addr4.address, addr3.address, 20000, 10, true)
      ).wait();

      const poolFee = await factory.getPoolFee(addr4.address);
      expect(poolFee._to).to.equal(addr3.address);
      expect(poolFee._protocolFee).to.equal(20000);
      expect(poolFee._origFeeShare).to.equal(10);
      expect(poolFee._isSet).to.equal(true);
    });

    it("Set Rate for Pool Forbidden", async function () {
      const data = ethers.utils.defaultAbiCoder.encode([], []);
      await expect(
        factory.connect(addr1).setRateParams(addr1.address, data, false)
      ).to.be.revertedWith("FORBIDDEN");

      await expect(
        factory.setRateParams(addr1.address, data, false)
      ).to.be.revertedWithoutReason();

      await expect(
        factory.setRateParams(protocol.address, data, false)
      ).to.be.revertedWith("VALIDATE");

      const data1 = ethers.utils.defaultAbiCoder.encode(["uint256"], [1]);
      await (
        await factory.setRateParams(rateModel.address, data1, false)
      ).wait();

      const resp = await factory.getRateParams(rateModel.address);
      expect(resp.data).to.be.eq(data1);
      expect(resp.active).to.be.eq(false);

      await (
        await factory.setRateParams(rateModel.address, data1, true)
      ).wait();

      const resp1 = await factory.getRateParams(rateModel.address);
      expect(resp1.data).to.be.eq(data1);
      expect(resp1.active).to.be.eq(true);

      expect(await factory.rateParamsStoreOwner()).to.be.equal(
        await factory.owner()
      );
    });
  });

  describe("Setting Pool Params", function () {
    it("Forbidden Error", async function () {
      await (await factory.addProtocol(protocol.address)).wait();
      expect(await factory.allPoolsLength()).to.equal(0);

      const params = createPoolParamsObj(addr3.address, tokenA, tokenB);

      await factory.createPool(
        params.createPoolParams.protocolId,
        params.createPoolParams.cfmm,
        params.createPoolParams.tokens,
        params.data
      );

      const key = await addressCalculator.getGammaPoolKey(addr3.address, 1);
      const pool = await factory.getPool(key);
      expect(pool).to.not.equal(ethers.constants.AddressZero);
      expect(key).to.equal(await factory.getKey(pool));

      // Precalculated address
      const expectedPoolAddress = await addressCalculator.calcAddress(
        factory.address,
        1,
        key
      );
      expect(pool).to.equal(expectedPoolAddress);
      expect(await factory.allPoolsLength()).to.equal(1);

      await expect(
        factory.connect(addr1).setPoolParams(pool, 1, 2, 3, 4, 5, 6, 7, 8)
      ).to.be.revertedWithCustomError(factory, "Forbidden");
    });

    it("Params Error", async function () {
      await (await factory.addProtocol(protocol.address)).wait();
      expect(await factory.allPoolsLength()).to.equal(0);

      const params = createPoolParamsObj(addr3.address, tokenA, tokenB);

      await factory.createPool(
        params.createPoolParams.protocolId,
        params.createPoolParams.cfmm,
        params.createPoolParams.tokens,
        params.data
      );

      const key = await addressCalculator.getGammaPoolKey(addr3.address, 1);
      const pool = await factory.getPool(key);
      expect(pool).to.not.equal(ethers.constants.AddressZero);
      expect(key).to.equal(await factory.getKey(pool));

      const poolContract = GammaPool.attach(pool);

      // Precalculated address
      const expectedPoolAddress = await addressCalculator.calcAddress(
        factory.address,
        1,
        key
      );
      expect(pool).to.equal(expectedPoolAddress);
      expect(await factory.allPoolsLength()).to.equal(1);

      await expect(factory.setPoolParams(pool, 1, 2, 3, 101, 60, 0, 11, 1))
        .to.be.revertedWithCustomError(poolContract, "InvalidPoolParam")
        .withArgs(5);

      await expect(factory.setPoolParams(pool, 1, 2, 3, 95, 60, 0, 11, 1))
        .to.be.revertedWithCustomError(poolContract, "InvalidPoolParam")
        .withArgs(5);

      await expect(factory.setPoolParams(pool, 1, 2, 3, 94, 60, 0, 11, 1))
        .to.be.revertedWithCustomError(poolContract, "InvalidPoolParam")
        .withArgs(5);

      await expect(factory.setPoolParams(pool, 1, 2, 3, 78, 60, 1, 11, 1))
        .to.be.revertedWithCustomError(poolContract, "InvalidPoolParam")
        .withArgs(6);

      await expect(factory.setPoolParams(pool, 1, 2, 3, 77, 60, 100, 51, 5))
        .to.be.revertedWithCustomError(poolContract, "InvalidPoolParam")
        .withArgs(6);
    });

    it("Set Origination Fee", async function () {
      await (await factory.addProtocol(protocol.address)).wait();
      expect(await factory.allPoolsLength()).to.equal(0);

      const params = createPoolParamsObj(addr3.address, tokenA, tokenB);

      await factory.createPool(
        params.createPoolParams.protocolId,
        params.createPoolParams.cfmm,
        params.createPoolParams.tokens,
        params.data
      );

      const key = await addressCalculator.getGammaPoolKey(addr3.address, 1);
      const pool = await factory.getPool(key);
      expect(pool).to.not.equal(ethers.constants.AddressZero);
      expect(key).to.equal(await factory.getKey(pool));

      // Precalculated address
      const expectedPoolAddress = await addressCalculator.calcAddress(
        factory.address,
        1,
        key
      );
      expect(pool).to.equal(expectedPoolAddress);
      expect(await factory.allPoolsLength()).to.equal(1);

      const gammaPool = GammaPool.attach(pool);
      const resp = await gammaPool.getPoolData();
      expect(resp.origFee).to.equal(2);
      expect(resp.extSwapFee).to.equal(10);
      expect(resp.emaMultiplier).to.equal(10);
      expect(resp.minUtilRate1).to.equal(85);
      expect(resp.feeDivisor).to.equal(16384);

      const tx = await (
        await factory.setPoolParams(pool, 1, 2, 20, 84, 60, 1, 50, 10)
      ).wait();

      const event = tx.events[tx.events.length - 1];
      expect(event.args.pool).to.equal(pool);
      expect(event.args.origFee).to.equal(1);
      expect(event.args.extSwapFee).to.equal(2);
      expect(event.args.emaMultiplier).to.equal(20);
      expect(event.args.minUtilRate1).to.equal(84);
      expect(event.args.minUtilRate2).to.equal(60);
      expect(event.args.feeDivisor).to.equal(1);
      expect(event.args.liquidationFee).to.equal(50);
      expect(event.args.ltvThreshold).to.equal(10);

      const resp1 = await gammaPool.getPoolData();
      expect(resp1.origFee).to.equal(1);
      expect(resp1.extSwapFee).to.equal(2);
      expect(resp1.emaMultiplier).to.equal(20);
      expect(resp1.minUtilRate1).to.equal(84);
      expect(resp1.minUtilRate2).to.equal(60);
      expect(resp1.feeDivisor).to.equal(1);
      expect(resp1.liquidationFee).to.equal(50);
      expect(resp1.ltvThreshold).to.equal(10);

      const tx1 = await (
        await factory.setPoolParams(pool, 1, 2, 20, 84, 64, 65535, 50, 5)
      ).wait();

      const event1 = tx1.events[tx.events.length - 1];
      expect(event1.args.pool).to.equal(pool);
      expect(event1.args.origFee).to.equal(1);
      expect(event1.args.extSwapFee).to.equal(2);
      expect(event1.args.emaMultiplier).to.equal(20);
      expect(event1.args.minUtilRate1).to.equal(84);
      expect(event1.args.minUtilRate2).to.equal(64);
      expect(event1.args.feeDivisor).to.equal(65535);
      expect(event1.args.liquidationFee).to.equal(50);
      expect(event1.args.ltvThreshold).to.equal(5);

      const resp2 = await gammaPool.getPoolData();
      expect(resp2.origFee).to.equal(1);
      expect(resp2.extSwapFee).to.equal(2);
      expect(resp2.emaMultiplier).to.equal(20);
      expect(resp2.minUtilRate1).to.equal(84);
      expect(resp2.minUtilRate2).to.equal(64);
      expect(resp2.feeDivisor).to.equal(65535);
      expect(resp2.liquidationFee).to.equal(50);
      expect(resp2.ltvThreshold).to.equal(5);
    });
  });

  describe("Setting Loan Observer", function () {
    it("Check Loan Observer Owner", async function () {
      expect(await factory.loanObserverStoreOwner()).to.be.equal(
        await factory.owner()
      );
    });

    it("Allow to be Observed Errors", async function () {
      await expect(
        factory.connect(addr1).allowToBeObserved(1, addr2.address, false)
      ).to.be.revertedWith("FORBIDDEN");

      await expect(
        factory.allowToBeObserved(1, addr2.address, false)
      ).to.be.revertedWith("NOT_EXISTS");
    });

    it("Set Loan Observer Errors", async function () {
      await expect(
        factory
          .connect(addr1)
          .setLoanObserver(1, addr2.address, 1000, 1, true, false)
      ).to.be.revertedWith("FORBIDDEN");

      await expect(
        factory.setLoanObserver(1, addr2.address, 1000, 1, true, false)
      ).to.be.revertedWith("NOT_ZERO_ADDRESS");
    });

    it("Set Loan Observer", async function () {
      await (
        await factory.setLoanObserver(
          1,
          ethers.constants.AddressZero,
          1000,
          1,
          true,
          false
        )
      ).wait();
    });
  });

  describe("Transfer Ownership", function () {
    it("Forbidden transfer", async function () {
      expect(await factory.owner()).to.equal(owner.address);
      await expect(
        factory.connect(addr1).transferOwnership(addr2.address)
      ).to.be.revertedWith("Forbidden");
    });

    it("Transfer to ZeroAddress", async function () {
      expect(await factory.owner()).to.equal(owner.address);
      await expect(
        factory.transferOwnership(ethers.constants.AddressZero)
      ).to.be.revertedWith("ZeroAddress");
    });

    it("Replace Transfer Started", async function () {
      expect(await factory.owner()).to.equal(owner.address);
      const res = await (await factory.transferOwnership(addr1.address)).wait();
      expect(res.events[0].event).to.equal("OwnershipTransferStarted");
      expect(res.events[0].args.currentOwner).to.equal(owner.address);
      expect(res.events[0].args.newOwner).to.equal(addr1.address);
      expect(await factory.pendingOwner()).to.equal(addr1.address);
      expect(await factory.owner()).to.equal(owner.address);

      const res0 = await (
        await factory.transferOwnership(addr2.address)
      ).wait();
      expect(res0.events[0].event).to.equal("OwnershipTransferStarted");
      expect(res0.events[0].args.currentOwner).to.equal(owner.address);
      expect(res0.events[0].args.newOwner).to.equal(addr2.address);
      expect(await factory.pendingOwner()).to.equal(addr2.address);
      expect(await factory.owner()).to.equal(owner.address);
    });

    it("Accept Transfer Fail", async function () {
      expect(await factory.owner()).to.equal(owner.address);
      const res = await (await factory.transferOwnership(addr1.address)).wait();
      expect(res.events[0].event).to.equal("OwnershipTransferStarted");
      expect(res.events[0].args.currentOwner).to.equal(owner.address);
      expect(res.events[0].args.newOwner).to.equal(addr1.address);
      expect(await factory.pendingOwner()).to.equal(addr1.address);
      expect(await factory.owner()).to.equal(owner.address);
      await expect(factory.acceptOwnership()).to.be.revertedWith("NotNewOwner");
    });

    it("Accept Transfer Success", async function () {
      expect(await factory.owner()).to.equal(owner.address);
      const res = await (await factory.transferOwnership(addr1.address)).wait();
      expect(res.events[0].event).to.equal("OwnershipTransferStarted");
      expect(res.events[0].args.currentOwner).to.equal(owner.address);
      expect(res.events[0].args.newOwner).to.equal(addr1.address);
      expect(await factory.pendingOwner()).to.equal(addr1.address);
      expect(await factory.owner()).to.equal(owner.address);

      const res0 = await (
        await factory.connect(addr1).acceptOwnership()
      ).wait();
      expect(res0.events[0].event).to.equal("OwnershipTransferred");
      expect(res0.events[0].args.previousOwner).to.equal(owner.address);
      expect(res0.events[0].args.newOwner).to.equal(addr1.address);
      expect(await factory.pendingOwner()).to.equal(
        ethers.constants.AddressZero
      );
      expect(await factory.owner()).to.equal(addr1.address);
    });
  });

  async function createPool() {
    await (await factory.addProtocol(protocolExternal.address)).wait();
    expect(await factory.allPoolsLength()).to.equal(0);

    const params = createPoolParamsObj(addr3.address, tokenA, tokenB);

    await factory.createPool(
      PROTOCOL_EXTERNAL_ID,
      params.createPoolParams.cfmm,
      params.createPoolParams.tokens,
      params.data
    );

    expect(await factory.allPoolsLength()).to.equal(1);

    const key = await addressCalculator.getGammaPoolKey(
      addr3.address,
      PROTOCOL_EXTERNAL_ID
    );
    const pool = await factory.getPool(key);
    return pool;
  }

  describe("Pause GammaPool", function () {
    it("Forbidden pause", async function () {
      const pool = await createPool();

      await expect(
        factory.connect(addr1).pausePoolFunction(pool, 0)
      ).to.be.revertedWith("Forbidden");

      await expect(
        factory.connect(addr1).pausePoolFunction(pool, 1)
      ).to.be.revertedWith("Forbidden");

      await expect(
        factory.connect(addr1).pausePoolFunction(pool, 2)
      ).to.be.revertedWith("Forbidden");

      await expect(
        factory.connect(addr1).pausePoolFunction(pool, 3)
      ).to.be.revertedWith("Forbidden");
    });

    it("Forbidden unpause", async function () {
      const pool = await createPool();

      await expect(
        factory.connect(addr1).unpausePoolFunction(pool, 0)
      ).to.be.revertedWith("Forbidden");

      await expect(
        factory.connect(addr1).unpausePoolFunction(pool, 1)
      ).to.be.revertedWith("Forbidden");

      await expect(
        factory.connect(addr1).unpausePoolFunction(pool, 2)
      ).to.be.revertedWith("Forbidden");

      await expect(
        factory.connect(addr1).unpausePoolFunction(pool, 3)
      ).to.be.revertedWith("Forbidden");
    });

    it("Pause & Unpause all functions", async function () {
      const pool = await createPool();

      const gammapool = GammaPoolExternal.attach(pool);

      expect(await gammapool.isPaused(0)).to.equal(false);
      expect(await gammapool.isPaused(1)).to.equal(false);
      expect(await gammapool.isPaused(2)).to.equal(false);
      expect(await gammapool.isPaused(3)).to.equal(false);
      expect(await gammapool.isPaused(4)).to.equal(false);
      expect(await gammapool.isPaused(5)).to.equal(false);
      expect(await gammapool.isPaused(6)).to.equal(false);
      expect(await gammapool.isPaused(7)).to.equal(false);
      expect(await gammapool.isPaused(8)).to.equal(false);
      expect(await gammapool.isPaused(9)).to.equal(false);
      expect(await gammapool.isPaused(10)).to.equal(false);
      expect(await gammapool.isPaused(11)).to.equal(false);
      expect(await gammapool.isPaused(12)).to.equal(false);
      expect(await gammapool.isPaused(13)).to.equal(false);
      expect(await gammapool.isPaused(14)).to.equal(false);
      expect(await gammapool.isPaused(15)).to.equal(false);
      expect(await gammapool.isPaused(16)).to.equal(false);
      expect(await gammapool.isPaused(17)).to.equal(false);
      expect(await gammapool.isPaused(18)).to.equal(false);
      expect(await gammapool.isPaused(19)).to.equal(false);
      expect(await gammapool.isPaused(20)).to.equal(false);
      expect(await gammapool.isPaused(21)).to.equal(false);
      expect(await gammapool.isPaused(22)).to.equal(false);
      expect(await gammapool.isPaused(23)).to.equal(false);
      expect(await gammapool.isPaused(24)).to.equal(false);
      expect(await gammapool.isPaused(25)).to.equal(false);

      await (await factory.pausePoolFunction(pool, 0)).wait();

      expect(await gammapool.isPaused(0)).to.equal(true);
      expect(await gammapool.isPaused(1)).to.equal(true);
      expect(await gammapool.isPaused(2)).to.equal(true);
      expect(await gammapool.isPaused(3)).to.equal(true);
      expect(await gammapool.isPaused(4)).to.equal(true);
      expect(await gammapool.isPaused(5)).to.equal(true);
      expect(await gammapool.isPaused(6)).to.equal(true);
      expect(await gammapool.isPaused(7)).to.equal(true);
      expect(await gammapool.isPaused(8)).to.equal(true);
      expect(await gammapool.isPaused(9)).to.equal(true);
      expect(await gammapool.isPaused(10)).to.equal(true);
      expect(await gammapool.isPaused(11)).to.equal(true);
      expect(await gammapool.isPaused(12)).to.equal(true);
      expect(await gammapool.isPaused(13)).to.equal(true);
      expect(await gammapool.isPaused(14)).to.equal(true);
      expect(await gammapool.isPaused(15)).to.equal(true);
      expect(await gammapool.isPaused(16)).to.equal(true);
      expect(await gammapool.isPaused(17)).to.equal(true);
      expect(await gammapool.isPaused(18)).to.equal(true);
      expect(await gammapool.isPaused(19)).to.equal(true);
      expect(await gammapool.isPaused(20)).to.equal(true);
      expect(await gammapool.isPaused(21)).to.equal(true);
      expect(await gammapool.isPaused(22)).to.equal(true);
      expect(await gammapool.isPaused(23)).to.equal(true);
      expect(await gammapool.isPaused(24)).to.equal(true);
      expect(await gammapool.isPaused(25)).to.equal(true);

      await expect(
        gammapool.deposit(1, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.mint(2, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.withdraw(3, owner.address, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.redeem(4, owner.address, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.depositNoPull(owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.withdrawNoPull(owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.depositReserves(
          owner.address,
          [],
          [],
          ethers.constants.HashZero
        )
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.withdrawReserves(owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(gammapool.createLoan(0)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );
      await expect(
        gammapool.increaseCollateral(1, [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.decreaseCollateral(1, [], owner.address, [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.borrowLiquidity(1, 2, [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.repayLiquidity(1, 2, 1, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.repayLiquiditySetRatio(1, 2, [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.repayLiquidityWithLP(1, 2, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.rebalanceCollateral(1, [], [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(gammapool.updatePool(1)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );
      await expect(gammapool.liquidate(1)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );
      await expect(gammapool.liquidateWithLP(1)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );
      await expect(
        gammapool.batchLiquidations([])
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(gammapool.sync()).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );
      await expect(gammapool.skim(owner.address)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );

      await expect(
        gammapool.clearToken(tokenA.address, owner.address, 0)
      ).to.be.revertedWithCustomError(gammapool, "Paused");
      await expect(
        gammapool.rebalanceExternally(
          1,
          [],
          1,
          owner.address,
          ethers.constants.HashZero
        )
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      await expect(
        gammapool.liquidateExternally(
          1,
          [],
          1,
          owner.address,
          ethers.constants.HashZero
        )
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      await (await factory.unpausePoolFunction(pool, 0)).wait();

      expect(await gammapool.isPaused(0)).to.equal(false);
      expect(await gammapool.isPaused(1)).to.equal(false);
      expect(await gammapool.isPaused(2)).to.equal(false);
      expect(await gammapool.isPaused(3)).to.equal(false);
      expect(await gammapool.isPaused(4)).to.equal(false);
      expect(await gammapool.isPaused(5)).to.equal(false);
      expect(await gammapool.isPaused(6)).to.equal(false);
      expect(await gammapool.isPaused(7)).to.equal(false);
      expect(await gammapool.isPaused(8)).to.equal(false);
      expect(await gammapool.isPaused(9)).to.equal(false);
      expect(await gammapool.isPaused(10)).to.equal(false);
      expect(await gammapool.isPaused(11)).to.equal(false);
      expect(await gammapool.isPaused(12)).to.equal(false);
      expect(await gammapool.isPaused(13)).to.equal(false);
      expect(await gammapool.isPaused(14)).to.equal(false);
      expect(await gammapool.isPaused(15)).to.equal(false);
      expect(await gammapool.isPaused(16)).to.equal(false);
      expect(await gammapool.isPaused(17)).to.equal(false);
      expect(await gammapool.isPaused(18)).to.equal(false);
      expect(await gammapool.isPaused(19)).to.equal(false);
      expect(await gammapool.isPaused(20)).to.equal(false);
      expect(await gammapool.isPaused(21)).to.equal(false);
      expect(await gammapool.isPaused(22)).to.equal(false);
      expect(await gammapool.isPaused(23)).to.equal(false);
      expect(await gammapool.isPaused(24)).to.equal(false);
      expect(await gammapool.isPaused(25)).to.equal(false);

      await expect(
        gammapool.deposit(1, owner.address)
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.mint(2, owner.address)
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.withdraw(3, owner.address, owner.address)
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.redeem(4, owner.address, owner.address)
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.depositNoPull(owner.address)
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.withdrawNoPull(owner.address)
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.depositReserves(
          owner.address,
          [],
          [],
          ethers.constants.HashZero
        )
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.withdrawReserves(owner.address)
      ).to.be.revertedWithoutReason();
      await expect(gammapool.createLoan(0)).to.not.be.revertedWithoutReason();
      await expect(
        gammapool.increaseCollateral(1, [])
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.decreaseCollateral(1, [], owner.address, [])
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.borrowLiquidity(1, 2, [])
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.repayLiquidity(1, 2, 1, owner.address)
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.repayLiquiditySetRatio(1, 2, [])
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.repayLiquidityWithLP(1, 2, owner.address)
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.rebalanceCollateral(1, [], [])
      ).to.be.revertedWithoutReason();
      await expect(gammapool.updatePool(1)).to.be.revertedWithoutReason();
      await expect(gammapool.liquidate(1)).to.be.revertedWithoutReason();
      await expect(gammapool.liquidateWithLP(1)).to.be.revertedWithoutReason();
      await expect(
        gammapool.batchLiquidations([])
      ).to.be.revertedWithoutReason();
      await expect(gammapool.sync()).to.not.be.revertedWithoutReason();
      await expect(gammapool.skim(owner.address)).to.be.revertedWithoutReason();
      await expect(
        gammapool.clearToken(tokenA.address, owner.address, 0)
      ).to.not.be.revertedWithoutReason();
      await expect(
        gammapool.rebalanceExternally(
          1,
          [],
          1,
          owner.address,
          ethers.constants.HashZero
        )
      ).to.be.revertedWithoutReason();
      await expect(
        gammapool.liquidateExternally(
          1,
          [],
          1,
          owner.address,
          ethers.constants.HashZero
        )
      ).to.be.revertedWithoutReason();
    });

    it("Pause & Unpause individual functions", async function () {
      const pool = await createPool();

      const gammapool = GammaPoolExternal.attach(pool);

      // Pausing

      expect(await gammapool.isPaused(1)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 1)).wait();
      expect(await gammapool.isPaused(1)).to.equal(true);

      await expect(
        gammapool.deposit(1, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(2)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 2)).wait();
      expect(await gammapool.isPaused(2)).to.equal(true);

      await expect(
        gammapool.mint(2, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(3)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 3)).wait();
      expect(await gammapool.isPaused(3)).to.equal(true);

      await expect(
        gammapool.withdraw(3, owner.address, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(4)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 4)).wait();
      expect(await gammapool.isPaused(4)).to.equal(true);

      await expect(
        gammapool.redeem(4, owner.address, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(5)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 5)).wait();
      expect(await gammapool.isPaused(5)).to.equal(true);

      await expect(
        gammapool.depositNoPull(owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(6)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 6)).wait();
      expect(await gammapool.isPaused(6)).to.equal(true);

      await expect(
        gammapool.withdrawNoPull(owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(7)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 7)).wait();
      expect(await gammapool.isPaused(7)).to.equal(true);

      await expect(
        gammapool.depositReserves(
          owner.address,
          [],
          [],
          ethers.constants.HashZero
        )
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(8)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 8)).wait();
      expect(await gammapool.isPaused(8)).to.equal(true);

      await expect(
        gammapool.withdrawReserves(owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(9)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 9)).wait();
      expect(await gammapool.isPaused(9)).to.equal(true);

      await expect(gammapool.createLoan(0)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );

      expect(await gammapool.isPaused(10)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 10)).wait();
      expect(await gammapool.isPaused(10)).to.equal(true);

      await expect(
        gammapool.increaseCollateral(1, [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(11)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 11)).wait();
      expect(await gammapool.isPaused(11)).to.equal(true);

      await expect(
        gammapool.decreaseCollateral(1, [], owner.address, [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(12)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 12)).wait();
      expect(await gammapool.isPaused(12)).to.equal(true);

      await expect(
        gammapool.borrowLiquidity(1, 2, [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(13)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 13)).wait();
      expect(await gammapool.isPaused(13)).to.equal(true);

      await expect(
        gammapool.repayLiquidity(1, 2, 1, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(14)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 14)).wait();
      expect(await gammapool.isPaused(14)).to.equal(true);

      await expect(
        gammapool.repayLiquiditySetRatio(1, 2, [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(15)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 15)).wait();
      expect(await gammapool.isPaused(15)).to.equal(true);

      await expect(
        gammapool.repayLiquidityWithLP(1, 2, owner.address)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(16)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 16)).wait();
      expect(await gammapool.isPaused(16)).to.equal(true);

      await expect(
        gammapool.rebalanceCollateral(1, [], [])
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(17)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 17)).wait();
      expect(await gammapool.isPaused(17)).to.equal(true);

      await expect(gammapool.updatePool(1)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );

      expect(await gammapool.isPaused(18)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 18)).wait();
      expect(await gammapool.isPaused(18)).to.equal(true);

      await expect(gammapool.liquidate(1)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );

      expect(await gammapool.isPaused(19)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 19)).wait();
      expect(await gammapool.isPaused(19)).to.equal(true);

      await expect(gammapool.liquidateWithLP(1)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );

      expect(await gammapool.isPaused(20)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 20)).wait();
      expect(await gammapool.isPaused(20)).to.equal(true);

      await expect(
        gammapool.batchLiquidations([])
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(21)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 21)).wait();
      expect(await gammapool.isPaused(21)).to.equal(true);

      await expect(gammapool.sync()).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );

      expect(await gammapool.isPaused(22)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 22)).wait();
      expect(await gammapool.isPaused(22)).to.equal(true);

      await expect(gammapool.skim(owner.address)).to.be.revertedWithCustomError(
        gammapool,
        "Paused"
      );

      expect(await gammapool.isPaused(23)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 23)).wait();
      expect(await gammapool.isPaused(23)).to.equal(true);

      await expect(
        gammapool.clearToken(tokenA.address, owner.address, 0)
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(24)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 24)).wait();
      expect(await gammapool.isPaused(24)).to.equal(true);

      await expect(
        gammapool.rebalanceExternally(
          1,
          [],
          1,
          owner.address,
          ethers.constants.HashZero
        )
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      expect(await gammapool.isPaused(25)).to.equal(false);
      await (await factory.pausePoolFunction(pool, 25)).wait();
      expect(await gammapool.isPaused(25)).to.equal(true);

      await expect(
        gammapool.liquidateExternally(
          1,
          [],
          1,
          owner.address,
          ethers.constants.HashZero
        )
      ).to.be.revertedWithCustomError(gammapool, "Paused");

      // Unpausing

      expect(await gammapool.isPaused(1)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 1)).wait();
      expect(await gammapool.isPaused(1)).to.equal(false);

      await expect(
        gammapool.deposit(1, owner.address)
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(2)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 2)).wait();
      expect(await gammapool.isPaused(2)).to.equal(false);

      await expect(
        gammapool.mint(2, owner.address)
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(3)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 3)).wait();
      expect(await gammapool.isPaused(3)).to.equal(false);

      await expect(
        gammapool.withdraw(3, owner.address, owner.address)
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(4)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 4)).wait();
      expect(await gammapool.isPaused(4)).to.equal(false);

      await expect(
        gammapool.redeem(4, owner.address, owner.address)
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(5)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 5)).wait();
      expect(await gammapool.isPaused(5)).to.equal(false);

      await expect(
        gammapool.depositNoPull(owner.address)
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(6)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 6)).wait();
      expect(await gammapool.isPaused(6)).to.equal(false);

      await expect(
        gammapool.withdrawNoPull(owner.address)
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(7)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 7)).wait();
      expect(await gammapool.isPaused(7)).to.equal(false);

      await expect(
        gammapool.depositReserves(
          owner.address,
          [],
          [],
          ethers.constants.HashZero
        )
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(8)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 8)).wait();
      expect(await gammapool.isPaused(8)).to.equal(false);

      await expect(
        gammapool.withdrawReserves(owner.address)
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(9)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 9)).wait();
      expect(await gammapool.isPaused(9)).to.equal(false);

      await expect(gammapool.createLoan(0)).to.not.be.revertedWithoutReason();

      expect(await gammapool.isPaused(10)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 10)).wait();
      expect(await gammapool.isPaused(10)).to.equal(false);

      await expect(
        gammapool.increaseCollateral(1, [])
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(11)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 11)).wait();
      expect(await gammapool.isPaused(11)).to.equal(false);

      await expect(
        gammapool.decreaseCollateral(1, [], owner.address, [])
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(12)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 12)).wait();
      expect(await gammapool.isPaused(12)).to.equal(false);

      await expect(
        gammapool.borrowLiquidity(1, 2, [])
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(13)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 13)).wait();
      expect(await gammapool.isPaused(13)).to.equal(false);

      await expect(
        gammapool.repayLiquidity(1, 2, 1, owner.address)
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(14)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 14)).wait();
      expect(await gammapool.isPaused(14)).to.equal(false);

      await expect(
        gammapool.repayLiquiditySetRatio(1, 2, [])
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(15)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 15)).wait();
      expect(await gammapool.isPaused(15)).to.equal(false);

      await expect(
        gammapool.repayLiquidityWithLP(1, 2, owner.address)
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(16)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 16)).wait();
      expect(await gammapool.isPaused(16)).to.equal(false);

      await expect(
        gammapool.rebalanceCollateral(1, [], [])
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(17)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 17)).wait();
      expect(await gammapool.isPaused(17)).to.equal(false);

      await expect(gammapool.updatePool(1)).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(18)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 18)).wait();
      expect(await gammapool.isPaused(18)).to.equal(false);

      await expect(gammapool.liquidate(1)).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(19)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 19)).wait();
      expect(await gammapool.isPaused(19)).to.equal(false);

      await expect(gammapool.liquidateWithLP(1)).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(20)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 20)).wait();
      expect(await gammapool.isPaused(20)).to.equal(false);

      await expect(
        gammapool.batchLiquidations([])
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(21)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 21)).wait();
      expect(await gammapool.isPaused(21)).to.equal(false);

      await expect(gammapool.sync()).to.not.be.revertedWithoutReason();

      expect(await gammapool.isPaused(22)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 22)).wait();
      expect(await gammapool.isPaused(22)).to.equal(false);

      await expect(gammapool.skim(owner.address)).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(23)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 23)).wait();
      expect(await gammapool.isPaused(23)).to.equal(false);

      await expect(
        gammapool.clearToken(tokenA.address, owner.address, 0)
      ).to.not.be.revertedWithoutReason();

      expect(await gammapool.isPaused(24)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 24)).wait();
      expect(await gammapool.isPaused(24)).to.equal(false);

      await expect(
        gammapool.rebalanceExternally(
          1,
          [],
          1,
          owner.address,
          ethers.constants.HashZero
        )
      ).to.be.revertedWithoutReason();

      expect(await gammapool.isPaused(25)).to.equal(true);
      await (await factory.unpausePoolFunction(pool, 25)).wait();
      expect(await gammapool.isPaused(25)).to.equal(false);

      await expect(
        gammapool.liquidateExternally(
          1,
          [],
          1,
          owner.address,
          ethers.constants.HashZero
        )
      ).to.be.revertedWithoutReason();
    });
  });
});
