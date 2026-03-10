import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying with:", deployer.address);

  const AuthorityRegistry = await ethers.getContractFactory("AuthorityRegistry");
  const registry = await AuthorityRegistry.deploy(deployer.address);
  await registry.waitForDeployment();

  const registryAddress = await registry.getAddress();
  console.log("AuthorityRegistry:", registryAddress);

  const ThincrsCertificateSBT = await ethers.getContractFactory("ThincrsCertificateSBT");
  const sbt = await ThincrsCertificateSBT.deploy(registryAddress, deployer.address);
  await sbt.waitForDeployment();

  const sbtAddress = await sbt.getAddress();
  console.log("ThincrsCertificateSBT:", sbtAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});