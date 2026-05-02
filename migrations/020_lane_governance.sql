-- filename: migrations/020_lane_governance.sql

CREATE TABLE IF NOT EXISTS lanestatus_verdict (
    verdict_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    shardid           INTEGER NOT NULL
                         REFERENCES shardinstance(shardid)
                         ON DELETE CASCADE,
    nodeid            TEXT NOT NULL,
    current_lane      TEXT NOT NULL
                         CHECK (current_lane IN ('RESEARCH','EXPPROD','PROD')),
    proposed_lane     TEXT NOT NULL
                         CHECK (proposed_lane IN ('RESEARCH','EXPPROD','PROD')),
    kmetric           REAL NOT NULL,
    emetric           REAL NOT NULL,
    rmetric           REAL NOT NULL,
    vtmax             REAL NOT NULL,
    evidence_window_ms INTEGER NOT NULL,
    decision          TEXT NOT NULL
                         CHECK (decision IN ('APPROVE','REJECT','HOLD')),
    rationale         TEXT,
    timestamputc      TEXT NOT NULL,
    issuedby          TEXT NOT NULL,   -- DID/DID-agent
    -- RoH / ALN anchor for this decision window.
    roh_anchor_hex    TEXT
);
CREATE INDEX IF NOT EXISTS idx_lanestatus_shard
    ON lanestatus_verdict (shardid, timestamputc);
CREATE INDEX IF NOT EXISTS idx_lanestatus_decision
    ON lanestatus_verdict (decision, proposed_lane);
