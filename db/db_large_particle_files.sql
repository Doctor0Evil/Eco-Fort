-- filename: db_large_particle_files.sql
-- destination: Eco-Fort/db/db_large_particle_files.sql

PRAGMA foreign_keys = ON;

-- 1. Registry of large particle files (ALN/CSV/etc.) in the constellation.
CREATE TABLE IF NOT EXISTS large_particle_file (
    lpf_id            INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Link back to the generic file index and repo
    repo_name         TEXT NOT NULL,   -- e.g. 'EcoNet', 'Eco-Fort'
    rel_path          TEXT NOT NULL,   -- 'qpudatashards/particles/BigHydroShard2026v1.csv'
    file_ext          TEXT NOT NULL,   -- 'aln','csv','bmx','parquet', etc.
    dir_class         TEXT NOT NULL,   -- 'QPUDATASHARD','PARTICLE','SCHEMA','OTHER'

    -- Size and performance hints
    size_bytes        INTEGER NOT NULL,
    row_estimate      INTEGER,         -- estimated number of rows
    column_count      INTEGER,         -- number of logical columns
    line_length_hint  INTEGER,         -- approx avg bytes per line
    chunk_size_bytes  INTEGER,         -- recommended streaming chunk in bytes
    chunk_row_target  INTEGER,         -- recommended streaming chunk in rows

    -- Hashing and integrity strategy
    hash_strategy     TEXT NOT NULL,   -- 'SKIP','SAMPLE_BLOCKS','FULL_ONCE'
    hash_function     TEXT,            -- e.g. 'HEX_GENERIC'
    content_hash      TEXT,            -- hash of whole file (if computed)
    block_hash_count  INTEGER,         -- number of block hashes recorded
    last_hash_utc     TEXT,            -- when content_hash was last updated

    -- Token-cost / reasoning hints
    summary_level     TEXT NOT NULL,   -- 'NONE','BASIC','AGGREGATE','FULL_INDEX'
    summary_shard_ref TEXT,            -- ALN/CSV file containing precomputed summary
    schema_ref        TEXT,            -- ALN schema name (e.g. 'HydroShardPhoenix2026v1')
    particle_role     TEXT,            -- 'QPUDATASHARD','EVIDENCE','SIMULATION','GOVERNANCE'
    lyap_channel      TEXT,            -- 'hydraulics','materials','energy','dataquality', etc.

    -- Governance / usage hints
    non_actuating     INTEGER NOT NULL DEFAULT 1 CHECK (non_actuating IN (0,1)),
    preferred_consumer TEXT,           -- 'Virta-Sys','ecological-orchestrator', etc.
    notes             TEXT,

    created_utc       TEXT NOT NULL,
    updated_utc       TEXT NOT NULL,

    UNIQUE (repo_name, rel_path)
);

CREATE INDEX IF NOT EXISTS idx_lpf_repo_dir
    ON large_particle_file (repo_name, dir_class);

CREATE INDEX IF NOT EXISTS idx_lpf_channel_role
    ON large_particle_file (lyap_channel, particle_role, summary_level);

CREATE INDEX IF NOT EXISTS idx_lpf_hash_strategy
    ON large_particle_file (hash_strategy, hash_function);


-- 2. Optional block-level hashing and statistics for very large files.
CREATE TABLE IF NOT EXISTS large_particle_block (
    block_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    lpf_id            INTEGER NOT NULL
                          REFERENCES large_particle_file(lpf_id)
                          ON DELETE CASCADE,

    block_index       INTEGER NOT NULL,   -- 0..N-1, sequential
    offset_bytes      INTEGER NOT NULL,
    length_bytes      INTEGER NOT NULL,

    hash_value        TEXT,               -- block hash (if computed)
    row_count         INTEGER,            -- estimated rows in this block
    min_value_json    TEXT,               -- JSON/ALN of per-column minima (optional)
    max_value_json    TEXT,               -- per-column maxima (optional)
    aggregate_json    TEXT,               -- means, stddev, etc. (optional)

    last_scanned_utc  TEXT,

    UNIQUE (lpf_id, block_index)
);

CREATE INDEX IF NOT EXISTS idx_lpf_block_lpfid
    ON large_particle_block (lpf_id);
