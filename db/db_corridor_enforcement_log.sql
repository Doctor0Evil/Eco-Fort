-- filename: db_corridor_enforcement_log.sql
-- destination: Eco-Fort/db/db_corridor_enforcement_log.sql
-- Corridor enforcement logging, violation tracking, and automated governance actions.
PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. Corridor Evaluation Log
-- Tracks every corridor compliance check against a shard or workload.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS corridor_check_log (
    check_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    shard_id            TEXT NOT NULL,
    varid               TEXT NOT NULL,          -- e.g., 'HYDRAULICS.TURBIDITY_NTU'
    check_timestamp_utc TEXT NOT NULL,
    expected_band       TEXT NOT NULL CHECK(expected_band IN ('SAFE', 'GOLD', 'HARD')),
    actual_value        REAL NOT NULL,
    normalized_r_value  REAL NOT NULL CHECK(normalized_r_value BETWEEN 0.0 AND 1.0),
    plane_contract_id   INTEGER,
    evaluation_result   TEXT NOT NULL CHECK(evaluation_result IN ('COMPLIANT', 'VIOLATION', 'UNKNOWN')),
    evaluator_did       TEXT NOT NULL,          -- DID of agent/system that performed the check
    evidence_hex        TEXT NOT NULL,          -- hexstamp of inputs/state at evaluation time
    UNIQUE(shard_id, varid, check_timestamp_utc)
);

CREATE INDEX IF NOT EXISTS idx_corridor_check_shard_time ON corridor_check_log(shard_id, check_timestamp_utc);
CREATE INDEX IF NOT EXISTS idx_corridor_check_result ON corridor_check_log(evaluation_result);

--------------------------------------------------------------------------------
-- 2. Violation Records & Severity Mapping
-- Captures details when a check fails or crosses gold/hard thresholds.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS corridor_violation_record (
    violation_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    check_id            INTEGER NOT NULL REFERENCES corridor_check_log(check_id) ON DELETE CASCADE,
    severity            TEXT NOT NULL CHECK(severity IN ('INFO', 'WARNING', 'CRITICAL', 'BLOCKING')),
    threshold_breach    REAL NOT NULL,          -- actual_value - hard_band_limit or similar
    nonoffsettable      INTEGER NOT NULL DEFAULT 0 CHECK(nonoffsettable IN (0,1)),
    auto_resolved       INTEGER NOT NULL DEFAULT 0 CHECK(auto_resolved IN (0,1)),
    resolution_action   TEXT,                   -- e.g., 'LANE_DEMOTE', 'QUARANTINE', 'MANUAL_REVIEW'
    resolved_utc        TEXT,
    resolver_did        TEXT,
    notes               TEXT
);

CREATE INDEX IF NOT EXISTS idx_corridor_violation_severity ON corridor_violation_record(severity, nonoffsettable);

--------------------------------------------------------------------------------
-- 3. Enforcement Action Ledger
-- Records governance actions triggered by violations or scheduled audits.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS corridor_enforcement_action (
    action_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    violation_id        INTEGER REFERENCES corridor_violation_record(violation_id) ON DELETE SET NULL,
    shard_id            TEXT NOT NULL,
    action_type         TEXT NOT NULL CHECK(action_type IN (
        'LANE_DOWNGRADE', 'QUARANTINE', 'EVIDENCE_REJECT', 
        'MANUAL_OVERRIDE', 'AUTO_CORRECT', 'NOTIFY_STAKEHOLDER'
    )),
    previous_lane       TEXT,
    new_lane            TEXT,
    triggered_by        TEXT NOT NULL,          -- 'AUTO_GOVERNOR', 'CI_PIPELINE', 'HUMAN_ADMIN'
    authorized_by_did   TEXT,
    action_timestamp_utc TEXT NOT NULL,
    policy_ref          TEXT,                   -- e.g., 'lane.governance.v1.aln#nonoffsettable_rule'
    evidence_hex        TEXT NOT NULL,
    status              TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'EXECUTED', 'FAILED', 'REVERTED'))
);

CREATE INDEX IF NOT EXISTS idx_enforcement_shard_lane ON corridor_enforcement_action(shard_id, new_lane, status);
