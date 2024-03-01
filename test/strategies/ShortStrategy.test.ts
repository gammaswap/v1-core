import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { Address } from "cluster";

const PROTOCOL_ID = 1;

describe("ShortStrategy", function () {
  let TestERC20: any;
  let TestCFMM: any;
  let TestStrategy: any;
  let TestPositionManager: any;
  let TestRateParamsStore: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let strategy: any;
  let posManager: any;
  let paramsStore: any;
  let owner: any;
  let addr1: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestCFMM = await ethers.getContractFactory("TestCFMM");
    TestStrategy = await ethers.getContractFactory("TestShortStrategy");
    TestRateParamsStore = await ethers.getContractFactory(
      "TestRateParamsStore"
    );
    TestPositionManager = await ethers.getContractFactory(
      "TestPositionManager"
    );
    [owner, addr1] = await ethers.getSigners();

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    cfmm = await TestCFMM.deploy(
      tokenA.address,
      tokenB.address,
      "Test CFMM",
      "TCFMM"
    );

    paramsStore = await TestRateParamsStore.deploy(owner.address);
    strategy = await TestStrategy.deploy();
    await (
      await strategy.initialize(
        cfmm.address,
        [tokenA.address, tokenB.address],
        [18, 18]
      )
    ).wait();

    posManager = await TestPositionManager.deploy(
      strategy.address,
      cfmm.address,
      PROTOCOL_ID
    );
  });

  async function convertToShares(
    assets: BigNumber,
    supply: BigNumber,
    totalAssets: BigNumber
  ): Promise<BigNumber> {
    return supply.eq(0) || totalAssets.eq(0)
      ? assets
      : assets.mul(supply).div(totalAssets);
  }

  async function convertToAssets(
    shares: BigNumber,
    supply: BigNumber,
    totalAssets: BigNumber
  ): Promise<BigNumber> {
    return supply.eq(0) ? shares : shares.mul(totalAssets).div(supply);
  }

  // increase totalAssets by assets, increase totalSupply by shares
  async function updateBalances(assets: BigNumber, shares: BigNumber) {
    const _totalAssets = await strategy.getTotalAssets();
    if (assets.gt(0))
      await (await strategy.setTotalAssets(_totalAssets.add(assets))).wait(); // increase totalAssets of gammaPool

    expect(await strategy.getTotalAssets()).to.be.equal(
      _totalAssets.add(assets)
    );

    const _totalSupply = await strategy.totalSupply0();

    if (shares.gt(0))
      await (await strategy.setTotalSupply(_totalSupply.add(shares))).wait(); // increase totalSupply of gammaPool

    expect(await strategy.totalSupply0()).to.be.equal(_totalSupply.add(shares));
  }

  async function testConvertToShares(
    assets: BigNumber,
    convert2Shares: Function,
    convert2Assets: Function
  ): Promise<BigNumber> {
    const totalSupply = await strategy.totalSupply0();
    const totalAssets = await strategy.getTotalAssets();
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
    const totalSupply = await strategy.totalSupply0();
    const totalAssets = await strategy.getTotalAssets();
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

  async function execFirstUpdateIndex(
    lpTokens: BigNumber,
    addInvariaint: BigNumber
  ) {
    await (await cfmm.mint(lpTokens, owner.address)).wait();
    await (await cfmm.transfer(strategy.address, lpTokens.div(2))).wait();

    await (await strategy.depositLPTokens(owner.address)).wait();

    await (await cfmm.trade(addInvariaint)).wait();
    await (await strategy.testUpdateIndex()).wait();
  }

  async function borrowLPTokens(lpTokens: BigNumber) {
    await (await strategy.borrowLPTokens(lpTokens)).wait();
    await (await strategy.testUpdateIndex()).wait();
  }

  async function checkGSPoolIsEmpty(
    cfmmTotalSupply: BigNumber,
    cfmmTotalInvariant: BigNumber
  ) {
    expect(await strategy.getTotalAssets()).to.equal(0);
    expect(await strategy.totalSupply0()).to.equal(0);
    const params = await strategy.getTotalAssetsParams();
    expect(params.borrowedInvariant).to.equal(0);
    expect(params.lpBalance).to.equal(0);
    expect(params.lpBorrowed).to.equal(0);
    expect(params.lpTokenTotal).to.equal(0);
    expect(params.lpTokenBorrowedPlusInterest).to.equal(0);
    expect(params.prevCFMMInvariant).to.equal(cfmmTotalInvariant);
    expect(params.prevCFMMTotalSupply).to.equal(cfmmTotalSupply);
  }

  async function checkWithdrawal(
    ownerAddr: Address,
    receiverAddr: Address,
    expTotalSupply: BigNumber,
    expOwnerBalance: BigNumber,
    expReceiverBalance: BigNumber,
    expTotalCFMMSupply: BigNumber,
    expStrategyCFMMSupply: BigNumber,
    expOwnerCFMMBalance: BigNumber,
    expReceiverCFMMBalance: BigNumber
  ) {
    const totalSupply = await strategy.totalSupply0();
    expect(totalSupply).to.equal(expTotalSupply);

    const ownerBalance = await strategy.balanceOf(ownerAddr);
    expect(ownerBalance).to.equal(expOwnerBalance);

    const receiverBalance = await strategy.balanceOf(receiverAddr);
    expect(receiverBalance).to.equal(expReceiverBalance);

    const totalCFMMSupply = await cfmm.totalSupply();
    expect(totalCFMMSupply).to.equal(expTotalCFMMSupply);

    const strategyCFMMBalance = await cfmm.balanceOf(strategy.address);
    expect(strategyCFMMBalance).to.equal(expStrategyCFMMSupply);

    const ownerCFMMBalance = await cfmm.balanceOf(ownerAddr);
    expect(ownerCFMMBalance).to.equal(expOwnerCFMMBalance);

    const receiverCFMMBalance = await cfmm.balanceOf(receiverAddr);
    expect(receiverCFMMBalance).to.equal(expReceiverCFMMBalance);

    const resp = await strategy.getLPTokenBalAndBorrowedInv();
    expect(resp.lpTokenBal).to.equal(strategyCFMMBalance);
  }

  async function prepareAssetsToWithdraw(assets: BigNumber, to: any) {
    await (await cfmm.mint(assets, to.address)).wait();
    await (await cfmm.connect(to).transfer(strategy.address, assets)).wait();
    await (await strategy.depositLPTokens(to.address)).wait();
  }

  async function withdrawNoPull(shares: BigNumber, to: Address, from: Address) {
    await (await strategy._withdrawNoPull(to)).wait();
  }

  async function withdrawReserves(
    shares: BigNumber,
    to: Address,
    from: Address
  ) {
    await (await strategy._withdrawReserves(to)).wait();
  }

  async function testERC4626Withdraw(
    from: Address,
    to: Address,
    assets: BigNumber,
    shares: BigNumber,
    ownerAssetChange: BigNumber,
    receiverAssetChange: BigNumber,
    ownerShareChange: BigNumber,
    receiverShareChange: BigNumber,
    cfmmSupplyChange: BigNumber,
    erc4626WithdrawFunc: Function
  ) {
    const resp = await strategy.getLPTokenBalAndBorrowedInv();

    const totalSupply = await strategy.totalSupply0();
    const ownerBalance = await strategy.balanceOf(from);
    const receiverBalance = await strategy.balanceOf(to);
    const totalCFMMSupply = await cfmm.totalSupply();
    const strategyCFMMBalance = await cfmm.balanceOf(strategy.address);
    const ownerCFMMBalance = await cfmm.balanceOf(from);
    const receiverCFMMBalance = await cfmm.balanceOf(to);

    expect(resp.lpTokenBal).to.equal(strategyCFMMBalance);

    const receiverAddr = to;
    const ownerAddr = from;

    await erc4626WithdrawFunc(assets, receiverAddr, ownerAddr);

    await checkWithdrawal(
      from,
      to,
      totalSupply.sub(shares),
      ownerBalance.sub(ownerShareChange),
      receiverBalance.sub(receiverShareChange),
      totalCFMMSupply.sub(cfmmSupplyChange),
      strategyCFMMBalance.sub(assets),
      ownerCFMMBalance.add(ownerAssetChange),
      receiverCFMMBalance.add(receiverAssetChange)
    );
  }

  async function testWithdraw(
    from: Address,
    to: Address,
    assets: BigNumber,
    shares: BigNumber,
    ownerAssetChange: BigNumber,
    receiverAssetChange: BigNumber,
    ownerShareChange: BigNumber,
    receiverShareChange: BigNumber,
    cfmmSupplyChange: BigNumber,
    withdrawFunc: Function
  ) {
    const strategyBalance = await strategy.balanceOf(strategy.address);

    await testERC4626Withdraw(
      from,
      to,
      assets,
      shares,
      ownerAssetChange,
      receiverAssetChange,
      ownerShareChange,
      receiverShareChange,
      cfmmSupplyChange,
      withdrawFunc
    );

    expect(await strategy.balanceOf(strategy.address)).to.equal(
      strategyBalance.sub(shares)
    );
  }

  async function testWithdrawReserves(
    from: Address,
    to: Address,
    assets: BigNumber,
    shares: BigNumber,
    ownerAssetChange: BigNumber,
    receiverAssetChange: BigNumber,
    ownerShareChange: BigNumber,
    receiverShareChange: BigNumber,
    receiverToken0Change: BigNumber,
    receiverToken1Change: BigNumber,
    withdrawFunc: Function
  ) {
    const token0Balance = await tokenA.balanceOf(to);
    const token1Balance = await tokenB.balanceOf(to);

    await testWithdraw(
      from,
      to,
      assets,
      shares,
      ownerAssetChange,
      receiverAssetChange,
      ownerShareChange,
      receiverShareChange,
      assets,
      withdrawFunc
    );

    expect(await tokenA.balanceOf(to)).to.equal(
      token0Balance.add(receiverToken0Change)
    );
    expect(await tokenB.balanceOf(to)).to.equal(
      token1Balance.add(receiverToken1Change)
    );
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Check Init Params", async function () {
      const ONE = BigNumber.from(10).pow(18);
      const assets = ONE.mul(100);
      const _totalAssets = await strategy.getTotalAssets();
      await (await strategy.setTotalAssets(_totalAssets.add(assets))).wait(); // increase totalAssets of gammaPool
      expect(await strategy.getTotalAssets()).to.equal(
        _totalAssets.add(assets)
      );

      const shares = ONE.mul(100);
      const _totalSupply = await strategy.totalSupply0();
      await (await strategy.setTotalSupply(_totalSupply.add(shares))).wait(); // increase totalSupply of gammaPool
      expect(await strategy.totalSupply0()).to.equal(_totalSupply.add(shares));
    });

    it("Check Allowance", async function () {
      const allowance = BigNumber.from(100);
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(0);
      await (
        await strategy.setAllowance(owner.address, strategy.address, allowance)
      ).wait();
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(100);

      await expect(
        strategy._spendAllowance(
          owner.address,
          strategy.address,
          allowance.add(1)
        )
      ).to.be.revertedWithCustomError(strategy, "ExcessiveSpend");

      await (
        await strategy._spendAllowance(
          owner.address,
          strategy.address,
          allowance.div(2)
        )
      ).wait();
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(allowance.div(2));

      await (
        await strategy.setAllowance(
          owner.address,
          strategy.address,
          ethers.constants.MaxUint256
        )
      ).wait();
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(ethers.constants.MaxUint256);

      await (
        await strategy._spendAllowance(
          owner.address,
          strategy.address,
          ethers.constants.MaxUint256
        )
      ).wait();
      expect(
        await strategy.checkAllowance(owner.address, strategy.address)
      ).to.equal(ethers.constants.MaxUint256);
    });

    it("Check First Exec", async function () {
      const ONE = BigNumber.from(10).pow(18);
      await execFirstUpdateIndex(ONE.mul(200), ONE.mul(10));
      const ownerBalance = await cfmm.balanceOf(owner.address);
      const strategyBalance = await cfmm.balanceOf(strategy.address);
      const cfmmTotalSupply = await cfmm.totalSupply();
      expect(ownerBalance).to.equal(cfmmTotalSupply.div(2));
      const cfmmInvariant = await cfmm.invariant();
      const gsTotalSupply = await strategy.totalSupply0();
      const ownerGSBalance = await strategy.balanceOf(owner.address);
      expect(gsTotalSupply).to.equal(ownerGSBalance);
      const params = await strategy.getTotalAssetsParams();
      expect(params.lpBalance).to.equal(strategyBalance);
      expect(params.lpBalance).to.equal(cfmmTotalSupply.div(2));

      await borrowLPTokens(ONE.mul(10));
      const params1 = await strategy.getTotalAssetsParams();
      const interest = params1.lpTokenBorrowedPlusInterest.sub(
        params1.lpBorrowed
      );
      expect(params1.lpBorrowed.add(params1.lpBalance)).to.equal(
        params1.lpTokenTotal.sub(interest)
      );
      const cfmmInvariant1 = await cfmm.invariant();
      expect(cfmmInvariant1).to.equal(cfmmInvariant.mul(95).div(100));
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
          strategy._convertToShares,
          strategy._convertToAssets
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          strategy._convertToAssets,
          strategy._convertToShares
        )
      ).to.be.equal(shares0);

      // supply == 0, (assets > 0, shares == 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(0);

      await updateBalances(assets1, shares1);

      expect(
        await testConvertToShares(
          assets1,
          strategy._convertToShares,
          strategy._convertToAssets
        )
      ).to.be.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          strategy._convertToAssets,
          strategy._convertToShares
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
          strategy._convertToShares,
          strategy._convertToAssets
        )
      ).to.be.equal(assets0);
      expect(
        await testConvertToAssets(
          shares0,
          strategy._convertToAssets,
          strategy._convertToShares
        )
      ).to.be.equal(0);

      // supply > 0, (assets > 0, shares > 0)
      const assets1 = ONE.mul(1000);
      const shares1 = ONE.mul(100);

      await updateBalances(assets1, shares1); // increase totalAssets by 1000, increase totalSupply by 100

      expect(
        await testConvertToShares(
          assets1,
          strategy._convertToShares,
          strategy._convertToAssets
        )
      ).to.not.equal(assets1);
      expect(
        await testConvertToAssets(
          shares1,
          strategy._convertToAssets,
          strategy._convertToShares
        )
      ).to.not.equal(shares1);

      // supply > 0, (assets > 0, shares > 0)
      const assets2 = ONE.mul(3000);
      const shares2 = ONE.mul(200);

      await updateBalances(assets2, shares2); // increase totalAssets by 3000, increase totalSupply by 200

      expect(
        await testConvertToShares(
          assets2,
          strategy._convertToShares,
          strategy._convertToAssets
        )
      ).to.not.equal(assets2);
      expect(
        await testConvertToAssets(
          shares2,
          strategy._convertToAssets,
          strategy._convertToShares
        )
      ).to.not.equal(shares2);
    });
  });

  describe("Write Functions", function () {
    describe("Deposit No Pull", function () {
      it("Error Deposit Assets/LP Tokens", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        await (await cfmm.mint(shares, owner.address)).wait();
        await expect(
          strategy._depositNoPull(owner.address)
        ).to.be.revertedWithCustomError(strategy, "ZeroShares");
      });

      it("< Min Shares Asset Deposit", async function () {
        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

        expect(await cfmm.totalSupply()).to.equal(0);
        expect(await cfmm.invariant()).to.equal(0);

        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        await (await cfmm.transfer(strategy.address, 10)).wait();

        await expect(
          strategy._depositNoPull(owner.address)
        ).to.be.revertedWithPanic();
      });

      it("= Min Shares Deposit", async function () {
        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

        expect(await cfmm.totalSupply()).to.equal(0);
        expect(await cfmm.invariant()).to.equal(0);

        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        const minShares = 1000;

        await (await cfmm.transfer(strategy.address, minShares)).wait();

        await expect(
          strategy._depositNoPull(owner.address)
        ).to.be.revertedWithCustomError(strategy, "ZeroAmount");
      });

      it("First Deposit Assets/LP Tokens", async function () {
        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

        expect(await cfmm.totalSupply()).to.equal(0);
        expect(await cfmm.invariant()).to.equal(0);

        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        const assets = shares.div(2);
        const expectedGSShares = await strategy._convertToShares(assets);
        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        const minShares = 1000;

        await (await cfmm.transfer(strategy.address, assets)).wait();

        const cfmmReserves = await cfmm.getReserves();

        const { events } = await (
          await strategy._depositNoPull(owner.address)
        ).wait();

        const depositEvent0 = events[events.length - 5];
        expect(depositEvent0.event).to.equal("Deposit");
        expect(depositEvent0.args.caller).to.equal(owner.address);
        expect(depositEvent0.args.to).to.equal(ethers.constants.AddressZero);
        expect(depositEvent0.args.assets).to.equal(minShares);
        expect(depositEvent0.args.shares).to.equal(minShares);

        const poolUpdatedEvent0 = events[events.length - 4];
        expect(poolUpdatedEvent0.event).to.equal("PoolUpdated");
        expect(poolUpdatedEvent0.args.lpTokenBalance).to.equal(assets);
        expect(poolUpdatedEvent0.args.lpTokenBorrowed).to.equal(0);
        expect(poolUpdatedEvent0.args.lastBlockNumber).to.equal(
          (await ethers.provider.getBlock("latest")).number
        );

        const cfmmBalance0 = await cfmm.balanceOf(strategy.address);
        const cfmmTotalSupply0 = await cfmm.totalSupply();
        const cfmmInvariant0 = await cfmm.invariant();
        const lpInvariant0 = cfmmBalance0
          .mul(cfmmInvariant0)
          .div(cfmmTotalSupply0);
        expect(poolUpdatedEvent0.args.accFeeIndex).to.equal(ONE);
        expect(poolUpdatedEvent0.args.lpTokenBorrowedPlusInterest).to.equal(0);
        expect(poolUpdatedEvent0.args.lpInvariant).to.equal(lpInvariant0);
        expect(poolUpdatedEvent0.args.borrowedInvariant).to.equal(0);
        expect(poolUpdatedEvent0.args.cfmmReserves.length).to.equal(2);
        expect(poolUpdatedEvent0.args.cfmmReserves[0]).to.equal(
          cfmmReserves[0]
        );
        expect(poolUpdatedEvent0.args.cfmmReserves[1]).to.equal(
          cfmmReserves[1]
        );
        expect(poolUpdatedEvent0.args.txType).to.equal(0);

        const depositEvent = events[events.length - 2];
        expect(depositEvent.event).to.equal("Deposit");
        expect(depositEvent.args.caller).to.equal(owner.address);
        expect(depositEvent.args.to).to.equal(owner.address);
        expect(depositEvent.args.assets).to.equal(assets.sub(minShares));
        expect(depositEvent.args.shares).to.equal(
          expectedGSShares.sub(minShares)
        );

        const poolUpdatedEvent = events[events.length - 1];
        expect(poolUpdatedEvent.event).to.equal("PoolUpdated");
        expect(poolUpdatedEvent.args.lpTokenBalance).to.equal(assets);
        expect(poolUpdatedEvent.args.lpTokenBorrowed).to.equal(0);
        expect(poolUpdatedEvent.args.lastBlockNumber).to.equal(
          (await ethers.provider.getBlock("latest")).number
        );

        const cfmmBalance = await cfmm.balanceOf(strategy.address);
        const cfmmTotalSupply = await cfmm.totalSupply();
        const cfmmInvariant = await cfmm.invariant();
        const lpInvariant = cfmmBalance.mul(cfmmInvariant).div(cfmmTotalSupply);
        expect(poolUpdatedEvent.args.accFeeIndex).to.equal(ONE);
        expect(poolUpdatedEvent.args.lpTokenBorrowedPlusInterest).to.equal(0);
        expect(poolUpdatedEvent.args.lpInvariant).to.equal(lpInvariant);
        expect(poolUpdatedEvent.args.borrowedInvariant).to.equal(0);
        expect(poolUpdatedEvent.args.cfmmReserves.length).to.equal(2);
        expect(poolUpdatedEvent.args.cfmmReserves[0]).to.equal(cfmmReserves[0]);
        expect(poolUpdatedEvent.args.cfmmReserves[1]).to.equal(cfmmReserves[1]);
        expect(poolUpdatedEvent.args.txType).to.equal(0);

        expect(await strategy.totalSupply0()).to.equal(expectedGSShares);
        expect(await strategy.balanceOf(owner.address)).to.equal(
          expectedGSShares.sub(minShares)
        );
        const params1 = await strategy.getTotalAssetsParams();
        expect(params1.lpBalance).to.equal(assets);
        expect(assets).to.equal(expectedGSShares);
      });

      it("Total Assets Ignore CFMM Fee if Same Block", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        const assets = shares.div(2);
        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        await (
          await cfmm.approve(strategy.address, ethers.constants.MaxUint256)
        ).wait();

        await (await cfmm.transfer(strategy.address, assets)).wait();

        await (await strategy._depositNoPull(owner.address)).wait();

        await borrowLPTokens(ONE.mul(10));

        const cfmmTotalSupply0 = await cfmm.totalSupply();
        const cfmmInvariant0 = await cfmm.invariant();

        const params0 = await strategy.getTotalAssetsParams();

        const borrowRate = await strategy.calcBorrowRate(
          params0.borrowedInvariant,
          params0.lpInvariant,
          paramsStore.address,
          strategy.address
        );

        let lastFees = await strategy.getLastFees(
          borrowRate.borrowRate,
          params0.borrowedInvariant,
          cfmmInvariant0,
          cfmmTotalSupply0,
          params0.prevCFMMInvariant,
          params0.prevCFMMTotalSupply,
          params0.lastBlockNum,
          params0.lastCFMMFeeIndex,
          borrowRate.maxCFMMFeeLeverage,
          borrowRate.spread
        );

        const totalAssets0 = await strategy.totalAssets(
          params0.borrowedInvariant,
          params0.lpBalance,
          cfmmInvariant0,
          cfmmTotalSupply0,
          lastFees.lastFeeIndex
        );

        await (await cfmm.trade(tradeYield)).wait();

        const cfmmTotalSupply1 = await cfmm.totalSupply();
        const cfmmInvariant1 = await cfmm.invariant();

        const params1 = await strategy.getTotalAssetsParams();

        const borrowRate1 = await strategy.calcBorrowRate(
          params1.borrowedInvariant,
          params1.lpInvariant,
          paramsStore.address,
          strategy.address
        );

        lastFees = await strategy.getLastFees(
          borrowRate1.borrowRate,
          params1.borrowedInvariant,
          cfmmInvariant1,
          cfmmTotalSupply1,
          params1.prevCFMMInvariant,
          params1.prevCFMMTotalSupply,
          params1.lastBlockNum.add(1),
          params1.lastCFMMFeeIndex,
          borrowRate1.maxCFMMFeeLeverage,
          borrowRate1.spread
        );
        const totalAssets1 = await strategy.totalAssets(
          params1.borrowedInvariant,
          params1.lpBalance,
          cfmmInvariant1,
          cfmmTotalSupply1,
          lastFees.lastFeeIndex
        );

        const expTotAssets = params1.lpBalance.add(
          params1.borrowedInvariant.mul(cfmmTotalSupply1).div(cfmmInvariant1)
        );

        expect(cfmmTotalSupply1).to.equal(cfmmTotalSupply0);
        expect(cfmmInvariant1).to.gt(cfmmInvariant0); // trade fees accrued
        expect(totalAssets1).to.lt(totalAssets0); // decreased value of GS LP in CFMM in LP tokens within 1 block
        expect(totalAssets1).to.equal(expTotAssets);
      });

      it("More Deposit Assets/LP Tokens", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        const assets = shares.div(2);
        const expectedGSShares = await strategy._convertToShares(assets);
        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        await (
          await cfmm.approve(strategy.address, ethers.constants.MaxUint256)
        ).wait();

        await (await cfmm.transfer(strategy.address, assets)).wait();

        const minShares = 1000;

        const { events } = await (
          await strategy._depositNoPull(owner.address)
        ).wait();

        const depositEvent = events[events.length - 2];
        expect(depositEvent.event).to.equal("Deposit");
        expect(depositEvent.args.caller).to.equal(owner.address);
        expect(depositEvent.args.to).to.equal(owner.address);
        expect(depositEvent.args.assets).to.equal(assets.sub(minShares));
        expect(depositEvent.args.shares).to.equal(
          expectedGSShares.sub(minShares)
        );

        expect(await strategy.totalSupply0()).to.equal(expectedGSShares);
        expect(await strategy.balanceOf(owner.address)).to.equal(
          expectedGSShares.sub(minShares)
        );

        await (await cfmm.trade(tradeYield)).wait();

        const assets2 = assets.div(2);
        const expectedGSShares2 = await strategy._convertToShares(assets2);

        // time passes by
        // mine 256 blocks
        await ethers.provider.send("hardhat_mine", ["0x100"]);

        await (await cfmm.transfer(strategy.address, assets2)).wait();

        const resp = await (
          await strategy._depositNoPull(owner.address)
        ).wait();

        const depositEvent1 = resp.events[resp.events.length - 2];
        expect(depositEvent1.event).to.equal("Deposit");
        expect(depositEvent1.args.caller).to.equal(owner.address);
        expect(depositEvent1.args.to).to.equal(owner.address);
        expect(depositEvent1.args.assets).to.equal(assets2);
        expect(depositEvent1.args.shares).to.equal(expectedGSShares2);

        await borrowLPTokens(ONE.mul(10));

        await (await cfmm.trade(tradeYield)).wait();
        // time passes by
        // mine 256 blocks
        await ethers.provider.send("hardhat_mine", ["0x100"]);

        const assets3 = assets2.div(2);
        const params1 = await strategy.getTotalAssetsParams();

        const cfmmTotalSupply1 = await cfmm.totalSupply();
        const cfmmInvariant1 = await cfmm.invariant();

        const borrowRate = await strategy.calcBorrowRate(
          params1.borrowedInvariant,
          params1.lpInvariant,
          paramsStore.address,
          strategy.address
        );

        const lastFees = await strategy.getLastFees(
          borrowRate.borrowRate,
          params1.borrowedInvariant,
          cfmmInvariant1,
          cfmmTotalSupply1,
          params1.prevCFMMInvariant,
          params1.prevCFMMTotalSupply,
          params1.lastBlockNum.sub(2),
          params1.lastCFMMFeeIndex,
          borrowRate.maxCFMMFeeLeverage,
          borrowRate.spread
        );

        const currTotalAssets = await strategy.totalAssets(
          params1.borrowedInvariant,
          params1.lpBalance,
          cfmmInvariant1,
          cfmmTotalSupply1,
          lastFees.lastFeeIndex
        );

        const expectedGSShares3 = assets3
          .mul(await strategy.totalSupply0())
          .div(currTotalAssets);

        await (await cfmm.transfer(strategy.address, assets3)).wait();

        const resp1 = await (
          await strategy._depositNoPull(owner.address)
        ).wait();

        const depositEvent2 = resp1.events[resp1.events.length - 2];
        expect(depositEvent2.event).to.equal("Deposit");
        expect(depositEvent2.args.caller).to.equal(owner.address);
        expect(depositEvent2.args.to).to.equal(owner.address);
        expect(depositEvent2.args.assets).to.equal(assets3);
        expect(depositEvent2.args.shares).to.equal(expectedGSShares3);
      });
    });

    describe("Withdraw No Pull", function () {
      it("Withdraw Shares Error", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const assets = ONE.mul(200);
        await prepareAssetsToWithdraw(assets, owner);

        await expect(
          strategy._withdrawNoPull(owner.address)
        ).to.be.revertedWithCustomError(strategy, "ZeroAssets");

        await (await strategy.transfer(strategy.address, assets)).wait();

        await borrowLPTokens(ONE.mul(1));

        await expect(
          strategy._withdrawNoPull(owner.address)
        ).to.be.revertedWithCustomError(strategy, "ExcessiveWithdrawal");
      });

      it("Withdraw Shares", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const assets = ONE.mul(200);
        await prepareAssetsToWithdraw(assets, owner);

        const withdrawAssets = ONE.mul(50);
        const shares = ONE.mul(50);

        await (await strategy.transfer(strategy.address, shares)).wait();

        await testWithdraw(
          owner.address,
          addr1.address,
          withdrawAssets,
          shares,
          ethers.constants.Zero,
          withdrawAssets,
          ethers.constants.Zero,
          ethers.constants.Zero,
          ethers.constants.Zero,
          withdrawNoPull
        );

        await (await strategy.transfer(strategy.address, shares)).wait();

        await testWithdraw(
          owner.address,
          owner.address,
          withdrawAssets,
          shares,
          withdrawAssets,
          withdrawAssets,
          ethers.constants.Zero,
          ethers.constants.Zero,
          ethers.constants.Zero,
          withdrawNoPull
        );
      });
    });

    describe("Deposit Reserves", function () {
      it("Error Deposit Reserves", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        await (await cfmm.mint(shares, owner.address)).wait();

        await expect(
          posManager.depositReserves(owner.address, [0, 0], [0, 0])
        ).to.be.revertedWithCustomError(posManager, "ZeroShares");

        const amtDesired1 = [2, 2];
        const amtMin1 = [0, 0];
        await expect(
          posManager.depositReserves(owner.address, amtDesired1, amtMin1)
        ).to.be.revertedWithCustomError(posManager, "STF_Fail");

        await (
          await tokenA.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();
        await (
          await tokenB.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();

        await expect(
          posManager.depositReserves(owner.address, [1, 2], [0, 0])
        ).to.be.revertedWithCustomError(posManager, "WrongTokenBalance");

        await expect(
          posManager.depositReserves(owner.address, [2, 1], [0, 0])
        ).to.be.revertedWithCustomError(posManager, "WrongTokenBalance");

        await expect(
          posManager.depositReserves(owner.address, [1, 1], [0, 0])
        ).to.be.revertedWithCustomError(posManager, "WrongTokenBalance");
      });

      it("< Min Shares Deposit", async function () {
        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

        expect(await cfmm.totalSupply()).to.equal(0);
        expect(await cfmm.invariant()).to.equal(0);

        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        await (
          await tokenA.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();
        await (
          await tokenB.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();

        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        await expect(
          posManager.depositReserves(owner.address, [10, 10], [0, 0])
        ).to.be.revertedWithPanic();
      });

      it("= Min Shares Deposit", async function () {
        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

        expect(await cfmm.totalSupply()).to.equal(0);
        expect(await cfmm.invariant()).to.equal(0);

        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        await (
          await tokenA.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();
        await (
          await tokenB.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();

        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        await expect(
          posManager.depositReserves(owner.address, [500, 500], [0, 0])
        ).to.be.revertedWithCustomError(posManager, "ZeroAmount");
      });

      it("First Deposit Reserves", async function () {
        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(ethers.constants.Zero, ethers.constants.Zero);

        expect(await cfmm.totalSupply()).to.equal(0);
        expect(await cfmm.invariant()).to.equal(0);

        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        await (
          await tokenA.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();
        await (
          await tokenB.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();

        const assets = BigNumber.from(2000);
        const expectedGSShares = await strategy._convertToShares(assets);
        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        const minShares = 1000;

        const cfmmReserves = await cfmm.getReserves();

        const res = await (
          await posManager.depositReserves(owner.address, [1000, 1000], [0, 0])
        ).wait();

        const depositEvent0 = res.events[res.events.length - 6];
        expect(depositEvent0.event).to.equal("Deposit");
        expect(depositEvent0.args.caller).to.equal(posManager.address);
        expect(depositEvent0.args.to).to.equal(ethers.constants.AddressZero);
        expect(depositEvent0.args.assets).to.equal(minShares);
        expect(depositEvent0.args.shares).to.equal(minShares);

        const poolUpdatedEvent0 = res.events[res.events.length - 5];
        expect(poolUpdatedEvent0.event).to.equal("PoolUpdated");
        expect(poolUpdatedEvent0.args.lpTokenBalance).to.equal(assets);
        expect(poolUpdatedEvent0.args.lpTokenBorrowed).to.equal(0);
        expect(poolUpdatedEvent0.args.lastBlockNumber).to.equal(
          (await ethers.provider.getBlock("latest")).number
        );
        expect(poolUpdatedEvent0.args.accFeeIndex).to.equal(ONE);
        expect(poolUpdatedEvent0.args.lpTokenBorrowedPlusInterest).to.equal(0);

        const cfmmBalance0 = await cfmm.balanceOf(strategy.address);
        const cfmmTotalSupply0 = await cfmm.totalSupply();
        const cfmmInvariant0 = await cfmm.invariant();
        const lpInvariant0 = cfmmBalance0
          .mul(cfmmInvariant0)
          .div(cfmmTotalSupply0);
        expect(poolUpdatedEvent0.args.lpInvariant).to.equal(lpInvariant0);
        expect(poolUpdatedEvent0.args.borrowedInvariant).to.equal(0);
        expect(poolUpdatedEvent0.args.cfmmReserves.length).to.equal(2);
        expect(poolUpdatedEvent0.args.cfmmReserves[0]).to.equal(
          cfmmReserves[0] + 1000
        );
        expect(poolUpdatedEvent0.args.cfmmReserves[1]).to.equal(
          cfmmReserves[1] + 1000
        );
        expect(poolUpdatedEvent0.args.txType).to.equal(2);

        const depositEvent = res.events[res.events.length - 3];
        expect(depositEvent.event).to.equal("Deposit");
        expect(depositEvent.args.caller).to.equal(posManager.address);
        expect(depositEvent.args.to).to.equal(owner.address);
        expect(depositEvent.args.assets).to.equal(minShares);
        expect(depositEvent.args.shares).to.equal(minShares);

        const poolUpdatedEvent = res.events[res.events.length - 2];
        expect(poolUpdatedEvent.event).to.equal("PoolUpdated");
        expect(poolUpdatedEvent.args.lpTokenBalance).to.equal(assets);
        expect(poolUpdatedEvent.args.lpTokenBorrowed).to.equal(0);
        expect(poolUpdatedEvent.args.lastBlockNumber).to.equal(
          (await ethers.provider.getBlock("latest")).number
        );
        expect(poolUpdatedEvent.args.accFeeIndex).to.equal(ONE);
        expect(poolUpdatedEvent.args.lpTokenBorrowedPlusInterest).to.equal(0);

        const cfmmBalance = await cfmm.balanceOf(strategy.address);
        const cfmmTotalSupply = await cfmm.totalSupply();
        const cfmmInvariant = await cfmm.invariant();
        const lpInvariant = cfmmBalance.mul(cfmmInvariant).div(cfmmTotalSupply);
        expect(poolUpdatedEvent.args.lpInvariant).to.equal(lpInvariant);
        expect(poolUpdatedEvent.args.borrowedInvariant).to.equal(0);
        expect(poolUpdatedEvent.args.cfmmReserves.length).to.equal(2);
        expect(poolUpdatedEvent.args.cfmmReserves[0]).to.equal(
          cfmmReserves[0] + 1000
        );
        expect(poolUpdatedEvent.args.cfmmReserves[1]).to.equal(
          cfmmReserves[1] + 1000
        );
        expect(poolUpdatedEvent.args.txType).to.equal(2);

        const depositReserveEvent = res.events[res.events.length - 1];
        expect(depositReserveEvent.args.pool).to.equal(strategy.address);
        expect(depositReserveEvent.args.reserves.length).to.equal(2);
        expect(depositReserveEvent.args.reservesLen).to.equal(
          depositReserveEvent.args.reserves.length
        );
        expect(depositReserveEvent.args.reserves[0]).to.equal(1000);
        expect(depositReserveEvent.args.reserves[1]).to.equal(1000);
        expect(depositReserveEvent.args.shares).to.equal(minShares);

        expect(await strategy.totalSupply0()).to.equal(expectedGSShares);
        expect(await strategy.balanceOf(owner.address)).to.equal(minShares);
        const params1 = await strategy.getTotalAssetsParams();
        expect(params1.lpBalance).to.equal(assets);
        expect(assets).to.equal(expectedGSShares);
      });

      it("More Deposit Reserves", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const shares = ONE.mul(200);
        const tradeYield = ONE.mul(10);
        await (await cfmm.mint(shares, owner.address)).wait();
        await (await cfmm.trade(tradeYield)).wait();

        await (await strategy.testUpdateIndex()).wait();
        await checkGSPoolIsEmpty(shares, shares.add(tradeYield));

        expect(await cfmm.totalSupply()).to.equal(shares);
        expect(await cfmm.invariant()).to.equal(shares.add(tradeYield));

        await (
          await tokenA.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();
        await (
          await tokenB.approve(posManager.address, ethers.constants.MaxUint256)
        ).wait();

        const assets = shares.div(2);
        const expectedGSShares = await strategy._convertToShares(assets);
        const params = await strategy.getTotalAssetsParams();
        expect(params.lpBalance).to.equal(0);

        const minShares = 1000;

        const res = await (
          await posManager.depositReserves(
            owner.address,
            [assets.div(2), assets.div(2)],
            [0, 0]
          )
        ).wait();

        const depositEvent = res.events[res.events.length - 3];
        expect(depositEvent.event).to.equal("Deposit");
        expect(depositEvent.args.caller).to.equal(posManager.address);
        expect(depositEvent.args.to).to.equal(owner.address);
        expect(depositEvent.args.assets).to.equal(assets.sub(minShares));
        expect(depositEvent.args.shares).to.equal(
          expectedGSShares.sub(minShares)
        );

        expect(await strategy.totalSupply0()).to.equal(expectedGSShares);
        expect(await strategy.balanceOf(owner.address)).to.equal(
          expectedGSShares.sub(minShares)
        );

        await (await cfmm.trade(tradeYield)).wait();

        const assets2 = assets.div(2);
        const expectedGSShares2 = await strategy._convertToShares(assets2);

        // time passes by
        // mine 256 blocks
        await ethers.provider.send("hardhat_mine", ["0x100"]);

        const resp = await (
          await posManager.depositReserves(
            owner.address,
            [assets2.div(2), assets2.div(2)],
            [0, 0]
          )
        ).wait();

        const depositEvent1 = resp.events[resp.events.length - 3];
        expect(depositEvent1.event).to.equal("Deposit");
        expect(depositEvent1.args.caller).to.equal(posManager.address);
        expect(depositEvent1.args.to).to.equal(owner.address);
        expect(depositEvent1.args.assets).to.equal(assets2);
        expect(depositEvent1.args.shares).to.equal(expectedGSShares2);

        await borrowLPTokens(ONE.mul(10));

        await (await cfmm.trade(tradeYield)).wait();
        // time passes by
        // mine 256 blocks
        await ethers.provider.send("hardhat_mine", ["0x100"]);

        const assets3 = assets2.div(2);
        const params1 = await strategy.getTotalAssetsParams();

        const cfmmTotalSupply1 = await cfmm.totalSupply();
        const cfmmInvariant1 = await cfmm.invariant();

        const borrowRate = await strategy.calcBorrowRate(
          params1.borrowedInvariant,
          params1.lpInvariant,
          paramsStore.address,
          strategy.address
        );

        const lastFees = await strategy.getLastFees(
          borrowRate.borrowRate,
          params1.borrowedInvariant,
          cfmmInvariant1,
          cfmmTotalSupply1,
          params1.prevCFMMInvariant,
          params1.prevCFMMTotalSupply,
          params1.lastBlockNum.sub(1),
          params1.lastCFMMFeeIndex,
          borrowRate.maxCFMMFeeLeverage,
          borrowRate.spread
        );

        const currTotalAssets = await strategy.totalAssets(
          params1.borrowedInvariant,
          params1.lpBalance,
          cfmmInvariant1,
          cfmmTotalSupply1,
          lastFees.lastFeeIndex
        );

        const expectedGSShares3 = assets3
          .mul(await strategy.totalSupply0())
          .div(currTotalAssets);

        const resp1 = await (
          await posManager.depositReserves(
            owner.address,
            [assets3.div(2), assets3.div(2)],
            [0, 0]
          )
        ).wait();

        const depositEvent2 = resp1.events[resp1.events.length - 3];
        expect(depositEvent2.event).to.equal("Deposit");
        expect(depositEvent2.args.caller).to.equal(posManager.address);
        expect(depositEvent2.args.to).to.equal(owner.address);
        expect(depositEvent2.args.assets).to.equal(assets3);
        expect(depositEvent2.args.shares).to.equal(expectedGSShares3);
      });
    });

    describe("Withdraw Reserves", function () {
      it("Withdraw Reserves Error", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const assets = ONE.mul(200);
        await prepareAssetsToWithdraw(assets, owner);

        await expect(
          strategy._withdrawReserves(owner.address)
        ).to.be.revertedWithCustomError(strategy, "ZeroAssets");

        await (await strategy.transfer(strategy.address, assets)).wait();

        await borrowLPTokens(ONE.mul(1));

        await expect(
          strategy._withdrawReserves(owner.address)
        ).to.be.revertedWithCustomError(strategy, "ExcessiveWithdrawal");
      });

      it("Withdraw Reserves", async function () {
        const ONE = BigNumber.from(10).pow(18);
        const assets = ONE.mul(200);
        await prepareAssetsToWithdraw(assets, owner);

        const withdrawAssets = ONE.mul(50);
        const shares = ONE.mul(50);

        // px is assumed to be 2
        await (await strategy.transfer(strategy.address, shares)).wait();

        await testWithdrawReserves(
          owner.address,
          addr1.address,
          withdrawAssets,
          shares,
          ethers.constants.Zero, // ownerAssetChange: BigNumber,
          ethers.constants.Zero, // receiverAssetChange: BigNumber,
          ethers.constants.Zero, // ownerShareChange: BigNumber,
          ethers.constants.Zero, // receiverShareChange: BigNumber,
          withdrawAssets, // token0Change: BigNumber,
          withdrawAssets.mul(2), // token1Change: BigNumber,
          withdrawReserves
        );

        await (await strategy.transfer(strategy.address, shares)).wait();

        await testWithdrawReserves(
          owner.address,
          owner.address,
          withdrawAssets,
          shares,
          ethers.constants.Zero,
          ethers.constants.Zero,
          ethers.constants.Zero,
          ethers.constants.Zero,
          withdrawAssets, // token0Change: BigNumber,
          withdrawAssets.mul(2), // token1Change: BigNumber,
          withdrawReserves
        );
      });
    });
  });
});
