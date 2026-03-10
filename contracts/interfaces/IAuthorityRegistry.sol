// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAuthorityRegistry {
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

    function isAuthorizedIssuer(address wallet) external view returns (bool);
    function getIssuer(address wallet) external view returns (Issuer memory);
    function getIssuerStatus(address wallet) external view returns (IssuerStatus);
    function ROOT_AUTHORITY_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
}