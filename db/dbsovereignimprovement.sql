-- filename: dbsovereignimprovement.sql
-- destination: Eco-Fort/db/dbsovereignimprovement.sql
-- Sovereign improvement ledger for monotone K/E/R upgrades and Lyapunov validation.
PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. Sovereign Upgrade Ledger
-- Core record of before/after metrics, monotonicity checks, and authorization.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sovereign_upgrade_ledger (
    upgrade_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    target_type       TEXT    NOT NULL CHECK(target_type IN ('REPO','SCHEMA','WORKLOAD','KERNEL','CORRIDOR')),
    target_ref        TEXT    NOT NULL,          -- Repo slug, schema_name, or workload_id
    version_from      TEXT,
    version_to        TEXT,
    initiated_utc     TEXT    NOT NULL,
    -- Before window metrics
    k_before          REAL    NOT NULL,
    e_before          REAL    NOT NULL,
    r_before          REAL    NOT NULL,
    vt_before         REAL    NOT NULL,
    -- After window metrics
    k_after           REAL    NOT NULL,
    e_after           REAL    NOT NULL,
    r_after           REAL    NOT NULL,
    vt_after          REAL    NOT NULL,
    -- Invariant checks
    monotone_ok       INTEGER NOT NULL CHECK(monotone_ok IN (0,1)),
    lyapunov_ok       INTEGER NOT NULL CHECK(lyapunov_ok IN (0,1)),
    residual_tolerance REAL  NOT NULL DEFAULT 1e-6,
    -- Governance & provenance
    authorized_did    TEXT    NOT NULL,
    evidence_before_hex TEXT,
    evidence_after_hex  TEXT,
    status            TEXT    NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','APPROVED','REJECTED','MERGED','ROLLED_BACK_DENIED')),
    UNIQUE(target_type, target_ref, version_to, initiated_utc)
);

-- CHECK constraint logic (enforced via app/CI, but schema documents the invariant):
-- monotone_ok = (k_after >= k_before AND e_after >= e_before AND r_after <= r_before)
-- lyapunov_ok = (vt_after <= vt_before + residual_tolerance)

CREATE INDEX IF NOT EXISTS idx_upgrade_ledger_target 
ON sovereign_upgrade_ledger(target_type, target_ref, initiated_utc DESC);

CREATE INDEX IF NOT EXISTS idx_upgrade_ledger_monotone 
ON sovereign_upgrade_ledger(monotone_ok, lyapunov_ok, status);

--------------------------------------------------------------------------------
-- 2. Upgrade Evidence Windows
-- Stores the granular K/E/R/Vt snapshots that compose the before/after windows.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sovereign_upgrade_evidence (
    evidence_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    upgrade_id        INTEGER NOT NULL REFERENCES sovereign_upgrade_ledger(upgrade_id) ON DELETE CASCADE,
    window_label      TEXT    NOT NULL,          -- 'BEFORE_BASELINE','BEFORE_TEST','AFTER_PILOT','AFTER_PROD'
    shard_ref         TEXT    NOT NULL,          -- shard_id or region reference
    k_obs             REAL    NOT NULL,
    e_obs             REAL    NOT NULL,
    r_obs             REAL    NOT NULL,
    v_obs             REAL    NOT NULL,
    observed_utc      TEXT    NOT NULL,
    UNIQUE(upgrade_id, window_label, shard_ref)
);

CREATE INDEX IF NOT EXISTS idx_upgrade_evidence_window 
ON sovereign_upgrade_evidence(upgrade_id, window_label);

--------------------------------------------------------------------------------
-- 3. Upgrade Gate Status
-- CI/CD and governance checkpoints that must pass before a merge/deployment.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sovereign_upgrade_gates (
    gate_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    upgrade_id        INTEGER NOT NULL REFERENCES sovereign_upgrade_ledger(upgrade_id) ON DELETE CASCADE,
    gate_name         TEXT    NOT NULL,          -- 'KER_MONOTONICITY', 'LYAPUNOV_DESCENT', 'TOPOLOGY_OK', 'CONTRACTS_VERIFIED', 'LANE_COMPATIBLE'
    passed            INTEGER NOT NULL CHECK(passed IN (0,1)),
    checked_utc       TEXT    NOT NULL,
    notes             TEXT,
    UNIQUE(upgrade_id, gate_name)
);

CREATE INDEX IF NOT EXISTS idx_upgrade_gates_status 
ON sovereign_upgrade_gates(passed, checked_utc DESC);
