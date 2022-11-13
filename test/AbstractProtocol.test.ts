import { ethers } from "hardhat";
import { expect } from "chai";

describe("AbstractProtocol", function () {
  let TestERC20: any;
  let TestAbstractProtocol: any;
  let tokenA: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let protocol: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestAbstractProtocol = await ethers.getContractFactory(
      "TestAbstractProtocol"
    );
    [owner, addr1, addr2] = await ethers.getSigners();

    tokenA = await TestERC20.deploy("Test Token A", "TOKA");

    protocol = await TestAbstractProtocol.deploy(
      1,
      addr1.address,
      addr2.address,
      2,
      3
    );
    // We can interact with the contract by calling `hardhatToken.method()`
    await tokenA.deployed();
    await protocol.deployed();
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set right init params", async function () {
      expect(await protocol.protocolId()).to.equal(1);
      expect(await protocol.longStrategy()).to.equal(addr1.address);
      expect(await protocol.shortStrategy()).to.equal(addr2.address);
    });

    it("Get Parameters", async function () {
      const params = await protocol.parameters();
      const sParams = ethers.utils.hexlify(params.sParams);
      const _sParams = ethers.utils.defaultAbiCoder.decode(
        ["uint8"], // specify your return type/s here
        ethers.utils.hexDataSlice(sParams, 0)
      );
      expect(_sParams[0]).to.equal(2);
      const rParams = ethers.utils.hexlify(params.rParams);
      const _rParams = ethers.utils.defaultAbiCoder.decode(
        ["uint8"], // specify your return type/s here
        ethers.utils.hexDataSlice(rParams, 0)
      );
      expect(_rParams[0]).to.equal(3);
    });
  });

  describe("Init & Validation", function () {
    it("Initialize Parameters", async function () {
      const abi = ethers.utils.defaultAbiCoder;
      const sData = abi.encode(
        ["uint8"], // encode as address array
        [4]
      ); // array to encode
      const rData = abi.encode(
        ["uint8"], // encode as address array
        [5]
      ); // array to encode
      await protocol.initialize(sData, rData);

      const params = await protocol.parameters();
      const sParams = ethers.utils.hexlify(params.sParams);
      const _sParams = ethers.utils.defaultAbiCoder.decode(
        ["uint8"], // specify your return type/s here
        ethers.utils.hexDataSlice(sParams, 0)
      );
      expect(_sParams[0]).to.equal(2);
      const rParams = ethers.utils.hexlify(params.rParams);
      const _rParams = ethers.utils.defaultAbiCoder.decode(
        ["uint8"], // specify your return type/s here
        ethers.utils.hexDataSlice(rParams, 0)
      );
      expect(_rParams[0]).to.equal(3);
    });

    it("Is Contract", async function () {
      const tokens = await protocol.validateCFMM(
        [addr1.address, addr2.address],
        tokenA.address
      );
      expect(tokens[0]).to.equal(addr2.address);
      expect(tokens[1]).to.equal(addr1.address);

      await expect(
        protocol.validateCFMM([addr1.address, addr2.address], owner.address)
      ).to.be.revertedWith("NOT_CONTRACT");
    });
  });
});
