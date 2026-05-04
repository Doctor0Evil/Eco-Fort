-- filename: db_evidence_provenance_chain.sql
-- destination: Eco-Fort/db/db_evidence_provenance_chain.sql
-- Append-only cryptographic provenance chains for shards, artifacts, and governance decisions.
PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. Provenance Chain Roots
-- Tracks the current tip of the hash chain for each tracked entity.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS provenance_chain_root (
    entity_type         TEXT NOT NULL,          -- 'SHARD', 'ARTIFACT', 'LANE_DECISION', 'TOPOLOGY_AUDIT'
    entity_id           TEXT NOT NULL,
    latest_link_id      INTEGER,                -- FK to provenance_link
    chain_hash          TEXT,                   -- Cumulative Merkle/root hash for fast verification
    last_updated_utc    TEXT NOT NULL,
    signing_did         TEXT NOT NULL,
    PRIMARY KEY (entity_type, entity_id)
);

--------------------------------------------------------------------------------
-- 2. Provenance Link (Append-Only Chain)
-- Each row is a cryptographic link. Immutability enforced by parent_hash.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS provenance_link (
    link_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_hash         TEXT,                   -- NULL for genesis block
    self_hash           TEXT NOT NULL,          -- SHA2/256 of (parent_hash + payload + metadata)
    entity_type         TEXT NOT NULL,
    entity_id           TEXT NOT NULL,
    payload_type        TEXT NOT NULL,          -- 'METRICS', 'CONFIG', 'GOVERNANCE_VERDICT', 'CI_RUN'
    payload_hex         BLOB,                   -- Serialized ALN/JSON payload
    timestamp_utc       TEXT NOT NULL,
    signer_did          TEXT NOT NULL,
    verification_status TEXT NOT NULL DEFAULT 'UNVERIFIED' CHECK(verification_status IN ('UNVERIFIED', 'VERIFIED', 'TAMPER_DETECTED')),
    UNIQUE(entity_type, entity_id, self_hash)
);

CREATE INDEX IF NOT EXISTS idx_provenance_link_entity_time ON provenance_link(entity_type, entity_id, timestamp_utc);
CREATE INDEX IF NOT EXISTS idx_provenance_link_parent ON provenance_link(parent_hash);

--------------------------------------------------------------------------------
-- 3. Verification Audit Log
-- Records attempts to validate chain integrity, used for CI and governance checks.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS provenance_verification_audit (
    audit_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type         TEXT NOT NULL,
    entity_id           TEXT NOT NULL,
    audit_timestamp_utc TEXT NOT NULL,
    audited_by_did      TEXT NOT NULL,
    chain_length        INTEGER NOT NULL,
    integrity_ok        INTEGER NOT NULL CHECK(integrity_ok IN (0,1)),
    failure_details     TEXT,                   -- e.g., 'HASH_MISMATCH_AT_LINK_42'
    notes               TEXT
);

CREATE INDEX IF NOT EXISTS idx_provenance_audit_integrity ON provenance_verification_audit(entity_type, entity_id, integrity_ok);
