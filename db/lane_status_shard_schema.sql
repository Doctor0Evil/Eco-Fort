-- filename: db/lane_status_shard_schema.sql
-- destination: Eco-Fort/db/lane_status_shard_schema.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS lane_status_shard (
    shard_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name        TEXT NOT NULL,
    layer_name       TEXT NOT NULL,
    kernel_id        INTEGER NOT NULL,
    region           TEXT NOT NULL,           -- 'Phoenix-AZ','*', etc.
    lane             TEXT NOT NULL CHECK (lane IN ('RESEARCH','EXPPROD','PROD')),
    lane_source      TEXT NOT NULL,           -- 'Virta-Sys:lane-governor'
    lane_reason      TEXT NOT NULL,

    window_start_utc TEXT NOT NULL,
    window_end_utc   TEXT NOT NULL,
    evidence_count   INTEGER NOT NULL,

    k_avg            REAL NOT NULL,
    e_avg            REAL NOT NULL,
    r_avg            REAL NOT NULL,
    vt_trend         REAL NOT NULL,

    k_min_required   REAL NOT NULL,
    e_min_required   REAL NOT NULL,
    r_max_allowed    REAL NOT NULL,

    corridor_ok      INTEGER NOT NULL CHECK (corridor_ok IN (0,1)),
    planes_ok        INTEGER NOT NULL CHECK (planes_ok IN (0,1)),
    topology_ok      INTEGER NOT NULL CHECK (topology_ok IN (0,1)),

    evidence_hex     TEXT NOT NULL,
    signing_did      TEXT NOT NULL,

    created_utc      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lane_status_kernel_region
    ON lane_status_shard (kernel_id, region, lane);

CREATE INDEX IF NOT EXISTS idx_lane_status_repo_layer
    ON lane_status_shard (repo_name, layer_name, region);
