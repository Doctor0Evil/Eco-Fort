-- filename db_blastradius_index.sql
-- destination Eco-Fort/db/db_blastradius_index.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS blastradius_object (
    bro_id            INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Link back to spine: which shard / node / virtual node this describes
    scope_type        TEXT NOT NULL,  -- SHARD, NODE, VNODE, REPO
    scope_ref         TEXT NOT NULL,  -- e.g. shardid, nodeid, qpulogicalid, reponame

    -- Geometric / topological footprint (safe-to-display)
    center_region     TEXT NOT NULL,  -- Phoenix-AZ, Central-AZ, Global, HostLocal
    center_node       TEXT,           -- CAP-LP-HBUF-01, PHX-HYDRO-LANE-01, mt6883-handset-2026
    radius_meters     REAL,           -- approximate physical radius if applicable
    radius_hops       INTEGER,        -- graph hops in node adjacency
    radius_time_hours REAL,           -- time horizon of effect (e.g. hydrological travel, treatment course)

    -- Eco-planes and KER band summary
    primary_plane     TEXT NOT NULL,  -- hydraulics, energy, materials, biodiversity, health, dataquality, topology, finance
    secondary_planes  TEXT,           -- comma-separated other planes touched
    k_band            TEXT NOT NULL,  -- HIGH, MEDIUM, LOW (knowledge factor)
    e_band            TEXT NOT NULL,  -- HIGH, MEDIUM, LOW (eco-impact)
    r_band            TEXT NOT NULL,  -- LOW, MEDIUM, HIGH (risk-of-harm)
    vt_residual_est   REAL,           -- representative V_t in 0..1 window for this object

    -- Neighboring zones and blast radius pattern, as safe-to-display text
    neighbor_zones    TEXT,           -- e.g. "UPSTREAM:PHX-HYDRO-02;DOWNSTREAM:PHX-HYDRO-03;ADJ-STREET:PHX-STR-12"
    neighbor_count    INTEGER,        -- how many neighbors in the active set
    continuity_grade  TEXT,           -- A,B,C continuity classification for VNODE or NODE
    nonactuating_only INTEGER NOT NULL DEFAULT 1 CHECK (nonactuating_only IN (0,1)),

    -- Metaphysical properties: sovereignty, governance, metaphysical "color"
    sovereignty_tag   TEXT,           -- e.g. "SOVEREIGN-LOCAL", "MULTI-JURIS", "LEDGER-ANCHORED"
    governance_profile TEXT,          -- e.g. "OBSERVEONLY", "OKTOPLAN", "GOVONLY"
    metaphysical_code TEXT,           -- short label: "HEALTH-DET0X", "HYDRO-BUFFER", "NANOSWARM-COURSE"

    -- Hex-encoded summary template for fast reuse
    hex_descriptor    TEXT NOT NULL,  -- compact hex encoding of key fields (see below)
    descriptor_version TEXT NOT NULL DEFAULT 'BR2026v1',

    created_utc       TEXT NOT NULL,
    updated_utc       TEXT NOT NULL,

    UNIQUE(scope_type, scope_ref)
);

CREATE INDEX IF NOT EXISTS idx_bro_scope
    ON blastradius_object (scope_type, scope_ref);

CREATE INDEX IF NOT EXISTS idx_bro_region_plane
    ON blastradius_object (center_region, primary_plane);

CREATE INDEX IF NOT EXISTS idx_bro_ker_bands
    ON blastradius_object (k_band, e_band, r_band);

CREATE INDEX IF NOT EXISTS idx_bro_nonactuating
    ON blastradius_object (nonactuating_only);
