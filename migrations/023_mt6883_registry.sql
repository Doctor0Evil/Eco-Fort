-- filename: migrations/023_mt6883_registry.sql

CREATE TABLE IF NOT EXISTS mt6883_registry (
    registry_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    -- Link back to the generic shardinstance.
    shardid           INTEGER NOT NULL
                         REFERENCES shardinstance(shardid)
                         ON DELETE CASCADE,
    -- ALN particle name / schema, e.g. 'MT6883.PatientVaultShard.v1'
    particle_name     TEXT NOT NULL,
    -- High-level category: 'HEALTHCARE','LARGEPARTICLE'
    category          TEXT NOT NULL
                         CHECK (category IN ('HEALTHCARE','LARGEPARTICLE')),
    -- RoH (Rule-of-History) fields.
    roh_valid_from    TEXT NOT NULL, -- ISO8601
    roh_valid_until   TEXT,          -- nullable open-ended
    roh_chain_hex     TEXT NOT NULL, -- append-only provenance string
    -- Rights-of-harm coordinate (0..1), normalized via corridors.
    roh_risk          REAL NOT NULL CHECK (roh_risk >= 0.0 AND roh_risk <= 1.0),
    -- Summary eco-safety metadata for quick querying.
    saferoute_tag     TEXT,          -- e.g., 'NON_TOXIC','RESTRICTED','CRITICAL'
    ker_band          TEXT,          -- 'SAFE','GUARDED','BLOCKED'
    -- Bostrom DID for the registry maintainer.
    maintainer_did    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_mt6883_shard
    ON mt6883_registry (shardid, category);
CREATE INDEX IF NOT EXISTS idx_mt6883_roh
    ON mt6883_registry (roh_risk, roh_valid_until);
