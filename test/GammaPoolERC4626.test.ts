import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;
const MIN_SHARES = 1000;

describe("GammaPoolERC4626", function () {
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
    GammaPool = await ethers.getContractFactory("TestGammaPool4626");
    [owner, addr1, addr2, addr3, addr4, addr5, addr6] =
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

    borrowStrategy = addr1;
    repayStrategy = addr5;
    rebalanceStrategy = addr6;
    liquidationStrategy = addr4;

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

  async function convertToShares(
    assets: BigNumber,
    supply: BigNumber,
    totalAssets: BigNumber
  ): Promise<BigNumber> {
    if (assets.eq(0)) {
      return ethers.constants.Zero;
    }
    if (supply.eq(0) || totalAssets.eq(0)) {
      return assets.sub(MIN_SHARES); // First deposit in GammaPool will require minting MIN_SHARES
    }
    return assets.mul(supply).div(totalAssets);
  }

  async function convertToAssets(
    shares: BigNumber,
    supply: BigNumber,
    totalAssets: BigNumber
  ): Promise<BigNumber> {
    if (shares.eq(0)) {
      return ethers.constants.Zero;
    }
    if (supply.eq(0)) {
      return shares.sub(MIN_SHARES); // First deposit in GammaPool will require minting MIN_SHARES
    }
    return shares.mul(totalAssets).div(supply);
  }

  // increase totalAssets by assets, increase totalSupply by shares
  async function updateBalances(assets: BigNumber, shares: BigNumber) {
    const _totalAssets = await gammaPool.totalAssets();
    if (assets.gt(0)) await cfmm.transfer(gammaPool.address, assets); // increase totalAssets of gammaPool

    await (await gammaPool.depositNoPull(ethers.constants.AddressZero)).wait();
    expect(await gammaPool.totalAssets()).to.be.equal(_totalAssets.add(assets));
    expect(await cfmm.balanceOf(gammaPool.address)).to.be.equal(
      _totalAssets.add(assets)
    );

    const _totalSupply = await gammaPool.totalSupply();

    if (shares.gt(0))
      await (await gammaPool.mint(shares, owner.address)).wait(); // increase totalSupply of gammaPool

    expect(await gammaPool.totalSupply()).to.be.equal(_totalSupply.add(shares));
  }

  async function testConvertToShares(
    assets: BigNumber,
    convert2Shares: Function,
    convert2Assets: Function
  ): Promise<BigNumber> {
    const totalSupply = await gammaPool.totalSupply();
    const totalAssets = await gammaPool.totalAssets();
    const convertedToShares = await convertToShares(
      assets,
      totalSupply,
      totalAssets
    );

    const _convertedToShares = await convert2Shares(assets);

    expect(_convertedToShares).to.be.equal(convertedToShares);
    expect(await convert2Assets(convertedToShares)).to.be.equal(
      await convertToAssets(convertedToShares, totalSupply, totalAssets)
    );

    return convertedToShares;
  }

  async function testConvertToAssets(
    shares: BigNumber,
    convert2Assets: Function,
    convert2Shares: Function
  ): Promise<BigNumber> {
    const totalSupply = await gammaPool.totalSupply();
    const totalAssets = await gammaPool.totalAssets();
    const convertedToAssets = await convertToAssets(
      shares,
      totalSupply,
      totalAssets
    );

    const _convertedToAssets = await convert2Assets(shares);

    expect(_convertedToAssets).to.be.equal(convertedToAssets);
    expect(await convert2Shares(convertedToAssets)).to.be.equal(
      await convertToShares(convertedToAssets, totalSupply, totalAssets)
    );

    return convertedToAssets;
  }

  describe("Deployment", function () {
    it("Check Init Params", async function () {
      expect(await gammaPool.asset()).to.equal(cfmm.address);
      expect(await gammaPool.asset()).to.equal(await gammaPool.cfmm());
    });
  });

  // You can nest describe calls to create subsections.
  describe("Short Gamma Functions", function () {
    it("ERC4626 Functions in GammaPool", async function () {
      const ONE = ethers.BigNumber.from(10).pow(18);
      await cfmm.transfer(gammaPool.address, ONE.mul(1000));
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
  });

  describe("Check Max Functions", function () {
    it("Check maxDeposit & maxMint, supply == 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply == 0, (assets == 0, shares == 0)
      expect(await gammaPool.totalSupply()).to.be.equal(0);
      expect(await gammaPool.maxDeposit(ethers.constants.AddressZero)).to.equal(
        ethers.constants.MaxUint256
      );
      expect(await gammaPool.maxMint(owner.address)).to.equal(
        ethers.constants.MaxUint256
      );

      // supply == 0, (assets > 0, shares == 0)
      const assets0 = ONE.mul(1000);
      const shares0 = ONE.mul(0);

      await updateBalances(assets0, shares0);

      expect(await gammaPool.maxDeposit(ethers.constants.AddressZero)).to.equal(
        ethers.constants.MaxUint256
      );
      expect(await gammaPool.maxMint(owner.address)).to.equal(
        ethers.constants.MaxUint256
      );
    });

    it("Check maxDeposit & maxMint, supply > 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply > 0, (assets == 0, shares > 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(1000);

      await updateBalances(assets0, shares0);

      expect(await gammaPool.totalSupply()).to.be.gt(0);
      expect(await gammaPool.maxDeposit(ethers.constants.AddressZero)).to.equal(
        0
      );
      expect(await gammaPool.maxMint(owner.address)).to.equal(
        ethers.constants.MaxUint256
      );

      // supply > 0, (assets > 0, shares > 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(200);

      await updateBalances(assets1, shares1);

      expect(await gammaPool.maxDeposit(ethers.constants.AddressZero)).to.equal(
        ethers.constants.MaxUint256
      );
      expect(await gammaPool.maxMint(owner.address)).to.equal(
        ethers.constants.MaxUint256
      );
    });

    it("Check maxWithdraw & maxRedeem, supply == 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply == 0, (assets == 0, shares == 0)
      const balanceOwner = await gammaPool.balanceOf(owner.address);

      expect(balanceOwner).to.be.equal(0);
      expect(await gammaPool.totalAssets()).to.be.equal(0);
      expect(await gammaPool.totalSupply()).to.be.equal(0);
      expect(await gammaPool.maxWithdraw(owner.address)).to.be.equal(
        await gammaPool.convertToAssets(balanceOwner)
      );
      expect(await gammaPool.maxRedeem(owner.address)).to.be.equal(
        balanceOwner
      );

      // supply == 0, (assets > 0, shares == 0)
      const assets0 = ONE.mul(1000);
      const shares0 = ONE.mul(0);
      await updateBalances(assets0, shares0);

      const balanceOwner0 = await gammaPool.balanceOf(owner.address);

      expect(balanceOwner0).to.be.eq(0);
      expect(await gammaPool.totalAssets()).to.be.gt(0);
      expect(await gammaPool.totalSupply()).to.be.equal(0);
      expect(await gammaPool.maxWithdraw(owner.address)).to.be.equal(
        await gammaPool.convertToAssets(balanceOwner0)
      );
      expect(await gammaPool.maxRedeem(owner.address)).to.be.equal(
        balanceOwner0
      );
    });

    it("Check maxWithdraw & maxRedeem, supply > 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply > 0, (assets == 0, shares > 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(1000);
      await updateBalances(assets0, shares0);

      const balanceOwner = await gammaPool.balanceOf(owner.address);
      expect(balanceOwner).to.be.gt(0);
      expect(await gammaPool.totalAssets()).to.be.equal(0);
      expect(await gammaPool.totalSupply()).to.be.gt(0);
      expect(await gammaPool.maxWithdraw(owner.address)).to.be.equal(
        await gammaPool.convertToAssets(balanceOwner)
      );
      expect(await gammaPool.maxRedeem(owner.address)).to.be.equal(0);

      // supply > 0, (assets > 0, shares > 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(100);
      await updateBalances(assets1, shares1);

      const balanceOwner0 = await gammaPool.balanceOf(owner.address);
      expect(balanceOwner0).to.be.gt(0);
      expect(await gammaPool.totalAssets()).to.be.gt(0);
      expect(await gammaPool.totalSupply()).to.be.gt(0);
      expect(await gammaPool.maxWithdraw(owner.address)).to.be.equal(
        await gammaPool.convertToAssets(balanceOwner0)
      );
      expect(await gammaPool.maxRedeem(owner.address)).to.be.equal(
        balanceOwner0
      );
    });
  });

  describe("Conversion Functions", function () {
    it("Check convertToShares & convertToAssets, supply == 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply == 0, (assets == 0, shares == 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(0);

      expect(
        await testConvertToShares(
          assets0,
          gammaPool.convertToShares,
          gammaPool.convertToAssets
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          gammaPool.convertToAssets,
          gammaPool.convertToShares
        )
      ).to.be.equal(shares0);

      // supply == 0, (assets > 0, shares == 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(0);

      await updateBalances(assets1, shares1);

      expect(
        await testConvertToShares(
          assets1,
          gammaPool.convertToShares,
          gammaPool.convertToAssets
        )
      ).to.be.equal(assets1.sub(MIN_SHARES));
      expect(
        await testConvertToAssets(
          shares1,
          gammaPool.convertToAssets,
          gammaPool.convertToShares
        )
      ).to.be.equal(shares1);
    });

    it("Check convertToShares & convertToAssets, supply > 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply > 0, (assets == 0, shares > 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(100);

      await updateBalances(assets0, shares0);

      expect(
        await testConvertToShares(
          assets0,
          gammaPool.convertToShares,
          gammaPool.convertToAssets
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          gammaPool.convertToAssets,
          gammaPool.convertToShares
        )
      ).to.be.equal(0);

      // supply > 0, (assets > 0, shares > 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(100);

      await updateBalances(assets1, shares1); // increase totalAssets by 1000, increase totalSupply by 100

      expect(
        await testConvertToShares(
          assets1,
          gammaPool.convertToShares,
          gammaPool.convertToAssets
        )
      ).to.not.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          gammaPool.convertToAssets,
          gammaPool.convertToShares
        )
      ).to.not.equal(shares1);

      // supply > 0, (assets > 0, shares > 0)
      const assets2 = ONE.mul(3000);
      const shares2 = ONE.mul(200);

      await updateBalances(assets2, shares2); // increase totalAssets by 3000, increase totalSupply by 200

      expect(
        await testConvertToShares(
          assets2,
          gammaPool.convertToShares,
          gammaPool.convertToAssets
        )
      ).to.not.equal(assets2);
      expect(
        await testConvertToAssets(
          shares2,
          gammaPool.convertToAssets,
          gammaPool.convertToShares
        )
      ).to.not.equal(shares2);
    });
  });

  describe("Preview Functions", function () {
    it("Check previewDeposit & previewMint, supply == 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply == 0, (assets == 0, shares == 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(0);

      expect(
        await testConvertToShares(
          assets0,
          gammaPool.previewDeposit,
          gammaPool.previewMint
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          gammaPool.previewMint,
          gammaPool.previewDeposit
        )
      ).to.be.equal(shares0);

      // supply == 0, (assets > 0, shares == 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(0);

      await updateBalances(assets1, shares1);

      expect(
        await testConvertToShares(
          assets1,
          gammaPool.previewMint,
          gammaPool.convertToAssets
        )
      ).to.be.equal(assets1.sub(MIN_SHARES));
      expect(
        await testConvertToAssets(
          shares1,
          gammaPool.convertToAssets,
          gammaPool.previewMint
        )
      ).to.be.equal(shares1);
    });

    it("Check previewDeposit & previewMint, supply > 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply > 0, (assets == 0, shares > 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(100);

      await updateBalances(assets0, shares0);

      expect(
        await testConvertToShares(
          assets0,
          gammaPool.previewDeposit,
          gammaPool.previewMint
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          gammaPool.previewMint,
          gammaPool.previewDeposit
        )
      ).to.be.equal(0);

      // supply > 0, (assets > 0, shares > 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(100);

      await updateBalances(assets1, shares1); // increase totalAssets by 1000, increase totalSupply by 100

      expect(
        await testConvertToShares(
          assets1,
          gammaPool.previewDeposit,
          gammaPool.previewMint
        )
      ).to.not.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          gammaPool.previewMint,
          gammaPool.previewDeposit
        )
      ).to.not.equal(shares1);

      // supply > 0, (assets > 0, shares > 0)
      const assets2 = ONE.mul(4000);
      const shares2 = ONE.mul(500);

      await updateBalances(assets2, shares2); // increase totalAssets by 4000, increase totalSupply by 500

      expect(
        await testConvertToShares(
          assets2,
          gammaPool.previewDeposit,
          gammaPool.previewMint
        )
      ).to.not.equal(assets2);
      expect(
        await testConvertToAssets(
          shares2,
          gammaPool.previewMint,
          gammaPool.previewDeposit
        )
      ).to.not.equal(shares2);
    });

    it("Check previewWithdraw and previewRedeem, supply == 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply == 0, (assets == 0, shares == 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(0);

      expect(
        await testConvertToShares(
          assets0,
          gammaPool.previewWithdraw,
          gammaPool.previewRedeem
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          gammaPool.previewRedeem,
          gammaPool.previewWithdraw
        )
      ).to.be.equal(shares0);

      // supply == 0, (assets > 0, shares == 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(0);

      await updateBalances(assets1, shares1);

      expect(
        await testConvertToShares(
          assets1,
          gammaPool.previewWithdraw,
          gammaPool.previewRedeem
        )
      ).to.be.equal(assets1.sub(MIN_SHARES));
      expect(
        await testConvertToAssets(
          shares1,
          gammaPool.previewRedeem,
          gammaPool.previewWithdraw
        )
      ).to.be.equal(shares1);
    });

    it("Check previewWithdraw and previewRedeem, supply > 0", async function () {
      const ONE = BigNumber.from(10).pow(18);

      // supply > 0, (assets == 0, shares > 0)
      const assets0 = ONE.mul(0);
      const shares0 = ONE.mul(100);

      await updateBalances(assets0, shares0);

      expect(
        await testConvertToShares(
          assets0,
          gammaPool.previewWithdraw,
          gammaPool.previewRedeem
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          gammaPool.previewRedeem,
          gammaPool.previewWithdraw
        )
      ).to.be.equal(0);

      // supply > 0, (assets > 0, shares > 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(10000);

      await updateBalances(assets1, shares1); // increase totalAssets by 1000, increase totalSupply by 10000

      expect(
        await testConvertToShares(
          assets1,
          gammaPool.previewWithdraw,
          gammaPool.previewRedeem
        )
      ).to.not.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          gammaPool.previewRedeem,
          gammaPool.previewWithdraw
        )
      ).to.not.equal(shares1);

      // supply > 0, (assets > 0, shares > 0)
      const assets2 = ONE.mul(300);
      const shares2 = ONE.mul(2000);

      await updateBalances(assets2, shares2); // increase totalAssets by 1000, increase totalSupply by 2000

      expect(
        await testConvertToShares(
          assets2,
          gammaPool.previewWithdraw,
          gammaPool.previewRedeem
        )
      ).to.not.equal(assets2);
      expect(
        await testConvertToAssets(
          shares2,
          gammaPool.previewRedeem,
          gammaPool.previewWithdraw
        )
      ).to.not.equal(shares2);
    });
  });
});
