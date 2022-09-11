import { ethers } from "hardhat";
import { expect } from "chai";

describe("GammaPool", function () {
  let TestERC20;
  let TestAddressCalculator: any;
  let TestProtocol: any;
  let GammaPool: any;
  let GammaPoolFactory: any;
  let factory: any;
  let testAddressCalculator: any;
  let tokenA: any;
  let tokenB: any;
  let cfmm: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let gammaPool: any;
  let gammaPoolAddr: any;
  let protocol: any;
  let protocolZero: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    TestERC20 = await ethers.getContractFactory("TestERC20");
    TestAddressCalculator = await ethers.getContractFactory(
      "TestAddressCalculator"
    );
    GammaPool = await ethers.getContractFactory("GammaPool");
    [owner] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    testAddressCalculator = await TestAddressCalculator.deploy();
    tokenA = await TestERC20.deploy("Test Token A", "TOKA");
    tokenB = await TestERC20.deploy("Test Token B", "TOKB");

    // We can interact with the contract by calling `hardhatToken.method()`
    await tokenA.deployed();
    await tokenB.deployed();
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    // `it` is another Mocha function. This is the one you use to define your
    // tests. It receives the test name, and a callback function.

    // If the callback function is async, Mocha will `await` it.
    it("Should set the right owner", async function () {
      // Expect receives a value, and wraps it in an assertion objet. These
      // objects have a lot of utility methods to assert values.

      // This test expects the owner variable stored in the contract to be equal
      // to our Signer's owner.
      expect(await tokenA.owner()).to.equal(owner.address);
      expect(await tokenB.owner()).to.equal(owner.address);
    });

    it("Should be right INIT_CODE_HASH", async function () {
      const COMPUTED_INIT_CODE_HASH = ethers.utils.keccak256(
        GammaPool.bytecode
      );
      expect(COMPUTED_INIT_CODE_HASH).to.equal(
        await testAddressCalculator.getInitCodeHash()
      );
    });

    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await tokenA.balanceOf(owner.address);
      expect(await tokenA.totalSupply()).to.equal(ownerBalance);
    });
  });
});
