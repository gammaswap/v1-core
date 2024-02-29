// @ts-ignore
import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

describe("LinearKinkedRateModel", function () {
  let RateModel: any;
  let TestRateParamsStore: any;
  let rateModel: any;
  let rateParamsStore: any;
  let baseRate: any;
  let optimalUtilRate: any;
  let slope1: any;
  let slope2: any;
  let owner: any;
  let ONE: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    RateModel = await ethers.getContractFactory("TestLinearKinkedRateModel");
    TestRateParamsStore = await ethers.getContractFactory(
      "TestRateParamsStore"
    );

    [owner] = await ethers.getSigners();

    ONE = BigNumber.from(10).pow(18);
    baseRate = ONE.div(100);
    optimalUtilRate = ONE.mul(8).div(10);
    slope1 = ONE.mul(4).div(100);
    slope2 = ONE.mul(75).div(100);

    rateModel = await RateModel.deploy(
      baseRate,
      optimalUtilRate,
      slope1,
      slope2
    );
    rateParamsStore = await TestRateParamsStore.deploy(owner.address);
    await (await rateModel.setRateParamsStore(rateParamsStore.address)).wait();
  });

  function calcBorrowRate(
    lpInvariant: BigNumber,
    borrowedInvariant: BigNumber
  ): BigNumber {
    const totalInvariant = borrowedInvariant.add(lpInvariant);
    const utilizationRate = borrowedInvariant.mul(ONE).div(totalInvariant);
    if (utilizationRate.lte(optimalUtilRate)) {
      const variableRate = utilizationRate.mul(slope1).div(optimalUtilRate);
      return baseRate.add(variableRate);
    } else {
      const utilizationRateDiff = utilizationRate.sub(optimalUtilRate);
      const optimalUtilRateDiff = ONE.sub(optimalUtilRate);
      const variableRate = utilizationRateDiff
        .mul(slope2)
        .div(optimalUtilRateDiff);
      return baseRate.add(slope1).add(variableRate);
    }
  }

  describe("Deployment", function () {
    it("Should set right init params", async function () {
      expect(await rateModel.baseRate()).to.equal(baseRate);
      expect(await rateModel.optimalUtilRate()).to.equal(optimalUtilRate);
      expect(await rateModel.slope1()).to.equal(slope1);
      expect(await rateModel.slope2()).to.equal(slope2);
    });
  });

  describe("Calc Borrow Rate", function () {
    it("lpInvariant: 100, borrowedInvariant: 50", async function () {
      const lpInvariant = ONE.mul(100);
      const borrowedInvariant = ONE.mul(50);
      expect(
        await rateModel.testCalcBorrowRate(lpInvariant, borrowedInvariant)
      ).to.equal(calcBorrowRate(lpInvariant, borrowedInvariant));
    });

    it("lpInvariant: 100, borrowedInvariant: 90", async function () {
      const lpInvariant = ONE.mul(100);
      const borrowedInvariant = ONE.mul(90);
      expect(
        await rateModel.testCalcBorrowRate(lpInvariant, borrowedInvariant)
      ).to.equal(calcBorrowRate(lpInvariant, borrowedInvariant));
    });

    it("lpInvariant: 100, borrowedInvariant: 99", async function () {
      const lpInvariant = ONE.mul(100);
      const borrowedInvariant = ONE.mul(99);
      expect(
        await rateModel.testCalcBorrowRate(lpInvariant, borrowedInvariant)
      ).to.equal(calcBorrowRate(lpInvariant, borrowedInvariant));
    });

    it("lpInvariant: 100, borrowedInvariant: 100", async function () {
      const lpInvariant = ONE.mul(100);
      const borrowedInvariant = ONE.mul(100);
      expect(
        await rateModel.testCalcBorrowRate(lpInvariant, borrowedInvariant)
      ).to.equal(calcBorrowRate(lpInvariant, borrowedInvariant));
    });

    it("lpInvariant: 100, borrowedInvariant: 1000", async function () {
      const lpInvariant = ONE.mul(100);
      const borrowedInvariant = ONE.mul(1000);
      expect(
        await rateModel.testCalcBorrowRate(lpInvariant, borrowedInvariant)
      ).to.equal(calcBorrowRate(lpInvariant, borrowedInvariant));
    });

    it("lpInvariant: 1, borrowedInvariant: 9999999999", async function () {
      const lpInvariant = ONE.mul(1);
      const borrowedInvariant = ONE.mul(9999999999);
      expect(
        await rateModel.testCalcBorrowRate(lpInvariant, borrowedInvariant)
      ).to.equal(calcBorrowRate(lpInvariant, borrowedInvariant));
    });

    it("lpInvariant: 9999999999, borrowedInvariant: 1", async function () {
      const lpInvariant = ONE.mul(9999999999);
      const borrowedInvariant = ONE.mul(1);
      expect(
        await rateModel.testCalcBorrowRate(lpInvariant, borrowedInvariant)
      ).to.equal(calcBorrowRate(lpInvariant, borrowedInvariant));
    });
  });
});
