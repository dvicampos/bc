// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IAuthorityRegistry.sol";

contract ThincrsCertificateSBT is ERC721URIStorage, AccessControl, Pausable {
    IAuthorityRegistry public authorityRegistry;
    uint256 public nextTokenId;

    struct CertificateRecord {
        uint256 tokenId;
        address recipient;
        address issuer;
        bytes32 courseId;
        bytes32 certificateHash;
        uint64 issuedAt;
        bool revoked;
        uint64 revokedAt;
        string revocationReason;
    }

    mapping(uint256 => CertificateRecord) public certificates;
    mapping(bytes32 => bool) public usedCertificateHashes;

    event CertificateMinted(
        uint256 indexed tokenId,
        address indexed recipient,
        address indexed issuer,
        bytes32 courseId,
        bytes32 certificateHash
    );

    event CertificateRevoked(
        uint256 indexed tokenId,
        address indexed revokedBy,
        string reason
    );

    error NotAuthorizedIssuer();
    error InvalidRecipient();
    error CertificateHashAlreadyUsed();
    error CertificateNotFound();
    error CertificateAlreadyRevoked();
    error UnauthorizedRevocation();
    error NonTransferable();
    error ApprovalsDisabled();

    constructor(address registryAddress, address admin)
        ERC721("Thincrs Certificate", "THINCRS-SBT")
    {
        require(registryAddress != address(0), "Invalid registry");
        require(admin != address(0), "Invalid admin");

        authorityRegistry = IAuthorityRegistry(registryAddress);
        nextTokenId = 1;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mintCertificate(
        address recipient,
        bytes32 courseId,
        bytes32 certificateHash,
        string calldata tokenURI_
    ) external whenNotPaused returns (uint256) {
        if (!authorityRegistry.isAuthorizedIssuer(msg.sender)) revert NotAuthorizedIssuer();
        if (recipient == address(0)) revert InvalidRecipient();
        if (usedCertificateHashes[certificateHash]) revert CertificateHashAlreadyUsed();

        uint256 tokenId = nextTokenId;
        nextTokenId++;

        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        certificates[tokenId] = CertificateRecord({
            tokenId: tokenId,
            recipient: recipient,
            issuer: msg.sender,
            courseId: courseId,
            certificateHash: certificateHash,
            issuedAt: uint64(block.timestamp),
            revoked: false,
            revokedAt: 0,
            revocationReason: ""
        });

        usedCertificateHashes[certificateHash] = true;

        emit CertificateMinted(tokenId, recipient, msg.sender, courseId, certificateHash);

        return tokenId;
    }

    function revokeCertificate(
        uint256 tokenId,
        string calldata reason
    ) external whenNotPaused {
        if (!_exists(tokenId)) revert CertificateNotFound();

        CertificateRecord storage cert = certificates[tokenId];
        if (cert.revoked) revert CertificateAlreadyRevoked();

        bool isRootAuthority = authorityRegistry.hasRole(
            authorityRegistry.ROOT_AUTHORITY_ROLE(),
            msg.sender
        );

        bool isOriginalIssuerActive =
            cert.issuer == msg.sender &&
            authorityRegistry.isAuthorizedIssuer(msg.sender);

        if (!isRootAuthority && !isOriginalIssuerActive) {
            revert UnauthorizedRevocation();
        }

        cert.revoked = true;
        cert.revokedAt = uint64(block.timestamp);
        cert.revocationReason = reason;

        emit CertificateRevoked(tokenId, msg.sender, reason);
    }

    function isRevoked(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert CertificateNotFound();
        return certificates[tokenId].revoked;
    }

    function getCertificate(uint256 tokenId)
        external
        view
        returns (CertificateRecord memory)
    {
        if (!_exists(tokenId)) revert CertificateNotFound();
        return certificates[tokenId];
    }

    function getCertificatesByOwner(address owner, uint256[] calldata tokenIds)
        external
        view
        returns (CertificateRecord[] memory result)
    {
        uint256 len = tokenIds.length;
        result = new CertificateRecord[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 tokenId = tokenIds[i];
            if (_exists(tokenId) && ownerOf(tokenId) == owner) {
                result[i] = certificates[tokenId];
            }
        }
    }

    function setAuthorityRegistry(address registryAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(registryAddress != address(0), "Invalid registry");
        authorityRegistry = IAuthorityRegistry(registryAddress);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function approve(address, uint256) public pure override(ERC721, IERC721) {
        revert ApprovalsDisabled();
    }

    function setApprovalForAll(address, bool) public pure override(ERC721, IERC721) {
        revert ApprovalsDisabled();
    }

    function transferFrom(address, address, uint256) public pure override(ERC721, IERC721) {
        revert NonTransferable();
    }

    function safeTransferFrom(address, address, uint256) public pure override(ERC721, IERC721) {
        revert NonTransferable();
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override(ERC721, IERC721) {
        revert NonTransferable();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        if (from != address(0) && to != address(0)) {
            revert NonTransferable();
        }

        if (from != address(0) && to == address(0)) {
            revert NonTransferable();
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}