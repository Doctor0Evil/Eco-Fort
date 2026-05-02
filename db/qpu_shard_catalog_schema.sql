-- filename: db/qpu_shard_catalog_schema.sql
-- destination: Eco-Fort/db/qpu_shard_catalog_schema.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS qpu_shard_catalog (
    shard_id        INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Filesystem and identity
    repo_name       TEXT NOT NULL,  -- e.g. 'EcoNet'
    rel_dir         TEXT NOT NULL,  -- e.g. 'qpudatashards/particles'
    file_name       TEXT NOT NULL,  -- e.g. 'CyboquaticEnergyMassPhoenix2026v1.aln'
    file_ext        TEXT NOT NULL,  -- 'aln','csv','bmx','pdf'
    content_hash    TEXT,           -- optional: hex hash of file contents
    size_bytes      INTEGER,        -- optional: file size on disk

    -- Semantic metadata for agents
    shard_title     TEXT,           -- short human-readable title
    shard_version   TEXT,           -- e.g. '2026v1','v1','2024-2026'
    shard_kind      TEXT NOT NULL,  -- 'QPUDATASHARD','SCHEMA','WORKFLOW','EVIDENCE','KPI','SIMULATION','DOC'
    primary_plane   TEXT,           -- e.g. 'hydraulics','energy','materials','biodiversity','dataquality','topology','finance'
    region          TEXT,           -- e.g. 'Phoenix-AZ','Global','Central-AZ'
    band_hint       TEXT,           -- 'SPINE','RESEARCH','ENGINE','MATERIAL','GOV','APP'
    lane_hint       TEXT,           -- 'RESEARCH','EXPPROD','PROD','ARCHIVE'
    time_span       TEXT,           -- e.g. '2024-2026','2026Q1','20260103T221700Z'

    -- Wiring hints for code generation
    preferred_consumer TEXT,        -- e.g. 'Virta-Sys','Eco-Fort','EcoNet-CEIM-PhoenixWater'
    preferred_role     TEXT,        -- e.g. 'INGEST','KERNEL_INPUT','KERNEL_OUTPUT','GOVERNANCE_LOG','DASHBOARD_SOURCE'
    schema_ref         TEXT,        -- e.g. 'EcoNetSchemaShard2026v2.aln','IngestRcalibPhoenix2026v1.aln'
    notes              TEXT,        -- free-form hints for agents: how to use this shard

    -- Governance fields
    created_utc     TEXT,           -- when this catalog entry was created
    updated_utc     TEXT,           -- last metadata update
    active          INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),

    UNIQUE (repo_name, rel_dir, file_name)
);

CREATE INDEX IF NOT EXISTS idx_qpu_shard_repo_dir
    ON qpu_shard_catalog (repo_name, rel_dir);

CREATE INDEX IF NOT EXISTS idx_qpu_shard_kind_plane_region
    ON qpu_shard_catalog (shard_kind, primary_plane, region);

CREATE INDEX IF NOT EXISTS idx_qpu_shard_schema_ref
    ON qpu_shard_catalog (schema_ref);
