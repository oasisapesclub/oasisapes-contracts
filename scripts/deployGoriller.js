const hre = require("hardhat");

async function main() {

  const TestGorillers = await hre.ethers.getContractFactory("TestGorillers");
  const thicccqGoriller = await TestGorillers.deploy();
  console.log("TestGorillers deployed to:", thicccqGoriller.address);

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
