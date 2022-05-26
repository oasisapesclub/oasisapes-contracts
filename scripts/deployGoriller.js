const hre = require("hardhat");

async function main() {

  const ThicccqGorillers = await hre.ethers.getContractFactory("ThicccqGorillers");
  const thicccqGoriller = await ThicccqGorillers.deploy();
  console.log("ThicccqGorillers deployed to:", thicccqGoriller.address);

  await thicccqGoriller.deployed();

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
