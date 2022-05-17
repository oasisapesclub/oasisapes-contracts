// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the NonFungibleNanner to deploy
  const TestNanner = await hre.ethers.getContractFactory("TestNanner");
  const NannerShare = await hre.ethers.getContractFactory("NannerShare");
  const NannerFarm = await hre.ethers.getContractFactory("NannerFarm");
  const nanner = await TestNanner.deploy();
  console.log("TestNanner deployed to:", nanner.address);
  const shitcoin = await NannerShare.deploy();
  console.log("Test Shitcoin deployed to", shitcoin.address);

  await nanner.deployed();
  await shitcoin.deployed();

  const farm = await NannerFarm.deploy(shitcoin.address, '0x88aA40a8b6CD99e6d7A34B8e1cC1866AA2e6DdDE', '0x88aA40a8b6CD99e6d7A34B8e1cC1866AA2e6DdDE', 0, 11570000000000000, 0);
  console.log("Test Farm deployed to", farm.address);

  await farm.deployed();
  await shitcoin.transferOwnership(farm.address);
  console.log("shitcoin ownership transferred to farm");

  await farm.setNannerNFT(nanner.address);
  console.log("nanner address set on farm");

  


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
