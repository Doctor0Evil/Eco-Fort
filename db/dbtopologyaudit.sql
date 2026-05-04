-- filename: dbtopologyaudit.sql
-- destination: Eco-Fort/db/dbtopologyaudit.sql
-- Topology risk auditing, manifest compliance tracking, and r_topology metric recording.
PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. Topology Audit Runs
-- Tracks scheduled and ad-hoc governance scans across the constellation.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS topology_audit_run (
    audit_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    run_utc           TEXT    NOT NULL,
    scope             TEXT    NOT NULL,          -- 'CONSTELLATION', 'ORG', 'BAND', 'REPO'
    scope_ref         TEXT,                      -- Org name, band, or repo_slug if scoped
    n_repos_scanned   INTEGER NOT NULL DEFAULT 0,
    n_missing_manifest INTEGER NOT NULL DEFAULT 0,
    n_mislabelled_role INTEGER NOT NULL DEFAULT 0,
    n_mislabelled_nonactuating INTEGER NOT NULL DEFAULT 0,
    i_topology_raw    REAL    NOT NULL,          -- Raw inconsistency index
    r_topology_norm   REAL    NOT NULL CHECK(r_topology_norm >= 0.0 AND r_topology_norm <= 1.0),
    w_topology        REAL    NOT NULL DEFAULT 1.0, -- Weight from planeweightscontract
    auditor_did       TEXT    NOT NULL,
    status            TEXT    NOT NULL DEFAULT 'COMPLETED' CHECK(status IN('PENDING','RUNNING','COMPLETED','FAILED','CANCELLED')),
    UNIQUE(run_utc, scope, COALESCE(scope_ref, ''))
);

CREATE INDEX IF NOT EXISTS idx_topology_audit_scope_time 
ON topology_audit_run(scope, run_utc DESC);

CREATE INDEX IF NOT EXISTS idx_topology_audit_risk 
ON topology_audit_run(r_topology_norm DESC);

--------------------------------------------------------------------------------
-- 2. Topology Audit Issues
-- Granular findings per repo/layer that contribute to the audit run.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS topology_audit_issue (
    issue_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    audit_id          INTEGER NOT NULL REFERENCES topology_audit_run(audit_id) ON DELETE CASCADE,
    repo_slug         TEXT    NOT NULL,
    layer_name        TEXT,                      -- Optional: specific econet_layer
    issue_type        TEXT    NOT NULL CHECK(issue_type IN (
        'MISSING_MANIFEST', 'MISLABEL_ROLE', 'MISLABEL_NONACTUATING', 
        'SCHEMA_MISMATCH', 'LANE_CONFLICT', 'CONTRACT_VIOLATION'
    )),
    severity          TEXT    NOT NULL CHECK(severity IN ('INFO','WARN','BLOCKING')),
    description       TEXT,
    detected_utc      TEXT    NOT NULL,
    resolved_utc      TEXT,
    resolver_did      TEXT,
    UNIQUE(audit_id, repo_slug, COALESCE(layer_name, ''), issue_type)
);

CREATE INDEX IF NOT EXISTS idx_topology_issue_type_repo 
ON topology_audit_issue(issue_type, repo_slug);

CREATE INDEX IF NOT EXISTS idx_topology_issue_severity_resolved 
ON topology_audit_issue(severity, resolved_utc);

--------------------------------------------------------------------------------
-- 3. Topology Risk Metrics (Per-Shard/Per-Window)
-- Joins audit results into shard-level risk coordinates for residual computation.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS topology_risk_metric (
    metric_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    shard_id          TEXT    NOT NULL,          -- References shardinstance.shard_id
    region            TEXT,
    audit_id          INTEGER REFERENCES topology_audit_run(audit_id),
    r_topology        REAL    NOT NULL CHECK(r_topology >= 0.0 AND r_topology <= 1.0),
    w_topology        REAL    NOT NULL DEFAULT 1.0,
    vt_with_topology  REAL    NOT NULL,          -- V_core + w_topology * r_topology^2
    recorded_utc      TEXT    NOT NULL,
    UNIQUE(shard_id, region, recorded_utc)
);

CREATE INDEX IF NOT EXISTS idx_topology_metric_shard_time 
ON topology_risk_metric(shard_id, recorded_utc DESC);

CREATE INDEX IF NOT EXISTS idx_topology_metric_risk 
ON topology_risk_metric(r_topology DESC);
