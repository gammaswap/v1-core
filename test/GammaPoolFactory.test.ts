import { ethers } from "hardhat";
import { expect } from "chai";

const PROTOCOL_ID = 1;

describe("GammaPoolFactory", function () {
  let TestERC20: any;
  let TestAddressCalculator: any;
  let GammaPool: any;
  let GammaPoolFactory: any;
  let factory: any;
  let addressCalculator: any;
  let protocol: any;
  let protocolZero: any;
  let tokenA: any;
  let tokenB: any;
  let tokenC: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let addr4: any;
  let addr5: any;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    GammaPool = await ethers.getContractFactory("TestGammaPool");
    GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
    TestAddressCalculator = await ethers.getContractFactory(
      "TestAddressCalculator"
    );
    [owner, addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");
    factory = await GammaPoolFactory.deploy(owner.address);

    protocol = await GammaPool.deploy(
      factory.address,
      PROTOCOL_ID,
      addr1.address,
      addr2.address,
      addr5.address
    );

    addressCalculator = await TestAddressCalculator.deploy();

    protocolZero = await GammaPool.deploy(
      factory.address,
      0,
      addr1.address,
      addr2.address,
      addr5.address
    );

    // address _longStrategy, address _shortStrategy, uint24 _protocol

    // We can interact with the contract by calling `hardhatToken.method()`
    await tokenA.deployed();
    await tokenB.deployed();
    await factory.deployed();
    await protocol.deployed();
  });

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
      await expect(factory.addProtocol(protocol.address)).to.be.revertedWith(
        "ProtocolExists"
      );

      await expect(
        factory.addProtocol(protocolZero.address)
      ).to.be.revertedWith("ZeroProtocol");

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
      await factory.addProtocol(protocol.address);
      expect(await factory.allPoolsLength()).to.equal(0);
      const createPoolParams = {
        protocolId: 1,
        cfmm: addr3.address,
        tokens: [tokenA.address, tokenB.address],
      };
      await factory.createPool(
        createPoolParams.protocolId,
        createPoolParams.cfmm,
        createPoolParams.tokens
      );
      const key = await addressCalculator.getGammaPoolKey(addr3.address, 1);
      const pool = await factory.getPool(key);
      expect(pool).to.not.equal(ethers.constants.AddressZero);

      // Precalculated address
      const expectedPoolAddress = await addressCalculator.calcAddress(
        factory.address,
        1,
        key
      );
      expect(pool).to.equal(expectedPoolAddress);
      expect(await factory.allPoolsLength()).to.equal(1);
    });

    it("Create Pool Errors", async function () {
      await factory.removeProtocol(1);
      const createPoolParams = {
        cfmm: addr3.address,
        protocolId: 1,
        tokens: [tokenA.address, tokenB.address],
      };
      await expect(
        factory.createPool(
          createPoolParams.protocolId,
          createPoolParams.cfmm,
          createPoolParams.tokens
        )
      ).to.be.revertedWith("ProtocolNotSet");
      await factory.addProtocol(protocol.address);

      await factory.createPool(
        createPoolParams.protocolId,
        createPoolParams.cfmm,
        createPoolParams.tokens
      );
      await expect(
        factory.createPool(
          createPoolParams.protocolId,
          createPoolParams.cfmm,
          createPoolParams.tokens
        )
      ).to.be.revertedWith("PoolExists");

      await factory.setIsProtocolRestricted(1, true);

      const createPoolParams2 = {
        cfmm: addr4.address,
        protocolId: 1,
        tokens: [tokenA.address, tokenC.address],
      };
      await expect(
        factory
          .connect(addr1)
          .createPool(
            createPoolParams2.protocolId,
            createPoolParams2.cfmm,
            createPoolParams2.tokens
          )
      ).to.be.revertedWith("ProtocolRestricted");

      await factory.setIsProtocolRestricted(1, false);

      await factory
        .connect(addr1)
        .createPool(
          createPoolParams2.protocolId,
          createPoolParams2.cfmm,
          createPoolParams2.tokens
        );

      await expect(
        factory.createPool(
          createPoolParams2.protocolId,
          createPoolParams2.cfmm,
          createPoolParams2.tokens
        )
      ).to.be.revertedWith("PoolExists");
    });
  });

  describe("Setting Fees", function () {
    it("Set Fee", async function () {
      expect(await factory.fee()).to.equal(10000);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      await expect(factory.connect(addr1).setFee(1)).to.be.revertedWith(
        "Forbidden"
      );
      await factory.connect(owner).setFee(1);
      expect(await factory.fee()).to.equal(1);
    });

    it("Set Fee To", async function () {
      expect(await factory.feeTo()).to.equal(owner.address);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      await expect(
        factory.connect(addr1).setFeeTo(addr2.address)
      ).to.be.revertedWith("Forbidden");
      await factory.connect(owner).setFeeTo(addr2.address);
      expect(await factory.feeTo()).to.equal(addr2.address);
    });

    it("Set Fee To Setter", async function () {
      expect(await factory.feeToSetter()).to.equal(owner.address);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      await expect(
        factory.connect(addr1).setFeeToSetter(addr2.address)
      ).to.be.revertedWith("Forbidden");
      await factory.connect(owner).setFeeToSetter(addr1.address);
      expect(await factory.feeToSetter()).to.equal(addr1.address);

      await factory.connect(addr1).setFeeToSetter(addr2.address);
      expect(await factory.feeToSetter()).to.equal(addr2.address);
    });
  });
});
