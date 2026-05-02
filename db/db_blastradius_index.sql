-- filename: db_blastradius_index.sql
-- destination: Eco-Fort/db/db_blastradius_index.sql

PRAGMA foreign_keys = ON;

-- ==============================================================================
-- 1. NODE ADJACENCY GRAPH (Topology relationships)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS node_adjacency (
    edge_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    graph_name         TEXT NOT NULL,  -- HYDRO_PHOENIX, STREET_PHOENIX, HEALTH_ORGAN
    source_node        TEXT NOT NULL,
    target_node        TEXT NOT NULL,
    relationship_type  TEXT NOT NULL,  -- UPSTREAM, DOWNSTREAM, ADJACENT, FEEDS
    distance_meters    REAL,
    travel_time_hours  REAL,
    weight             REAL NOT NULL DEFAULT 1.0,
    created_utc        TEXT NOT NULL,
    UNIQUE (graph_name, source_node, target_node, relationship_type)
);

CREATE INDEX IF NOT EXISTS idx_node_adj_graph
    ON node_adjacency (graph_name);

CREATE INDEX IF NOT EXISTS idx_node_adj_source
    ON node_adjacency (source_node);

CREATE INDEX IF NOT EXISTS idx_node_adj_target
    ON node_adjacency (target_node);

-- ==============================================================================
-- 2. BLAST RADIUS OBJECT (Shard/Node influence footprint)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS blastradius_object (
    bro_id             INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Link back to spine scope
    scope_type         TEXT NOT NULL CHECK (scope_type IN ('SHARD','NODE','VNODE','REPO')),
    scope_ref          TEXT NOT NULL,  -- shardid, nodeid, vnodeid, or reponame

    -- Geometric / topological footprint
    center_region      TEXT NOT NULL,  -- Phoenix-AZ, Central-AZ, Global, HostLocal
    center_node        TEXT,           -- CAP-LP-HBUF-01, PHX-HYDRO-LANE-01, mt6883-handset-2026
    radius_meters      REAL,           -- approximate physical radius if applicable
    radius_hops        INTEGER,        -- graph hops in node_adjacency
    radius_time_hours  REAL,           -- time horizon of effect (e.g. hydrological travel, treatment course)

    -- Eco-planes and KER band summary
    primary_plane      TEXT NOT NULL,  -- hydraulics, energy, materials, biodiversity, health, dataquality, topology, finance
    secondary_planes   TEXT,           -- comma-separated other planes touched
    k_band             TEXT CHECK (k_band IN ('HIGH','MEDIUM','LOW')),
    e_band             TEXT CHECK (e_band IN ('HIGH','MEDIUM','LOW')),
    r_band             TEXT CHECK (r_band IN ('LOW','MEDIUM','HIGH')),
    vt_residual_est    REAL,           -- representative V_t in 0..1 window for this object

    -- Neighborhood view
    neighbor_zones     TEXT,           -- "UPSTREAM:PHX-HYDRO-02;DOWNSTREAM:PHX-HYDRO-03;ADJ-STREET:PHX-STR-12"
    neighbor_count     INTEGER,        -- how many neighbors in the active set

    -- Continuity and governance
    continuity_grade   TEXT,           -- A,B,C continuity classification for NODE or VNODE
    nonactuating_only  INTEGER NOT NULL DEFAULT 1 CHECK (nonactuating_only IN (0,1)),
    sovereignty_tag    TEXT,           -- SOVEREIGN-LOCAL, MULTI-JURIS, LEDGER-ANCHORED
    governance_profile TEXT,           -- OBSERVEONLY, OKTOPLAN, GOVONLY, NEEDSREVIEW
    metaphysical_code  TEXT,           -- short label: HEALTH-DET0X, HYDRO-BUFFER, etc.

    -- Compact hex descriptor for fast reuse
    hex_descriptor     TEXT NOT NULL,  -- compact hex encoding of key fields
    descriptor_version TEXT NOT NULL DEFAULT 'BR2026v1',

    created_utc        TEXT NOT NULL,
    updated_utc        TEXT NOT NULL,

    UNIQUE (scope_type, scope_ref)
);

CREATE INDEX IF NOT EXISTS idx_bro_scope
    ON blastradius_object (scope_type, scope_ref);

CREATE INDEX IF NOT EXISTS idx_bro_region_plane
    ON blastradius_object (center_region, primary_plane);

CREATE INDEX IF NOT EXISTS idx_bro_ker_bands
    ON blastradius_object (k_band, e_band, r_band);

CREATE INDEX IF NOT EXISTS idx_bro_governance
    ON blastradius_object (governance_profile, nonactuating_only);

CREATE INDEX IF NOT EXISTS idx_bro_hex_descriptor
    ON blastradius_object (hex_descriptor);

-- End of db_blastradius_index.sql
