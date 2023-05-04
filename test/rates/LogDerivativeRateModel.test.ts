// @ts-ignore
import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

describe("LogDerivativeRateModel", function () {
  let RateModel: any;
  let TestRateParamsStore: any;
  let rateModel: any;
  let rateParamsStore: any;
  let baseRate: any;
  let factor: any;
  let maxApy: any;
  let owner: any;
  let ONE: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    RateModel = await ethers.getContractFactory("TestLogDerivativeRateModel");
    TestRateParamsStore = await ethers.getContractFactory(
      "TestRateParamsStore"
    );

    [owner] = await ethers.getSigners();

    ONE = BigNumber.from(10).pow(18);
    baseRate = ONE.div(100);
    factor = ONE.mul(4).div(100);
    maxApy = ONE.mul(75).div(100);

    rateModel = await RateModel.deploy(baseRate, factor, maxApy);
    rateParamsStore = await TestRateParamsStore.deploy(owner.address);
    await (await rateModel.setRateParamsStore(rateParamsStore.address)).wait();
  });

  function calcBorrowRate(
    lpInvariant: BigNumber,
    borrowedInvariant: BigNumber
  ): BigNumber {
    const totalInvariant = borrowedInvariant.add(lpInvariant);
    const utilizationRate = borrowedInvariant.mul(ONE).div(totalInvariant);
    const utilizationRateSquare = utilizationRate.pow(2);
    const deonominator = BigNumber.from(10)
      .pow(36)
      .sub(utilizationRateSquare)
      .add(1);
    const numerator = factor.mul(utilizationRateSquare);
    const rate = numerator.div(deonominator).add(baseRate);

    if (rate.gt(maxApy)) {
      return maxApy;
    }
    return rate;
  }

  describe("Deployment", function () {
    it("Should set right init params", async function () {
      expect(await rateModel.baseRate()).to.equal(baseRate);
      expect(await rateModel.factor()).to.equal(factor);
      expect(await rateModel.maxApy()).to.equal(maxApy);
    });
  });

  describe("Edge Cases", function () {
    it("Max APY", async function () {
      const lpInvariant = ONE.mul(1);
      const borrowedInvariant = ONE.mul(100);
      expect(
        await rateModel.testCalcBorrowRate(lpInvariant, borrowedInvariant)
      ).to.equal(maxApy);
      expect(
        await rateModel.testCalcBorrowRate(
          lpInvariant.mul(10),
          borrowedInvariant
        )
      ).to.lt(maxApy);
    });

    it("No Free Funds Available Rate", async function () {
      const lpInvariant = ONE.mul(1);
      const borrowedInvariant = ONE.mul(100);
      expect(await rateModel.testCalcBorrowRate(0, borrowedInvariant)).to.equal(
        maxApy
      );
      expect(
        await rateModel.testCalcBorrowRate(
          lpInvariant.mul(10),
          borrowedInvariant
        )
      ).to.lt(maxApy);
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
