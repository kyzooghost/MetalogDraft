import { ethers } from 'hardhat';

async function main() {
  const MetaLog = await ethers.getContractFactory('MetaLog');
  const metalog = await MetaLog.deploy();
  await metalog.deployed();
  console.log(`Metalog deployed to ${metalog.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
