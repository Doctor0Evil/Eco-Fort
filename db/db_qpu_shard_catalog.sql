-- filename db_qpu_shard_catalog.sql
-- destination Eco-Fort/db/db_qpu_shard_catalog.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS qpu_shard_catalog (
    shard_id              INTEGER PRIMARY KEY AUTOINCREMENT,

    -- File identity and placement
    repo_target           TEXT NOT NULL,   -- e.g. 'EcoNet', 'Virta-Sys'
    destination_path      TEXT NOT NULL,   -- e.g. 'qpudatashards/qpu'
    filename              TEXT NOT NULL,   -- e.g. 'PhoenixQPUHydroLane2026v1.aln'
    file_ext              TEXT NOT NULL,   -- 'aln','csv','bmx','json', etc.
    content_hash          TEXT,            -- generic hash for integrity
    size_bytes            INTEGER,

    -- Semantic classification
    shard_title           TEXT,            -- human-readable title
    shard_kind            TEXT NOT NULL,   -- 'STATE','TRACE','PLAN','KERNEL_IO','GOV_LOG'
    primary_plane         TEXT,            -- 'hydraulics','energy','materials','topology', etc.
    region                TEXT,            -- 'Phoenix-AZ','Central-AZ','Global', etc.
    timespan              TEXT,            -- '2026Q1','2024-2026','20260103T221700Z'
    version_label         TEXT,            -- '2026v1','v1','beta1'

    -- Virtual hardware binding (logical QPU / MT6883, etc.)
    qpu_logical_id        TEXT,            -- logical qpu / virtual-core id
    hardware_family       TEXT,            -- 'MT6883','ARM','x86_64', etc.
    hardware_profile      TEXT,            -- 'mt6883-handset-v1','phoenix-rack-01'
    vcore_count           INTEGER,         -- virtual compute lanes
    memory_qubits         INTEGER,         -- logical qubit capacity (or 0 if not applicable)
    vram_mebibytes        INTEGER,         -- virtual memory size for the shard workload

    -- Virtual filesystem / operation semantics
    vfs_namespace         TEXT,            -- 'qpu://phoenix/hydraulics', etc.
    vfs_op_code           TEXT,            -- 'VOP_OPEN_SHARD','VOP_ROUTE_ENERGY', etc.
    vfs_op_kind           TEXT,            -- 'READ','WRITE','TRANSFORM','ROUTE','SNAPSHOT'
    vfs_contract          TEXT,            -- 'NON_ACTUATING','ACTUATOR_SAFE','GOV_LOG'
    required_inputs       TEXT,            -- ALN schema / struct names expected as inputs
    emitted_outputs       TEXT,            -- ALN schema / struct names produced

    -- Ecosystem, energy-routing, and maintenance semantics
    energy_domain         TEXT,            -- 'electric','hydraulic','thermal','logistical'
    energy_lane           TEXT,            -- corridor / lane id, e.g. 'PHX-HYDRO-LANE-01'
    maintenance_role      TEXT,            -- 'SENSOR_FEED','SCHEDULE_JOB','ALERT_STREAM'
    cost_reduction_score  REAL,            -- 0.0–1.0 heuristic for cost-reduction leverage
    uptime_class          TEXT,            -- 'ALWAYS_ON','BEST_EFFORT','BATCH'

    -- Psychological continuity & augmented citizens (MT6883, etc.)
    citizen_id            TEXT,            -- pseudonymous, stable citizen id
    augmentation_profile  TEXT,            -- 'mt6883-handset','mt6883-hud','mt6883-rig'
    continuity_contract   TEXT,            -- policy id, e.g. 'NEURO_CONTINUITY_AZ_2026'
    continuity_window_secs INTEGER,        -- minimum guaranteed continuous-experience window
    continuity_state_ref  TEXT,            -- ALN shard that stores continuity/neurostate refs

    -- Governance metadata
    created_utc           TEXT NOT NULL,   -- ISO-8601 creation time
    updated_utc           TEXT NOT NULL,   -- ISO-8601 last update
    active                INTEGER NOT NULL DEFAULT 1
                               CHECK (active IN (0,1)),

    UNIQUE (repo_target, destination_path, filename)
);

-- Indexes tuned for Virta-Sys and agent queries

CREATE INDEX IF NOT EXISTS idx_qpu_shard_repo_path
    ON qpu_shard_catalog (repo_target, destination_path);

CREATE INDEX IF NOT EXISTS idx_qpu_shard_kind_plane_region
    ON qpu_shard_catalog (shard_kind, primary_plane, region);

CREATE INDEX IF NOT EXISTS idx_qpu_shard_vfs_op
    ON qpu_shard_catalog (vfs_namespace, vfs_op_code, vfs_op_kind);

CREATE INDEX IF NOT EXISTS idx_qpu_shard_hardware
    ON qpu_shard_catalog (qpu_logical_id, hardware_family);

CREATE INDEX IF NOT EXISTS idx_qpu_shard_citizen
    ON qpu_shard_catalog (citizen_id, augmentation_profile);
