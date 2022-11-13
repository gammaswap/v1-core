// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const [owner] = await ethers.getSigners();

  const GammaPool = await ethers.getContractFactory("GammaPool");
  const implementation = await GammaPool.deploy();
  // deploy GammaPoolFactory
  const GammaPoolFactory = await ethers.getContractFactory("GammaPoolFactory");
  const factory = await GammaPoolFactory.deploy(owner.address, implementation.address);
  await factory.deployed();
  console.log("GammaPoolFactory Address >> " + factory.address);
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

