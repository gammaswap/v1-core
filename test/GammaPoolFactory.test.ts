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
      PROTOCOL_ID,
      factory.address,
      addr1.address,
      addr2.address,
      addr5.address
    );

    addressCalculator = await TestAddressCalculator.deploy();

    protocolZero = await GammaPool.deploy(
      0,
      factory.address,
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

      const params = {
        protocolId: 1,
        cfmm: addr3.address,
      };
      const data = ethers.utils.defaultAbiCoder.encode(
        ["tuple(uint16 protocolId, address cfmm)"],
        [params]
      );

      await factory.createPool(
        createPoolParams.protocolId,
        createPoolParams.cfmm,
        createPoolParams.tokens,
        data
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
      ).to.be.revertedWith("ProtocolNotSet");
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
      ).to.be.revertedWith("PoolExists");

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
      ).to.be.revertedWith("ProtocolRestricted");

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
      ).to.be.revertedWith("PoolExists");
    });
  });

  describe("Setting Fees", function () {
    it("Set Fee", async function () {
      expect(await factory.fee()).to.equal(10000);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      await expect(factory.connect(addr1).setFee(1, 2, 3)).to.be.revertedWith(
        "Forbidden"
      );
      const feeTo = await factory.feeTo();
      const res = await (await factory.connect(owner).setFee(1, 2, 3)).wait();
      expect(await factory.fee()).to.equal(1);
      expect(await factory.origMin()).to.equal(2);
      expect(await factory.origMax()).to.equal(3);

      expect(res.events[0].event).to.equal("FeeUpdate");
      expect(res.events[0].args.pool).to.equal(ethers.constants.AddressZero);
      expect(res.events[0].args.to).to.equal(feeTo);
      expect(res.events[0].args.protocolFee).to.equal(1);
      expect(res.events[0].args.origMin).to.equal(2);
      expect(res.events[0].args.origMax).to.equal(3);
      expect(res.events[0].args.isSet).to.equal(false);

      const feeInfo = await factory.connect(owner).feeInfo();
      expect(feeInfo._feeTo).to.equal(owner.address);
      expect(feeInfo._fee).to.equal(1);
      expect(feeInfo._origMin).to.equal(2);
      expect(feeInfo._origMax).to.equal(3);
    });

    it("Set Fee To", async function () {
      expect(await factory.feeTo()).to.equal(owner.address);
      const _feeToSetter = await factory.feeToSetter();
      expect(_feeToSetter).to.equal(owner.address);
      await expect(
        factory.connect(addr1).setFeeTo(addr2.address)
      ).to.be.revertedWith("Forbidden");
      const res = await (await factory.connect(owner).setFeeTo(addr2.address)).wait();
      expect(await factory.feeTo()).to.equal(addr2.address);

      expect(res.events[0].event).to.equal("FeeUpdate");
      expect(res.events[0].args.pool).to.equal(ethers.constants.AddressZero);
      expect(res.events[0].args.to).to.equal(addr2.address);
      expect(res.events[0].args.protocolFee).to.equal(10000);
      expect(res.events[0].args.origMin).to.equal(10000);
      expect(res.events[0].args.origMax).to.equal(10000);
      expect(res.events[0].args.isSet).to.equal(false);

      const feeInfo = await factory.connect(owner).feeInfo();
      expect(feeInfo._feeTo).to.equal(addr2.address);
      expect(feeInfo._fee).to.equal(10000);
      expect(feeInfo._origMin).to.equal(10000);
      expect(feeInfo._origMax).to.equal(10000);
    });

    it("Set Fee for Pool", async function () {
      const poolFee = await factory.getPoolFee(addr1.address);
      expect(poolFee._to).to.equal(owner.address);
      expect(poolFee._protocolFee).to.equal(10000);
      expect(poolFee._origMinFee).to.equal(10000);
      expect(poolFee._origMaxFee).to.equal(10000);
      expect(poolFee._isSet).to.equal(false);
      const res = await (
        await factory.setPoolFee(
          addr1.address,
          addr2.address,
          20000,
          30000,
          40000,
          true
        )
      ).wait();

      expect(res.events[0].event).to.equal("FeeUpdate");
      expect(res.events[0].args.pool).to.equal(addr1.address);
      expect(res.events[0].args.to).to.equal(addr2.address);
      expect(res.events[0].args.protocolFee).to.equal(20000);
      expect(res.events[0].args.origMin).to.equal(30000);
      expect(res.events[0].args.origMax).to.equal(40000);
      expect(res.events[0].args.isSet).to.equal(true);

      const poolFee1 = await factory.getPoolFee(addr1.address);
      expect(poolFee1._to).to.equal(addr2.address);
      expect(poolFee1._protocolFee).to.equal(20000);
      expect(poolFee1._origMinFee).to.equal(30000);
      expect(poolFee1._origMaxFee).to.equal(40000);
      expect(poolFee1._isSet).to.equal(true);

      const res1 = await (
        await factory.setPoolFee(
          addr1.address,
          addr2.address,
          50000,
          60000,
          70000,
          false
        )
      ).wait();

      expect(res1.events[0].event).to.equal("FeeUpdate");
      expect(res1.events[0].args.pool).to.equal(addr1.address);
      expect(res1.events[0].args.to).to.equal(addr2.address);
      expect(res1.events[0].args.protocolFee).to.equal(50000);
      expect(res1.events[0].args.origMin).to.equal(60000);
      expect(res1.events[0].args.origMax).to.equal(70000);
      expect(res1.events[0].args.isSet).to.equal(false);

      const poolFee2 = await factory.getPoolFee(addr1.address);
      expect(poolFee2._to).to.equal(owner.address);
      expect(poolFee2._protocolFee).to.equal(10000);
      expect(poolFee2._origMinFee).to.equal(10000);
      expect(poolFee2._origMaxFee).to.equal(10000);
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
      ).to.be.revertedWith("ZeroAddress");

      await factory.connect(owner).setFeeToSetter(addr1.address);
      expect(await factory.feeToSetter()).to.equal(addr1.address);

      await expect(
        factory.connect(addr1).setFeeToSetter(addr2.address)
      ).to.be.revertedWith("Forbidden");

      await factory.connect(owner).setFeeToSetter(addr2.address);
      expect(await factory.feeToSetter()).to.equal(addr2.address);

      await expect(
        factory.connect(addr1).setFeeTo(ethers.constants.AddressZero)
      ).to.be.revertedWith("Forbidden");

      await expect(
        factory
          .connect(addr1)
          .setPoolFee(addr4.address, addr2.address, 20000, 30000, 40000, false)
      ).to.be.revertedWith("Forbidden");

      await factory.connect(addr2).setFeeTo(ethers.constants.AddressZero);
      expect(await factory.feeTo()).to.equal(ethers.constants.AddressZero);

      await (
        await factory
          .connect(addr2)
          .setPoolFee(addr4.address, addr3.address, 20000, 30000, 40000, true)
      ).wait();

      const poolFee = await factory.getPoolFee(addr4.address);
      expect(poolFee._to).to.equal(addr3.address);
      expect(poolFee._protocolFee).to.equal(20000);
      expect(poolFee._origMinFee).to.equal(30000);
      expect(poolFee._origMaxFee).to.equal(40000);
      expect(poolFee._isSet).to.equal(true);
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
});
