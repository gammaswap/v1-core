// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const gsFactoryAddress = "<get this from pre strat deploy logs>";
  const protocolAddress = "<get this from strategies deploy logs>";

  // add protocol to gs factory
  const gammaPoolFactory = await ethers.getContractAt(
    "GammaPoolFactory",
    gsFactoryAddress
  );
  await gammaPoolFactory.addProtocol(protocolAddress);

  // show GammaPool hash
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

