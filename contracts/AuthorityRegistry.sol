// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract AuthorityRegistry is AccessControl, Pausable {
    bytes32 public constant ROOT_AUTHORITY_ROLE = keccak256("ROOT_AUTHORITY_ROLE");
    bytes32 public constant ISSUER_MANAGER_ROLE = keccak256("ISSUER_MANAGER_ROLE");

    enum IssuerStatus {
        NONE,
        PENDING,
        ACTIVE,
        SUSPENDED,
        REVOKED
    }

    struct Issuer {
        address wallet;
        string legalName;
        string displayName;
        string metadataURI;
        IssuerStatus status;
        uint64 createdAt;
        uint64 approvedAt;
        uint64 suspendedAt;
        uint64 revokedAt;
        address approvedBy;
    }

    mapping(address => Issuer) private issuers;

    event IssuerRegistered(address indexed wallet, string legalName);
    event IssuerApproved(address indexed wallet, address indexed approvedBy);
    event IssuerSuspended(address indexed wallet, address indexed suspendedBy, string reason);
    event IssuerRevoked(address indexed wallet, address indexed revokedBy, string reason);
    event IssuerMetadataUpdated(address indexed wallet, string metadataURI);

    error InvalidWallet();
    error IssuerAlreadyExists();
    error IssuerNotFound();
    error InvalidIssuerStatus(IssuerStatus currentStatus);
    error EmptyString(string fieldName);

    constructor(address rootAdmin) {
        if (rootAdmin == address(0)) revert InvalidWallet();

        _grantRole(DEFAULT_ADMIN_ROLE, rootAdmin);
        _grantRole(ROOT_AUTHORITY_ROLE, rootAdmin);
        _grantRole(ISSUER_MANAGER_ROLE, rootAdmin);
    }

    modifier onlyExistingIssuer(address wallet) {
        if (issuers[wallet].wallet == address(0)) revert IssuerNotFound();
        _;
    }

    function registerIssuer(
        address wallet,
        string calldata legalName,
        string calldata displayName,
        string calldata metadataURI
    ) external onlyRole(ROOT_AUTHORITY_ROLE) whenNotPaused {
        if (wallet == address(0)) revert InvalidWallet();
        if (bytes(legalName).length == 0) revert EmptyString("legalName");
        if (bytes(displayName).length == 0) revert EmptyString("displayName");
        if (issuers[wallet].wallet != address(0)) revert IssuerAlreadyExists();

        issuers[wallet] = Issuer({
            wallet: wallet,
            legalName: legalName,
            displayName: displayName,
            metadataURI: metadataURI,
            status: IssuerStatus.PENDING,
            createdAt: uint64(block.timestamp),
            approvedAt: 0,
            suspendedAt: 0,
            revokedAt: 0,
            approvedBy: address(0)
        });

        emit IssuerRegistered(wallet, legalName);
    }

    function approveIssuer(address wallet)
        external
        onlyRole(ROOT_AUTHORITY_ROLE)
        onlyExistingIssuer(wallet)
        whenNotPaused
    {
        Issuer storage issuer = issuers[wallet];

        if (
            issuer.status != IssuerStatus.PENDING &&
            issuer.status != IssuerStatus.SUSPENDED
        ) {
            revert InvalidIssuerStatus(issuer.status);
        }

        issuer.status = IssuerStatus.ACTIVE;
        issuer.approvedAt = uint64(block.timestamp);
        issuer.approvedBy = msg.sender;

        emit IssuerApproved(wallet, msg.sender);
    }

    function suspendIssuer(address wallet, string calldata reason)
        external
        onlyRole(ROOT_AUTHORITY_ROLE)
        onlyExistingIssuer(wallet)
        whenNotPaused
    {
        Issuer storage issuer = issuers[wallet];

        if (issuer.status != IssuerStatus.ACTIVE) {
            revert InvalidIssuerStatus(issuer.status);
        }

        issuer.status = IssuerStatus.SUSPENDED;
        issuer.suspendedAt = uint64(block.timestamp);

        emit IssuerSuspended(wallet, msg.sender, reason);
    }

    function revokeIssuer(address wallet, string calldata reason)
        external
        onlyRole(ROOT_AUTHORITY_ROLE)
        onlyExistingIssuer(wallet)
        whenNotPaused
    {
        Issuer storage issuer = issuers[wallet];

        if (
            issuer.status == IssuerStatus.NONE ||
            issuer.status == IssuerStatus.REVOKED
        ) {
            revert InvalidIssuerStatus(issuer.status);
        }

        issuer.status = IssuerStatus.REVOKED;
        issuer.revokedAt = uint64(block.timestamp);

        emit IssuerRevoked(wallet, msg.sender, reason);
    }

    function updateIssuerMetadataURI(address wallet, string calldata metadataURI)
        external
        onlyRole(ROOT_AUTHORITY_ROLE)
        onlyExistingIssuer(wallet)
        whenNotPaused
    {
        issuers[wallet].metadataURI = metadataURI;
        emit IssuerMetadataUpdated(wallet, metadataURI);
    }

    function isAuthorizedIssuer(address wallet) external view returns (bool) {
        return issuers[wallet].status == IssuerStatus.ACTIVE;
    }

    function getIssuer(address wallet) external view returns (Issuer memory) {
        return issuers[wallet];
    }

    function getIssuerStatus(address wallet) external view returns (IssuerStatus) {
        return issuers[wallet].status;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}