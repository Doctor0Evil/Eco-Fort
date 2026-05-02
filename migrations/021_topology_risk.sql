-- filename: migrations/021_topology_risk.sql

CREATE TABLE IF NOT EXISTS topology_misalign_diag (
    diag_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    -- Scope: e.g. 'REPO', 'SHARD', 'NODE'
    scopetype        TEXT NOT NULL CHECK (scopetype IN ('REPO','SHARD')),
    scoperefid       INTEGER NOT NULL,
    n_mislabel       INTEGER NOT NULL DEFAULT 0 CHECK (n_mislabel >= 0),
    n_missing        INTEGER NOT NULL DEFAULT 0 CHECK (n_missing >= 0),
    w_mislabel       REAL NOT NULL CHECK (w_mislabel >= 0.0),
    w_missing        REAL NOT NULL CHECK (w_missing >= 0.0),
    itopology_raw    REAL NOT NULL CHECK (itopology_raw >= 0.0),
    rtopology        REAL NOT NULL CHECK (rtopology >= 0.0 AND rtopology <= 1.0),
    timestamputc     TEXT NOT NULL,
    issuedby         TEXT NOT NULL,
    roh_anchor_hex   TEXT
);
CREATE INDEX IF NOT EXISTS idx_topology_scope
    ON topology_misalign_diag (scopetype, scoperefid);
