-- filename: dbnonactuatingcontracts.sql
-- destination: Eco-Fort/db/dbnonactuatingcontracts.sql
-- Non-actuating contract registry, dependency scanning, and CI verification logs.
PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. Non-Actuating Contract Registry
-- Declares and tracks the verification status of NonActuatingWorkload contracts.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nonactuating_contract_registry (
    contract_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_slug         TEXT    NOT NULL,
    layer_name        TEXT    NOT NULL,
    workload_id       TEXT    NOT NULL,          -- Stable identifier for the kernel/layer
    trait_name        TEXT    NOT NULL DEFAULT 'NonActuatingWorkload',
    declared_status   TEXT    NOT NULL CHECK(declared_status IN ('DECLARED','UNDISCLOSED')),
    verified_status   TEXT    NOT NULL DEFAULT 'UNVERIFIED' CHECK(verified_status IN ('UNVERIFIED','VERIFIED','FAILED','EXEMPT')),
    last_verified_utc TEXT,
    verifier_did      TEXT,
    ci_check_hash     TEXT,                      -- Hex hash of the CI scan job/output
    UNIQUE(repo_slug, layer_name, workload_id, trait_name)
);

CREATE INDEX IF NOT EXISTS idx_contract_registry_status 
ON nonactuating_contract_registry(verified_status, declared_status);

CREATE INDEX IF NOT EXISTS idx_contract_registry_workload 
ON nonactuating_contract_registry(workload_id);

--------------------------------------------------------------------------------
-- 2. Non-Actuating Dependency Scans
-- Records static analysis results: actuator paths, forbidden imports, FFI boundaries.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nonactuating_dependency_scan (
    scan_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    contract_id       INTEGER NOT NULL REFERENCES nonactuating_contract_registry(contract_id) ON DELETE CASCADE,
    scan_utc          TEXT    NOT NULL,
    tool_name         TEXT    NOT NULL,          -- e.g., 'cargo-audit', 'econet-contract-lint'
    actuator_paths_found INTEGER NOT NULL DEFAULT 0,
    forbidden_deps_found   INTEGER NOT NULL DEFAULT 0,
    ffi_boundary_violations INTEGER NOT NULL DEFAULT 0,
    dependency_tree_hex    TEXT,                  -- Compressed/hash of the resolved dep graph
    passed            INTEGER NOT NULL CHECK(passed IN (0,1)),
    notes             TEXT,
    UNIQUE(contract_id, scan_utc, tool_name)
);

CREATE INDEX IF NOT EXISTS idx_dep_scan_contract_time 
ON nonactuating_dependency_scan(contract_id, scan_utc DESC);

CREATE INDEX IF NOT EXISTS idx_dep_scan_pass_fail 
ON nonactuating_dependency_scan(passed);

--------------------------------------------------------------------------------
-- 3. Non-Actuating Verification Log
-- Immutable history of verification attempts, CI results, and overrides.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nonactuating_verification_log (
    log_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    contract_id       INTEGER NOT NULL REFERENCES nonactuating_contract_registry(contract_id),
    check_type        TEXT    NOT NULL,          -- 'STATIC_ANALYSIS', 'CI_BUILD', 'MANUAL_OVERRIDE', 'DEPLOY_GATE'
    result            TEXT    NOT NULL CHECK(result IN ('PASS','FAIL','SKIP','OVERRIDE')),
    evidence_hex      TEXT    NOT NULL,
    checked_utc       TEXT    NOT NULL,
    checker_did       TEXT    NOT NULL,
    failure_reason    TEXT
);

CREATE INDEX IF NOT EXISTS idx_verify_log_contract_result 
ON nonactuating_verification_log(contract_id, result, checked_utc DESC);
