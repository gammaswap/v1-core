import { ethers } from "hardhat";
import { expect } from "chai";

describe("GammaPoolFactory", function () {
  let TestERC20: any;
  let TestProtocol: any;
  let TestAddressCalculator: any;
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
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
    TestProtocol = await ethers.getContractFactory("TestProtocol");
    TestAddressCalculator = await ethers.getContractFactory(
      "TestAddressCalculator"
    );
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    tokenC = await TestERC20.deploy("Test Token C", "TOKC");
    factory = await GammaPoolFactory.deploy(owner.address);
    addressCalculator = await TestAddressCalculator.deploy();
    protocol = await TestProtocol.deploy(addr1.address, addr2.address, 1);
    protocolZero = await TestProtocol.deploy(addr1.address, addr2.address, 0);

    // address _longStrategy, address _shortStrategy, uint24 _protocol

    // We can interact with the contract by calling `hardhatToken.method()`
    await tokenA.deployed();
    await tokenB.deployed();
    await factory.deployed();
    await protocol.deployed();
    await protocolZero.deployed();
    await addressCalculator.deployed();
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set the right initial fields", async function () {
      expect(await factory.owner()).to.equal(owner.address);
      expect(await factory.feeToSetter()).to.equal(owner.address);
      const feeInfo = await factory.feeInfo();
      expect(feeInfo._feeTo).to.equal(owner.address);
      const fee = ethers.BigNumber.from(5).mul(
        ethers.BigNumber.from(10).pow(16)
      );
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
      await factory.addProtocol(protocol.address);
      expect(await factory.getProtocol(0)).to.equal(
        ethers.constants.AddressZero
      );
      expect(await factory.getProtocol(1)).to.equal(protocol.address);

      await factory.removeProtocol(1);
      expect(await factory.getProtocol(1)).to.equal(
        ethers.constants.AddressZero
      );

      await factory.addProtocol(protocol.address);
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
        cfmm: addr3.address,
        protocol: 1,
        tokens: [tokenA.address, tokenB.address],
      };
      await factory.createPool(createPoolParams);
      const key = await addressCalculator.getGammaPoolKey(addr3.address, 1);
      const pool = await factory.getPool(key);
      expect(pool).to.not.equal(ethers.constants.AddressZero);

      // Precalculated address
      const expectedPoolAddress = await addressCalculator.calcAddress(
        factory.address,
        key
      );
      expect(pool).to.equal(expectedPoolAddress);
      expect(await factory.allPoolsLength()).to.equal(1);
    });

    it("Create Pool Errors", async function () {
      await factory.removeProtocol(1);
      const createPoolParams = {
        cfmm: addr3.address,
        protocol: 1,
        tokens: [tokenA.address, tokenB.address],
      };
      await expect(factory.createPool(createPoolParams)).to.be.revertedWith(
        "ProtocolNotSet"
      );
      await factory.addProtocol(protocol.address);

      await factory.createPool(createPoolParams);

      await expect(factory.createPool(createPoolParams)).to.be.revertedWith(
        "PoolExists"
      );

      await factory.setIsProtocolRestricted(1, true);

      const createPoolParams2 = {
        cfmm: addr4.address,
        protocol: 1,
        tokens: [tokenA.address, tokenC.address],
      };
      await expect(
        factory.connect(addr1).createPool(createPoolParams2)
      ).to.be.revertedWith("ProtocolRestricted");

      await factory.setIsProtocolRestricted(1, false);

      await factory.connect(addr1).createPool(createPoolParams2);

      await expect(factory.createPool(createPoolParams2)).to.be.revertedWith(
        "PoolExists"
      );
    });
  });

  describe("Setting Fees", function () {
    it("Set Fee", async function () {
      expect(await factory.fee()).to.equal(
        ethers.BigNumber.from(5).mul(ethers.BigNumber.from(10).pow(16))
      );
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
