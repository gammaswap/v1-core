// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const cfmmFactoryAddress = "<get this from periphery pre core deploy logs>";
  const [owner] = await ethers.getSigners();
  
  const GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
  const factory = await GammaPoolFactory.deploy(owner.address);
  await factory.deployed()
  console.log("GammaPoolFactory Address >> " + factory.address);

  const CPMMProtocol = await ethers.getContractFactory("CPMMProtocol");
  const protocol = await CPMMProtocol.deploy(
    factory.address,
    cfmmFactoryAddress,
    1,
    "0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f", // cfmm pool hash
    1000,
    997,
    10 ^ 16,
    8 * 10 ^ 17,
    4 * 10 ^ 16,
    75 * 10 ^ 16);
  await protocol.deployed()
  factory.addProtocol(protocol.address);

  const GammaPool = await ethers.getContractFactory("GammaPool");
  const COMPUTED_INIT_CODE_HASH = ethers.utils.keccak256(
    GammaPool.bytecode
  );
  console.log("GAMMAPOOL_INIT_CODE_HASH >> " + COMPUTED_INIT_CODE_HASH)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

