import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

const PROTOCOL_ID = 1;

describe("GammaPoolERC4626", function () {
  let TestERC20: any;
  let TestAddressCalculator: any;
  let TestAbstractProtocol: any;
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
  let addr4: any;
  let addr5: any;
  let addr6: any;
  let longStrategy: any;
  let shortStrategy: any;
  let gammaPool: any;
  let protocol: any;

  beforeEach(async function () {
    // instantiate a GammaPool
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
    GammaPool = await ethers.getContractFactory("GammaPool");
    [owner, addr1, addr2, addr3, addr4, addr5, addr6] =
      await ethers.getSigners();

    TestShortStrategy = await ethers.getContractFactory("TestERC20Strategy");

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");
    cfmm = await TestERC20.deploy("Test CFMM", "CFMM");
    shortStrategy = await TestShortStrategy.deploy();
    addressCalculator = await TestAddressCalculator.deploy();

    factory = await TestGammaPoolFactory.deploy(
      cfmm.address,
      PROTOCOL_ID,
      [tokenA.address, tokenB.address],
      ethers.constants.AddressZero
    );

    longStrategy = addr6;
    protocol = await TestAbstractProtocol.deploy(
      factory.address,
      PROTOCOL_ID,
      longStrategy.address,
      shortStrategy.address,
      2,
      3
    );

    await factory.setProtocol(protocol.address);
  });

  async function deployGammaPool() {
    await (await factory.createPool()).wait();

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
      await deployGammaPool();
      expect(await gammaPool.asset()).to.equal(cfmm.address);
      expect(await gammaPool.maxDeposit(owner.address)).to.equal(
        ethers.constants.MaxUint256
      );
      expect(await gammaPool.maxMint(owner.address)).to.equal(
        ethers.constants.MaxUint256
      );
    });
  });

  async function convertToShares(
    assets: BigNumber,
    supply: BigNumber,
    totalAssets: BigNumber
  ): Promise<BigNumber> {
    return supply.eq(0) ? assets : assets.mul(supply).div(totalAssets);
  }

  async function convertToAssets(
    shares: BigNumber,
    supply: BigNumber,
    totalAssets: BigNumber
  ): Promise<BigNumber> {
    return supply.eq(0) ? shares : shares.mul(totalAssets).div(supply);
  }

  /**
   function convertToAssets(uint256 shares) public view virtual returns (uint256) {
      uint256 supply = GammaPoolStorage.store().totalSupply;

      return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }/**/
  async function updateBalances(assets: BigNumber, shares: BigNumber) {
    await cfmm.transfer(gammaPool.address, assets);
    expect(await gammaPool.totalAssets()).to.be.equal(
      await cfmm.balanceOf(gammaPool.address)
    );
    const _totalSupply = await gammaPool.totalSupply();
    await (await gammaPool.mint(shares, owner.address)).wait(); // minted 1000 to owner
    await (await gammaPool.mint(shares.mul(2), addr1.address)).wait(); // minted 1000 to owner
    expect(await gammaPool.totalSupply()).to.be.equal(
      _totalSupply.add(shares).add(shares.mul(2))
    );
  }

  async function testConvertToShares(assets: BigNumber): Promise<BigNumber> {
    const totalSupply = await gammaPool.totalSupply();
    const totalAssets = await gammaPool.totalAssets();
    const convertedShares = await convertToShares(
      assets,
      totalSupply,
      totalAssets
    );
    console.log("convertedShares >>");
    console.log(convertedShares);

    const _convertedShares = await gammaPool.convertToShares(assets);
    console.log("_convertedShares >>");
    console.log(_convertedShares);

    expect(await gammaPool.convertToShares(assets)).to.be.equal(
      convertedShares
    );
    return convertedShares;
  }

  async function testConvertToAssets(shares: BigNumber): Promise<BigNumber> {
    const totalSupply = await gammaPool.totalSupply();
    const totalAssets = await gammaPool.totalAssets();
    const convertedAssets = await convertToAssets(
      shares,
      totalSupply,
      totalAssets
    );
    console.log("convertedAssets >>");
    console.log(convertedAssets);

    const _convertedToAssets = await gammaPool.convertToAssets(shares);
    console.log("_convertedToAssets >>");
    console.log(_convertedToAssets);

    expect(await gammaPool.convertToAssets(shares)).to.be.equal(
      convertedAssets
    );
    return convertedAssets;
  }

  describe("View Functions", function () {
    it("Check Max Redeem", async function () {
      await deployGammaPool();
      const balanceOwner = await gammaPool.balanceOf(owner.address);
      const balanceAddr1 = await gammaPool.balanceOf(addr1.address);
      await (await gammaPool.mint(1000, owner.address)).wait(); // minted 1000 to owner
      await (await gammaPool.mint(2000, addr1.address)).wait(); // minted 1000 to owner
      expect(await gammaPool.maxRedeem(owner.address)).to.equal(
        balanceOwner.add(1000)
      );
      expect(await gammaPool.maxRedeem(addr1.address)).to.equal(
        balanceAddr1.add(2000)
      );
      expect(await gammaPool.maxRedeem(addr1.address)).to.not.equal(
        balanceAddr1.add(3000)
      );
    });

    it("Check Total Assets & Total Supply", async function () {
      await deployGammaPool();
      const ONE = BigNumber.from(10).pow(18);

      console.log("totalSupply >>");
      console.log(await gammaPool.totalSupply());

      const assets = ONE.mul(1000);
      const shares = ONE.mul(100);

      expect(await testConvertToShares(assets)).to.be.equal(assets);
      expect(await testConvertToAssets(shares)).to.be.equal(shares);

      await updateBalances(assets, shares);

      console.log("totalSupply2 >>");
      console.log(await gammaPool.totalSupply());

      expect(await testConvertToShares(assets)).to.not.equal(assets);
      expect(await testConvertToAssets(shares)).to.not.equal(shares);

      const _shares = shares.mul(2);
      await updateBalances(assets, _shares);
      expect(await testConvertToShares(assets)).to.not.equal(assets);
      expect(await testConvertToAssets(shares)).to.not.equal(shares);
    });

  });
  /*

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply;

        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = GammaPoolStorage.store().totalSupply;

        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(GammaPoolStorage.store().balanceOf[owner]);
    }






    describe("Check Write Functions", function () {

        it("Check Deployed Pool", async function () {
            await deployGammaPool();
            expect(gammaPool.address).to.not.equal(ethers.constants.AddressZero);
        });

        it("Check Balance Minted", async function () {
            const _totalSupply = await gammaPool.totalSupply();
            const _balance = await gammaPool.balanceOf(addr1.address);
            const amt = 1000;
            const res0 = await (await gammaPool.mint(amt, addr1.address)).wait();
            expect(res0.events[0].args.from).to.eq(ethers.constants.AddressZero);
            expect(res0.events[0].args.to).to.eq(addr1.address);
            expect(res0.events[0].args.value).to.eq(amt);
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
            expect(res0.events[0].args.value).to.eq(amt);
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
            await expect(gammaPool.transfer(addr3.address, amt)).to.be.revertedWith(
                "ERC20: bal < val"
            ); // Failure to Transfer
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
            expect(res0.events[0].args.value).to.eq(amt);
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
            ).to.be.revertedWith(""); // Failure to Transfer
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
            expect(res0.events[0].args.value).to.eq(amt.sub(50));

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
            ).to.be.revertedWith("ERC20: bal < val"); // Failure to Transfer
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
            ).to.be.revertedWith("ERC20: bal < val"); // Failure to Transfer
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
            expect(res0.events[0].args.value).to.eq(amt.sub(50));

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
    });/**/
});
