const hre = require("hardhat");
const path = require("path");
const fs = require("fs");

async function main() {
  console.log("Deployment started!");

  const [deployer] = await ethers.getSigners();
  const address = await deployer.getAddress();
  console.log(`Deploying the contract with the account: ${address}`);

  const Antrix = await hre.ethers.getContractFactory("Antrix");
  const contract = await Antrix.deploy(process.env.OWNER_ADDRESS);
  await contract.waitForDeployment()
  console.log(`Antrix deployed to ${contract.target}`);
  
  // saveContractFiles(contract);
}

// function saveContractFiles(contract) {
//     const contractDir=path.join(__dirname, "..","modules");
//     if(!fs.existsSync(contractDir)){
//         fs.mkdirSync(contractDir);
//     }

//     fs.writeFileSync(path.join(contractDir, `contract-address-${hre.network.name}.json`),

//     JSON.stringify({Antrix:contract.target},null,2)
//     );

//     const AntrixArtifact=artifacts.readArtifactSync("Antrix");
//     fs.writeFileSync(path.join(contractDir, Antrix.json),
//     JSON.stringify(AntrixArtifact,null,2)
//     );

// }

main().catch(error => {
  console.log(error);
  process.exitCode = 1;
});


// npx hardhat run scripts/deploy.js --network localhost