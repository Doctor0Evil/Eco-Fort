-- filename: dbmt6883registry.sql
-- destination: Eco-Fort/db/dbmt6883registry.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS mt6883registry (
    registry_id        INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Link to the canonical shard instance in the constellation spine.
    shard_id           INTEGER NOT NULL
                           REFERENCES shardinstance(shardid)
                           ON DELETE CASCADE,

    -- ALN particle identity for this MT6883-related shard.
    particle_name      TEXT NOT NULL,   -- e.g. nanoswarm.detox.corridor.v1
    schema_name        TEXT NOT NULL,   -- e.g. HealthcareCorridorVaultIndex2026v1.aln

    -- High-level category describing the MT6883 surface.
    -- HEALTHCARE: host-level healthcare / detox / telemetry shards
    -- LARGEPARTICLE: MT6883-related evidence largeparticle files
    category           TEXT NOT NULL
                           CHECK (category IN ('HEALTHCARE','LARGEPARTICLE')),

    -- Hardware affinity: which MT6883 profile this shard expects.
    hardware_family    TEXT NOT NULL,   -- e.g. MT6883
    hardware_profile   TEXT,            -- e.g. mt6883-handset-2026

    -- RoH Rule-of-History window for this shard's validity.
    roh_valid_from     TEXT NOT NULL,   -- ISO8601 UTC
    roh_valid_until    TEXT,            -- ISO8601 UTC, nullable when open-ended

    -- Append-only provenance chain anchoring RoH decisions for this shard.
    roh_chain_hex      TEXT NOT NULL,

    -- Normalized risk-of-harm for this shard in [0,1].
    roh_risk           REAL NOT NULL
                           CHECK (roh_risk >= 0.0 AND roh_risk <= 1.0),

    -- KER band and safe-routing tag for quick filtering.
    ker_band           TEXT NOT NULL
                           CHECK (ker_band IN ('SAFE','GUARDED','BLOCKED')),
    safe_route_tag     TEXT,            -- e.g. NONTOXIC, RESTRICTED, CRITICAL

    -- Lane continuity snapshot at the time of registration.
    lane               TEXT NOT NULL,   -- RESEARCH, EXPPROD, PROD, etc.
    continuity_grade   TEXT NOT NULL    -- e.g. A, B, C for node/vnode continuity

                         CHECK (continuity_grade IN ('A','B','C')),

    -- Last known Lyapunov residual estimate for this shard.
    vt_residual_est    REAL
                           CHECK (vt_residual_est IS NULL
                                  OR (vt_residual_est >= 0.0 AND vt_residual_est <= 1.0)),

    -- Optional linkage into blastradius for spatial/temporal continuity.
    broid              INTEGER
                           REFERENCES blastradiusobject(broid)
                           ON DELETE SET NULL,

    -- Governance and maintenance identity.
    maintainer_did     TEXT NOT NULL,

    -- Lifecycle timestamps.
    created_utc        TEXT NOT NULL,
    updated_utc        TEXT NOT NULL,

    -- Active flag for registry rows (soft delete).
    active             INTEGER NOT NULL DEFAULT 1
                           CHECK (active IN (0,1)),

    UNIQUE (shard_id, category)
);

CREATE INDEX IF NOT EXISTS idx_mt6883_shard
    ON mt6883registry (shard_id, category);

CREATE INDEX IF NOT EXISTS idx_mt6883_roh_window
    ON mt6883registry (roh_risk, roh_valid_until);

CREATE INDEX IF NOT EXISTS idx_mt6883_lane_continuity
    ON mt6883registry (lane, continuity_grade, ker_band, active);

CREATE INDEX IF NOT EXISTS idx_mt6883_blast
    ON mt6883registry (broid);
