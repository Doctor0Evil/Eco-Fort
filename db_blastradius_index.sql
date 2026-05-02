-- filename: db_blastradius_index.sql
-- destination: Eco-Fort/db/db_blastradius_index.sql
-- Purpose: Quantify influence zones for safer routing and neighborhood impact reasoning

PRAGMA foreign_keys = ON;

-- ==============================================================================
-- 1. NODE ADJACENCY GRAPH (Topology relationships)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS node_adjacency (
    edge_id INTEGER PRIMARY KEY AUTOINCREMENT,
    graph_name TEXT NOT NULL, -- HYDRO_PHOENIX, STREET_PHOENIX, HEALTH_ORGAN
    source_node TEXT NOT NULL,
    target_node TEXT NOT NULL,
    relationship_type TEXT NOT NULL, -- UPSTREAM, DOWNSTREAM, ADJACENT, FEEDS
    distance_meters REAL,
    travel_time_hours REAL,
    weight REAL DEFAULT 1.0,
    created_utc TEXT NOT NULL,
    UNIQUE(graph_name, source_node, target_node, relationship_type)
);

CREATE INDEX IF NOT EXISTS idx_node_adj_graph ON node_adjacency(graph_name);
CREATE INDEX IF NOT EXISTS idx_node_adj_source ON node_adjacency(source_node);

-- ==============================================================================
-- 2. BLAST RADIUS OBJECT (Shard/Node influence footprint)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS blastradius_object (
    blast_id INTEGER PRIMARY KEY AUTOINCREMENT,
    scope_type TEXT NOT NULL CHECK(scope_type IN ('SHARD', 'NODE', 'VNODE')),
    scope_ref TEXT NOT NULL, -- shard_id, node_id, vnode_id

    -- Geometric footprint
    center_region TEXT NOT NULL,
    center_node TEXT,
    radius_meters REAL,
    radius_hops INTEGER,
    radius_hours REAL,

    -- Plane interaction
    primary_plane TEXT NOT NULL,
    secondary_planes TEXT, -- Comma-separated list

    -- KER bands (coarse-grained: HIGH, MEDIUM, LOW)
    k_band TEXT CHECK(k_band IN ('HIGH', 'MEDIUM', 'LOW')),
    e_band TEXT CHECK(e_band IN ('HIGH', 'MEDIUM', 'LOW')),
    r_band TEXT CHECK(r_band IN ('HIGH', 'MEDIUM', 'LOW')),
    vt_residual_est REAL,

    -- Continuity and governance
    continuity_grade TEXT, -- A, B, C for virtual nodes
    sovereignty_tag TEXT, -- SOVEREIGN-LOCAL, CROSS-JURISDICTION
    governance_profile TEXT, -- OKTOPLAN, OBSERVEONLY, NEEDSREVIEW

    -- Neighborhood
    neighbor_count INTEGER DEFAULT 0,
    neighbor_zones TEXT, -- Human-readable: "UPSTREAM:PHX-HYDRO-02;DOWNSTREAM:PHX-HYDRO-03"
    nonactuating_only INTEGER NOT NULL DEFAULT 1 CHECK(nonactuating_only IN (0,1)),

    -- Compact hex descriptor
    hex_descriptor TEXT,

    created_utc TEXT NOT NULL,
    updated_utc TEXT NOT NULL,
    UNIQUE(scope_type, scope_ref)
);

CREATE INDEX IF NOT EXISTS idx_blast_region_plane ON blastradius_object(center_region, primary_plane);
CREATE INDEX IF NOT EXISTS idx_blast_governance ON blastradius_object(governance_profile, nonactuating_only);

-- End of db_blastradius_index.sql
