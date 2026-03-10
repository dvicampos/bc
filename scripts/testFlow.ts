import { ethers } from "hardhat";

async function main() {
  const [root, issuer, student] = await ethers.getSigners();

  const registryAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  const sbtAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";

  const registry = await ethers.getContractAt("AuthorityRegistry", registryAddress);
  const sbt = await ethers.getContractAt("ThincrsCertificateSBT", sbtAddress);

  console.log("Root:", root.address);
  console.log("Issuer:", issuer.address);
  console.log("Student:", student.address);

  console.log("\n1. Registrando issuer...");
  const tx1 = await registry.connect(root).registerIssuer(
    issuer.address,
    "Universidad Demo SA",
    "Universidad Demo",
    "ipfs://issuer-meta"
  );
  await tx1.wait();
  console.log("Issuer registrado");

  console.log("\n2. Aprobando issuer...");
  const tx2 = await registry.connect(root).approveIssuer(issuer.address);
  await tx2.wait();
  console.log("Issuer aprobado");

  const isAuthorized = await registry.isAuthorizedIssuer(issuer.address);
  console.log("isAuthorizedIssuer:", isAuthorized);

  console.log("\n3. Emitiendo certificado...");
  const courseId = ethers.keccak256(ethers.toUtf8Bytes("BLOCKCHAIN-101"));
  const certificateHash = ethers.keccak256(
    ethers.toUtf8Bytes("certificado-juan-perez-001")
  );

  const tx3 = await sbt.connect(issuer).mintCertificate(
    student.address,
    courseId,
    certificateHash,
    "ipfs://certificate-meta"
  );
  await tx3.wait();
  console.log("Certificado emitido");

  const owner = await sbt.ownerOf(1);
  console.log("Owner token 1:", owner);

  const cert = await sbt.getCertificate(1);
  console.log("\n4. Certificado:");
  console.log(cert);

  console.log("\n5. Validando revocación...");
  const revoked = await sbt.isRevoked(1);
  console.log("Revoked:", revoked);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});