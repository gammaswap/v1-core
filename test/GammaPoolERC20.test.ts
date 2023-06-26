import { ethers } from "hardhat";
import { expect } from "chai";

const PROTOCOL_ID = 1;

describe("GammaPoolERC20", function () {
  let TestERC20: any;
  let TestAddressCalculator: any;
  let TestShortStrategy: any;
  let GammaPool: any;
  let PoolViewer: any;
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
  let addr4: any;
  let addr5: any;
  let addr6: any;
  let addr7: any;
  let addr8: any;
  let addr9: any;
  let borrowStrategy: any;
  let repayStrategy: any;
  let rebalanceStrategy: any;
  let shortStrategy: any;
  let liquidationStrategy: any;
  let gammaPool: any;
  let poolViewer: any;
  let implementation: any;

  beforeEach(async function () {
    // instantiate a GammaPool
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestAddressCalculator = await ethers.getContractFactory(
      "TestAddressCalculator"
    );
    TestGammaPoolFactory = await ethers.getContractFactory(
      "TestGammaPoolFactory"
    );
    PoolViewer = await ethers.getContractFactory("PoolViewer");
    GammaPool = await ethers.getContractFactory("TestGammaPool");
    [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9] =
      await ethers.getSigners();

    TestShortStrategy = await ethers.getContractFactory("TestERC20Strategy");

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    cfmm = await TestERC20.deploy("Test CFMM", "CFMM");
    shortStrategy = await TestShortStrategy.deploy(cfmm.address);
    addressCalculator = await TestAddressCalculator.deploy();
    poolViewer = await PoolViewer.deploy();

    factory = await TestGammaPoolFactory.deploy(cfmm.address, PROTOCOL_ID, [
      tokenA.address,
      tokenB.address,
    ]);

    borrowStrategy = addr6;
    repayStrategy = addr7;
    rebalanceStrategy = addr8;
    liquidationStrategy = addr9;

    implementation = await GammaPool.deploy(
      PROTOCOL_ID,
      factory.address,
      borrowStrategy.address,
      repayStrategy.address,
      rebalanceStrategy.address,
      shortStrategy.address,
      liquidationStrategy.address,
      liquidationStrategy.address,
      poolViewer.address
    );

    await factory.addProtocol(implementation.address);
    await deployGammaPool();
  });

  async function deployGammaPool() {
    const data = ethers.utils.defaultAbiCoder.encode([], []);
    await (await factory.createPool2(data)).wait();

    const key = await addressCalculator.getGammaPoolKey(
      cfmm.address,
      PROTOCOL_ID
    );
    const pool = await factory.getPool(key);

    gammaPool = await GammaPool.attach(
      pool // The deployed contract address
    );
  }

  describe("Deployment", function () {
    it("Check Init Params", async function () {
      expect(gammaPool.address).to.not.equal(ethers.constants.AddressZero);
      expect(await gammaPool.name()).to.equal("GammaSwap V1");
      expect(await gammaPool.symbol()).to.equal("GS-V1");
      expect(await gammaPool.viewer()).to.equal(poolViewer.address);
      expect(await gammaPool.decimals()).to.equal(18);
      expect(await gammaPool.totalSupply()).to.equal(0);
      expect(await gammaPool.balanceOf(owner.address)).to.equal(0);
      expect(await gammaPool.allowance(addr1.address, owner.address)).to.equal(
        0
      );
    });
  });

  describe("Check Write Functions", function () {
    it("Check Deployed Pool", async function () {
      expect(gammaPool.address).to.not.equal(ethers.constants.AddressZero);
    });

    it("Check Balance Minted", async function () {
      const _totalSupply = await gammaPool.totalSupply();
      const _balance = await gammaPool.balanceOf(addr1.address);
      const amt = 1000;
      const res0 = await (await gammaPool.mint(amt, addr1.address)).wait();
      expect(res0.events[1].args.from).to.eq(ethers.constants.AddressZero);
      expect(res0.events[1].args.to).to.eq(addr1.address);
      expect(res0.events[1].args.amount).to.eq(amt);
      expect(await gammaPool.balanceOf(addr1.address)).to.equal(
        _balance.add(amt)
      );
      expect(await gammaPool.totalSupply()).to.equal(_totalSupply.add(amt));
    });

    it("Check Balance Transfer", async function () {
      await (await gammaPool.mint(1000, owner.address)).wait(); // minted 1000 to owner
      const _totalSupply = await gammaPool.totalSupply();
      const _balanceOwner = await gammaPool.balanceOf(owner.address); // get current owner balance
      const _balanceAddr2 = await gammaPool.balanceOf(addr2.address); // get current addr2 balance
      const amt = 100;
      const res0 = await (await gammaPool.transfer(addr2.address, amt)).wait();
      expect(res0.events[0].args.from).to.eq(owner.address);
      expect(res0.events[0].args.to).to.eq(addr2.address);
      expect(res0.events[0].args.amount).to.eq(amt);
      expect(await gammaPool.balanceOf(owner.address)).to.equal(
        _balanceOwner.sub(amt)
      );
      expect(await gammaPool.balanceOf(addr2.address)).to.equal(
        _balanceAddr2.add(amt)
      );
      expect(await gammaPool.totalSupply()).to.equal(_totalSupply);
    });

    it("Check Balance Transfer Fail", async function () {
      await (await gammaPool.mint(1000, owner.address)).wait(); // minted 1000 to owner
      const _balanceOwner = await gammaPool.balanceOf(owner.address); // get current owner balance
      const amt = _balanceOwner.add(1);
      await expect(
        gammaPool.transfer(addr3.address, amt)
      ).to.be.revertedWithCustomError(gammaPool, "ERC20Transfer"); // Failure to Transfer
    });

    it("Check Balance Approval", async function () {
      const _totalSupply = await gammaPool.totalSupply();
      const allowanceOwnerToAddr3 = await gammaPool.allowance(
        owner.address,
        addr3.address
      );
      const allowanceAddr3ToOwner = await gammaPool.allowance(
        addr3.address,
        owner.address
      );
      const amt = allowanceOwnerToAddr3.add(100);
      const res0 = await (await gammaPool.approve(addr3.address, amt)).wait();
      expect(res0.events[0].args.owner).to.eq(owner.address);
      expect(res0.events[0].args.spender).to.eq(addr3.address);
      expect(res0.events[0].args.amount).to.eq(amt);
      expect(await gammaPool.allowance(owner.address, addr3.address)).to.equal(
        amt
      );
      expect(await gammaPool.allowance(addr3.address, owner.address)).to.equal(
        allowanceAddr3ToOwner
      );
      expect(await gammaPool.totalSupply()).to.eq(_totalSupply);
    });

    it("Check Balance TransferFrom Fail Approval", async function () {
      await (await gammaPool.mint(1000, owner.address)).wait(); // minted 1000 to owner
      await (await gammaPool.mint(1000, addr2.address)).wait(); // minted 1000 to owner
      await (await gammaPool.mint(1000, addr3.address)).wait(); // minted 1000 to owner

      const _balanceAddr3 = await gammaPool.balanceOf(addr3.address); // get current addr2 balance
      await gammaPool
        .connect(addr3)
        .approve(owner.address, _balanceAddr3.sub(100)); // owner = addr3, spender = owner

      const allowanceAddr3ToOwner0 = await gammaPool.allowance(
        addr3.address,
        owner.address
      ); // owner = addr3, spender = owner

      const amt = ethers.BigNumber.from(allowanceAddr3ToOwner0).add(1);

      await expect(
        gammaPool.transferFrom(addr3.address, addr2.address, amt) // tried to transfer more than was approved
      ).to.be.revertedWithCustomError(gammaPool, "ERC20Allowance"); // Failure to Transfer
    });

    it("Check Balance TransferFrom", async function () {
      await (await gammaPool.mint(1000, owner.address)).wait(); // minted 1000 to owner
      await (await gammaPool.mint(1000, addr4.address)).wait(); // minted 1000 to owner
      await (await gammaPool.mint(1000, addr5.address)).wait(); // minted 1000 to owner
      const _totalSupply = await gammaPool.totalSupply();
      const _balanceOwner = await gammaPool.balanceOf(owner.address); // get current owner balance
      const _balanceAddr4 = await gammaPool.balanceOf(addr4.address); // get current addr2 balance
      const _balanceAddr5 = await gammaPool.balanceOf(addr5.address); // get current addr3 balance
      const allowanceOwnerToAddr4 = await gammaPool.allowance(
        owner.address,
        addr4.address
      ); // owner = addr3, spender = owner
      const allowanceAddr4ToOwner0 = await gammaPool.allowance(
        addr4.address,
        owner.address
      ); // owner = addr3, spender = owner
      const amt = ethers.BigNumber.from(allowanceAddr4ToOwner0).add(100);

      await gammaPool.connect(addr4).approve(owner.address, amt); // owner = addr3, spender = owner

      const res0 = await (
        await gammaPool.transferFrom(addr4.address, addr5.address, amt.sub(50))
      ).wait();
      // event Transfer(address indexed from, address indexed to, uint256 value);
      expect(res0.events[0].args.from).to.eq(addr4.address);
      expect(res0.events[0].args.to).to.eq(addr5.address);
      expect(res0.events[0].args.amount).to.eq(amt.sub(50));

      expect(await gammaPool.totalSupply()).to.eq(_totalSupply);
      expect(await gammaPool.balanceOf(owner.address)).to.eq(_balanceOwner);
      expect(await gammaPool.allowance(owner.address, addr4.address)).to.eq(
        allowanceOwnerToAddr4
      );
      expect(await gammaPool.balanceOf(addr4.address)).to.eq(
        _balanceAddr4.sub(amt.sub(50))
      );
      expect(await gammaPool.balanceOf(addr5.address)).to.eq(
        _balanceAddr5.add(amt.sub(50))
      );

      expect(await gammaPool.allowance(addr4.address, owner.address)).to.eq(
        amt.sub(50)
      );
    });

    it("Check Balance TransferFrom Fail Amount", async function () {
      await (await gammaPool.mint(1000, addr3.address)).wait(); // minted 1000 to owner
      const _balanceAddr3 = await gammaPool.balanceOf(addr3.address); // get current addr3 balance

      await gammaPool
        .connect(addr3)
        .approve(owner.address, _balanceAddr3.add(100)); // owner = addr3, spender = owner

      await expect(
        gammaPool.transferFrom(
          addr3.address,
          addr2.address,
          _balanceAddr3.add(1)
        )
      ).to.be.revertedWithCustomError(gammaPool, "ERC20Transfer"); // Failure to Transfer
    });

    it("Check Balance TransferFrom Max Fail Amount", async function () {
      await (await gammaPool.mint(1000, addr3.address)).wait(); // minted 1000 to owner
      const _balanceAddr3 = await gammaPool.balanceOf(addr3.address); // get current addr3 balance

      await gammaPool
        .connect(addr3)
        .approve(owner.address, ethers.constants.MaxUint256); // owner = addr3, spender = owner

      await expect(
        gammaPool.transferFrom(
          addr3.address,
          addr2.address,
          _balanceAddr3.add(1)
        )
      ).to.be.revertedWithCustomError(gammaPool, "ERC20Transfer"); // Failure to Transfer
    });

    it("Check Balance TransferFrom Max", async function () {
      await (await gammaPool.mint(1000, owner.address)).wait(); // minted 1000 to owner
      await (await gammaPool.mint(1000, addr4.address)).wait(); // minted 1000 to owner
      await (await gammaPool.mint(1000, addr5.address)).wait(); // minted 1000 to owner
      const _totalSupply = await gammaPool.totalSupply();
      const _balanceOwner = await gammaPool.balanceOf(owner.address); // get current owner balance
      const _balanceAddr4 = await gammaPool.balanceOf(addr4.address); // get current addr2 balance
      const _balanceAddr5 = await gammaPool.balanceOf(addr5.address); // get current addr3 balance
      const allowanceOwnerToAddr4 = await gammaPool.allowance(
        owner.address,
        addr4.address
      ); // owner = addr3, spender = owner
      const allowanceAddr4ToOwner0 = await gammaPool.allowance(
        addr4.address,
        owner.address
      ); // owner = addr3, spender = owner
      const amt = ethers.BigNumber.from(allowanceAddr4ToOwner0).add(100);

      await gammaPool
        .connect(addr4)
        .approve(owner.address, ethers.constants.MaxUint256); // owner = addr3, spender = owner

      const res0 = await (
        await gammaPool.transferFrom(addr4.address, addr5.address, amt.sub(50))
      ).wait();
      // event Transfer(address indexed from, address indexed to, uint256 value);
      expect(res0.events[0].args.from).to.eq(addr4.address);
      expect(res0.events[0].args.to).to.eq(addr5.address);
      expect(res0.events[0].args.amount).to.eq(amt.sub(50));

      expect(await gammaPool.totalSupply()).to.eq(_totalSupply);
      expect(await gammaPool.balanceOf(owner.address)).to.eq(_balanceOwner);
      expect(await gammaPool.allowance(owner.address, addr4.address)).to.eq(
        allowanceOwnerToAddr4
      );
      expect(await gammaPool.balanceOf(addr4.address)).to.eq(
        _balanceAddr4.sub(amt.sub(50))
      );
      expect(await gammaPool.balanceOf(addr5.address)).to.eq(
        _balanceAddr5.add(amt.sub(50))
      );

      expect(await gammaPool.allowance(addr4.address, owner.address)).to.eq(
        ethers.constants.MaxUint256
      );
    });
  });
});
