-- filename: migrations/016_plane_weights.sql
-- Extends existing corridordefinition / ecosafety grammar (no parallel spine).

-- Per-plane weight and non-offsettable flags, per corridor contract.
CREATE TABLE IF NOT EXISTS planeweights_contract (
    contract_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    -- e.g. 'PhoenixEcosafetyContinuity2026v1', 'CyboquaticTrustAndEcoPlanes2026v1'
    contract_name   TEXT NOT NULL UNIQUE,
    version_tag     TEXT NOT NULL,
    description     TEXT,
    -- RoH anchor for this contract (ALN shard id / hash string, not a hash function).
    roh_anchor_hex  TEXT NOT NULL,
    -- Whether this contract is frozen (no UPDATE/DELETE allowed once =1).
    frozen          INTEGER NOT NULL DEFAULT 0 CHECK (frozen IN (0,1))
);

-- One row per risk plane under a contract.
CREATE TABLE IF NOT EXISTS planeweights_plane (
    plane_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    contract_id     INTEGER NOT NULL
                        REFERENCES planeweights_contract(contract_id)
                        ON DELETE CASCADE,
    -- 'energy','hydraulics','biology','carbon','materials','biodiversity','dataquality'
    plane_name      TEXT NOT NULL,
    -- Lyapunov weight w_j (>=0).
    weight          REAL NOT NULL CHECK (weight >= 0.0),
    -- True if this plane is non-offsettable once above gold band.
    non_offsettable INTEGER NOT NULL DEFAULT 0 CHECK (non_offsettable IN (0,1)),
    -- Optional soft/hard thresholds for non-compensation rules.
    gold_threshold  REAL,   -- e.g. 0.10
    hard_threshold  REAL,   -- e.g. 0.13
    UNIQUE (contract_id, plane_name)
);
CREATE INDEX IF NOT EXISTS idx_planeweights_plane_contract
    ON planeweights_plane (contract_id, plane_name);
