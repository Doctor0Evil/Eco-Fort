-- filename: db_ker_window_aggregates.sql
-- destination: Eco-Fort/db/db_ker_window_aggregates.sql
-- Time-windowed KER aggregation, residual trend analysis, and reward eligibility tracking.
PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. KER Window Definitions
-- Configures window lengths, aggregation methods, and lane-specific thresholds.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ker_window_definition (
    window_def_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    window_name         TEXT NOT NULL UNIQUE,   -- e.g., 'SHORT_7D', 'MEDIUM_90D', 'LONG_365D'
    duration_days       REAL NOT NULL CHECK(duration_days > 0),
    aggregation_method  TEXT NOT NULL DEFAULT 'MEAN' CHECK(aggregation_method IN ('MEAN', 'MEDIAN', 'MIN', 'WEIGHTED_MEAN')),
    k_threshold         REAL NOT NULL CHECK(k_threshold BETWEEN 0.0 AND 1.0),
    e_threshold         REAL NOT NULL CHECK(e_threshold BETWEEN 0.0 AND 1.0),
    r_max_allowed       REAL NOT NULL CHECK(r_max_allowed BETWEEN 0.0 AND 1.0),
    residual_trend_max  REAL NOT NULL,          -- max allowed b (slope); <=0 for Lyapunov descent
    active              INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1))
);

--------------------------------------------------------------------------------
-- 2. KER Window Snapshots
-- Stores computed aggregates per shard/workload over a defined window.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ker_window_snapshot (
    snapshot_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    shard_id            TEXT NOT NULL,
    window_def_id       INTEGER NOT NULL REFERENCES ker_window_definition(window_def_id),
    window_start_utc    TEXT NOT NULL,
    window_end_utc      TEXT NOT NULL,
    k_avg               REAL NOT NULL CHECK(k_avg BETWEEN 0.0 AND 1.0),
    e_avg               REAL NOT NULL CHECK(e_avg BETWEEN 0.0 AND 1.0),
    r_max               REAL NOT NULL CHECK(r_max BETWEEN 0.0 AND 1.0),
    residual_start_v    REAL NOT NULL CHECK(residual_start_v >= 0.0),
    residual_end_v      REAL NOT NULL CHECK(residual_end_v >= 0.0),
    vt_trend_b          REAL,                   -- slope of V_t over window
    monotone_v_ok       INTEGER CHECK(monotone_v_ok IN (0,1)), -- 1 if vt_trend_b <= residual_trend_max + eps
    evidence_hex        TEXT NOT NULL,
    signing_did         TEXT NOT NULL,
    UNIQUE(shard_id, window_def_id, window_end_utc)
);

CREATE INDEX IF NOT EXISTS idx_ker_snapshot_shard_window ON ker_window_snapshot(shard_id, window_def_id, window_end_utc);
CREATE INDEX IF NOT EXISTS idx_ker_snapshot_lane_eligible ON ker_window_snapshot(k_avg, e_avg, r_max, monotone_v_ok);

--------------------------------------------------------------------------------
-- 3. Reward Eligibility Ledger
-- Tracks payout/reward eligibility based on window performance and monotonicity.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ker_reward_ledger (
    reward_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    shard_id            TEXT NOT NULL,
    window_end_utc      TEXT NOT NULL,
    eligibility_score   REAL NOT NULL CHECK(eligibility_score BETWEEN 0.0 AND 1.0),
    short_eligible      INTEGER NOT NULL DEFAULT 0,
    medium_eligible     INTEGER NOT NULL DEFAULT 0,
    long_eligible       INTEGER NOT NULL DEFAULT 0,
    payout_eligible     INTEGER NOT NULL DEFAULT 0 CHECK(payout_eligible IN (0,1)),
    payout_amount       REAL DEFAULT 0.0,
    payout_currency     TEXT DEFAULT 'ECO_SYS',
    payout_status       TEXT NOT NULL DEFAULT 'PENDING' CHECK(payout_status IN ('PENDING', 'DISBURSED', 'FORFEITED')),
    disbursement_utc    TEXT,
    audit_did           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ker_reward_shard_payout ON ker_reward_ledger(shard_id, payout_status, payout_eligible);

--------------------------------------------------------------------------------
-- 4. KER Trend & Stability Analysis
-- Stores longer-term stability metrics for governance dashboards and CI.
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ker_trend_analysis (
    analysis_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    shard_id            TEXT NOT NULL,
    analysis_timestamp_utc TEXT NOT NULL,
    rolling_k_trend     REAL,                   -- derivative of K over extended horizon
    rolling_e_trend     REAL,
    rolling_r_trend     REAL,
    volatility_index    REAL CHECK(volatility_index >= 0.0),
    stability_flag      TEXT NOT NULL DEFAULT 'STABLE' CHECK(stability_flag IN ('STABLE', 'DEGRADING', 'IMPROVING', 'OSCILLATING')),
    governance_recommendation TEXT,             -- e.g., 'PROMOTE_TO_PROD', 'RETAIN_RESEARCH', 'AUDIT_REQUIRED'
    computed_by_did     TEXT NOT NULL,
    evidence_hex        TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ker_trend_shard_time ON ker_trend_analysis(shard_id, analysis_timestamp_utc);
