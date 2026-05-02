-- filename: db_lane_governance.sql
-- destination: Virta-Sys/db/db_lane_governance.sql
-- Purpose: Evidence-based lane promotion (RESEARCH → EXPPROD → PROD)

PRAGMA foreign_keys = ON;

-- ==============================================================================
-- 1. LANE POLICY (Rules for promotion)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS lane_policy (
    policy_id INTEGER PRIMARY KEY AUTOINCREMENT,
    policy_name TEXT NOT NULL UNIQUE,
    source_lane TEXT NOT NULL CHECK(source_lane IN ('RESEARCH', 'EXPPROD')),
    target_lane TEXT NOT NULL CHECK(target_lane IN ('EXPPROD', 'PROD')),

    -- Evidence window requirements
    min_window_hours INTEGER NOT NULL,
    min_shard_count INTEGER NOT NULL,

    -- KER thresholds
    k_min REAL NOT NULL CHECK(k_min >= 0.0 AND k_min <= 1.0),
    e_min REAL NOT NULL CHECK(e_min >= 0.0 AND e_min <= 1.0),
    r_max REAL NOT NULL CHECK(r_max >= 0.0 AND r_max <= 1.0),

    -- Residual trend requirement
    vt_trend_max REAL NOT NULL DEFAULT 0.0, -- Non-positive for safestep

    -- Error tolerance
    error_rate_max REAL NOT NULL DEFAULT 0.0,

    description TEXT,
    created_utc TEXT NOT NULL,
    updated_utc TEXT NOT NULL
);

-- Seed standard policies
INSERT OR IGNORE INTO lane_policy (policy_name, source_lane, target_lane, min_window_hours, min_shard_count, k_min, e_min, r_max, vt_trend_max, error_rate_max, description, created_utc, updated_utc) VALUES
('RESEARCH_TO_EXPPROD', 'RESEARCH', 'EXPPROD', 168, 10, 0.88, 0.88, 0.15, 0.0, 0.02, 'Standard RESEARCH to EXPPROD promotion', '2026-05-02T20:00:00Z', '2026-05-02T20:00:00Z'),
('EXPPROD_TO_PROD', 'EXPPROD', 'PROD', 336, 20, 0.94, 0.90, 0.12, 0.0, 0.0, 'Standard EXPPROD to PROD promotion', '2026-05-02T20:00:00Z', '2026-05-02T20:00:00Z');

-- ==============================================================================
-- 2. LANE DECISION LOG (Virta-Sys evaluation results)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS lanedecision (
    decision_id INTEGER PRIMARY KEY AUTOINCREMENT,
    reponame TEXT NOT NULL,
    layername TEXT,
    kernelid TEXT NOT NULL,
    region TEXT NOT NULL,

    -- Evidence window
    t_start_utc TEXT NOT NULL,
    t_end_utc TEXT NOT NULL,
    shard_count INTEGER NOT NULL,

    -- Aggregate KER
    k_avg REAL NOT NULL,
    e_avg REAL NOT NULL,
    r_avg REAL NOT NULL,
    vt_trend REAL NOT NULL,

    -- Policy thresholds met
    policy_id INTEGER NOT NULL REFERENCES lane_policy(policy_id),
    corridor_ok INTEGER NOT NULL CHECK(corridor_ok IN (0,1)),
    planes_ok INTEGER NOT NULL CHECK(planes_ok IN (0,1)),
    topology_ok INTEGER NOT NULL CHECK(topology_ok IN (0,1)),

    -- Result
    target_lane TEXT NOT NULL CHECK(target_lane IN ('EXPPROD', 'PROD')),
    admissible INTEGER NOT NULL CHECK(admissible IN (0,1)),
    rationale TEXT,

    created_utc TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lanedec_kernel ON lanedecision(reponame, kernelid, region);

-- ==============================================================================
-- 3. VIRTA LANE VERDICT (Final authoritative decision)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS virtalaneverdict (
    verdict_id INTEGER PRIMARY KEY AUTOINCREMENT,
    decision_id INTEGER NOT NULL UNIQUE REFERENCES lanedecision(decision_id),
    verdict TEXT NOT NULL CHECK(verdict IN ('Admissible', 'Denied')),
    issuing_system TEXT NOT NULL DEFAULT 'Virta-Sys',
    issued_utc TEXT NOT NULL,
    evidence_hex TEXT -- Hash of supporting shard instances
);

CREATE INDEX IF NOT EXISTS idx_verdict_decision ON virtalaneverdict(decision_id);

-- End of db_lane_governance.sql
