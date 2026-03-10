import { expect } from "chai";
import { ethers } from "hardhat";

describe("Thincrs", function () {
  async function deployFixture() {
    const [root, issuer, student, other] = await ethers.getSigners();

    const Registry = await ethers.getContractFactory("AuthorityRegistry");
    const registry = await Registry.deploy(root.address);
    await registry.waitForDeployment();

    const SBT = await ethers.getContractFactory("ThincrsCertificateSBT");
    const sbt = await SBT.deploy(await registry.getAddress(), root.address);
    await sbt.waitForDeployment();

    return { root, issuer, student, other, registry, sbt };
  }

  it("debe registrar y aprobar issuer", async function () {
    const { root, issuer, registry } = await deployFixture();

    await registry.connect(root).registerIssuer(
      issuer.address,
      "Universidad Demo SA",
      "Universidad Demo",
      "ipfs://issuer-meta"
    );

    await registry.connect(root).approveIssuer(issuer.address);

    expect(await registry.isAuthorizedIssuer(issuer.address)).to.equal(true);
  });

  it("solo issuer activo puede mintear", async function () {
    const { root, issuer, student, sbt, registry } = await deployFixture();

    await registry.connect(root).registerIssuer(
      issuer.address,
      "Universidad Demo SA",
      "Universidad Demo",
      "ipfs://issuer-meta"
    );
    await registry.connect(root).approveIssuer(issuer.address);

    const courseId = ethers.id("BLOCKCHAIN-ADV-001");
    const certificateHash = ethers.id("certificado-juan-perez-001");

    await expect(
      sbt.connect(issuer).mintCertificate(
        student.address,
        courseId,
        certificateHash,
        "ipfs://certificate-meta"
      )
    ).to.not.be.reverted;

    expect(await sbt.ownerOf(1)).to.equal(student.address);
  });

  it("no debe permitir transferencias", async function () {
    const { root, issuer, student, other, sbt, registry } = await deployFixture();

    await registry.connect(root).registerIssuer(
      issuer.address,
      "Universidad Demo SA",
      "Universidad Demo",
      "ipfs://issuer-meta"
    );
    await registry.connect(root).approveIssuer(issuer.address);

    const courseId = ethers.id("BLOCKCHAIN-ADV-001");
    const certificateHash = ethers.id("certificado-juan-perez-001");

    await sbt.connect(issuer).mintCertificate(
      student.address,
      courseId,
      certificateHash,
      "ipfs://certificate-meta"
    );

    await expect(
      sbt.connect(student).transferFrom(student.address, other.address, 1)
    ).to.be.reverted;
  });

  it("no debe permitir approve", async function () {
    const { root, issuer, student, other, sbt, registry } = await deployFixture();

    await registry.connect(root).registerIssuer(
      issuer.address,
      "Universidad Demo SA",
      "Universidad Demo",
      "ipfs://issuer-meta"
    );
    await registry.connect(root).approveIssuer(issuer.address);

    const courseId = ethers.id("BLOCKCHAIN-ADV-001");
    const certificateHash = ethers.id("certificado-juan-perez-001");

    await sbt.connect(issuer).mintCertificate(
      student.address,
      courseId,
      certificateHash,
      "ipfs://certificate-meta"
    );

    await expect(
      sbt.connect(student).approve(other.address, 1)
    ).to.be.reverted;
  });

  it("no debe repetir certificateHash", async function () {
    const { root, issuer, student, other, sbt, registry } = await deployFixture();

    await registry.connect(root).registerIssuer(
      issuer.address,
      "Universidad Demo SA",
      "Universidad Demo",
      "ipfs://issuer-meta"
    );
    await registry.connect(root).approveIssuer(issuer.address);

    const courseId = ethers.id("BLOCKCHAIN-ADV-001");
    const certificateHash = ethers.id("certificado-unico");

    await sbt.connect(issuer).mintCertificate(
      student.address,
      courseId,
      certificateHash,
      "ipfs://certificate-meta-1"
    );

    await expect(
      sbt.connect(issuer).mintCertificate(
        other.address,
        courseId,
        certificateHash,
        "ipfs://certificate-meta-2"
      )
    ).to.be.reverted;
  });

  it("root puede revocar", async function () {
    const { root, issuer, student, sbt, registry } = await deployFixture();

    await registry.connect(root).registerIssuer(
      issuer.address,
      "Universidad Demo SA",
      "Universidad Demo",
      "ipfs://issuer-meta"
    );
    await registry.connect(root).approveIssuer(issuer.address);

    const courseId = ethers.id("BLOCKCHAIN-ADV-001");
    const certificateHash = ethers.id("certificado-revocable");

    await sbt.connect(issuer).mintCertificate(
      student.address,
      courseId,
      certificateHash,
      "ipfs://certificate-meta"
    );

    await sbt.connect(root).revokeCertificate(1, "Error de emision");

    const cert = await sbt.getCertificate(1);
    expect(cert.revoked).to.equal(true);
  });
});