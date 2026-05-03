-- filename: spine/tasks/EcoNetKerResidualBlastRadius2026v1.task.sql
-- destination: Eco-Fort (SPINE band) /spine/tasks/
--
-- Scope: SPINE, non-actuating, grammar-tightening only.
-- This task shard defines:
--  1) Plane weights + Lyapunov residual grammar (PlaneWeightsShard2026v1).
--  2) Cross-system SQLite tables for neighbouring blast-radii parameters.
--
-- All tables are strictly non-actuating and are used by Virta-Sys,
-- ecological-orchestrator, and Paycomp as read-only governance surfaces.

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 1. Plane weights schema (already agreed math, made executable)
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS planeweights (
    planeweights_id      INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Contract / continuity binding (e.g. PhoenixEcosafetyContinuity2026v1)
    contract_id          TEXT NOT NULL,

    -- Logical risk plane id: 'energy','hydraulics','biology','carbon',
    -- 'materials','biodiversity','dataquality','topology', etc.
    plane_id             TEXT NOT NULL,

    -- Non-negative Lyapunov weight w_j for this plane.
    weight               REAL NOT NULL CHECK (weight >= 0.0),

    -- Non-offsettable flag; 1 means this plane cannot be "offset"
    -- by improvements in other planes for deployment decisions.
    non_offsettable      INTEGER NOT NULL CHECK (non_offsettable IN (0,1)),

    -- Soft and hard bands for this plane's normalized risk coordinate r_j.
    -- Example: soft_band <= 0.10, hard_band <= 0.13 for carbon/biodiversity.
    soft_band            REAL NOT NULL CHECK (soft_band >= 0.0 AND soft_band <= 1.0),
    hard_band            REAL NOT NULL CHECK (hard_band >= 0.0 AND hard_band <= 1.0),

    -- Optional per-plane uncertainty cap on r_j or derived statistics.
    uncertainty_cap      REAL NOT NULL CHECK (uncertainty_cap >= 0.0 AND uncertainty_cap <= 1.0),

    -- Version tag for this weights profile, e.g. 'PlaneWeightsShard2026v1'.
    version_tag          TEXT NOT NULL,

    -- Hex stamp tying this record back to the ecosafety proofs document
    -- that shows adding w_topology * r_topology^2 preserves Lyapunov
    -- properties and safestep invariants under corridor constraints.
    proof_ref_hex        TEXT NOT NULL,

    -- Audit fields
    created_utc          TEXT NOT NULL DEFAULT (datetime('now')),
    updated_utc          TEXT NOT NULL DEFAULT (datetime('now')),

    UNIQUE (contract_id, plane_id, version_tag)
);

CREATE INDEX IF NOT EXISTS idx_planeweights_contract_plane
    ON planeweights (contract_id, plane_id);

----------------------------------------------------------------------
-- 2. Neighbouring blast-radii schema (per-plane, per-region, per-graph)
--
-- This is the cross-system grammar that lets agents understand how far
-- a governance decision or anomaly can reach, without loading full
-- adjacency graphs. It is shared by smart-city and MT6883 workloads.
----------------------------------------------------------------------

-- Logical adjacency graphs live here (e.g. HYDRO, HEALTHORGAN, AIRGRID).
CREATE TABLE IF NOT EXISTS adjacencygraph (
    graph_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    graph_name      TEXT NOT NULL UNIQUE,          -- 'HYDRO', 'HEALTHORGAN', etc.
    description     TEXT,
    primary_plane   TEXT NOT NULL,                 -- e.g. 'hydraulics','biology'
    region          TEXT NOT NULL,                 -- e.g. 'Phoenix-AZ', 'Global'
    created_utc     TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Node-level adjacency index; kept simple so agents can reason about
-- neighbors without re-deriving the full graph from src code.
CREATE TABLE IF NOT EXISTS nodeadjacency (
    nodeadj_id      INTEGER PRIMARY KEY AUTOINCREMENT,

    graph_id        INTEGER NOT NULL REFERENCES adjacencygraph(graph_id)
                        ON DELETE CASCADE,

    -- Logical node identifier: could be hydrological reach id,
    -- treatment plant id, organ id, or MT6883 logical host id.
    node_id         TEXT NOT NULL,

    -- Neighbor node identifier.
    neighbor_node_id TEXT NOT NULL,

    -- Edge weight / distance metadata (optional, domain-specific).
    distance_m      REAL CHECK (distance_m IS NULL OR distance_m >= 0.0),
    latency_s       REAL CHECK (latency_s IS NULL OR latency_s >= 0.0),

    created_utc     TEXT NOT NULL DEFAULT (datetime('now')),

    UNIQUE (graph_id, node_id, neighbor_node_id)
);

CREATE INDEX IF NOT EXISTS idx_nodeadj_graph_node
    ON nodeadjacency (graph_id, node_id);

----------------------------------------------------------------------
-- 3. Blast radius index (per-plane, per-graph, per-scope)
--
-- TBR2026v1: Encodes a summary of reach in meters, hops, and time
-- along with KER band and topology grade as ASCII-hex descriptor.
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS blastradiusindex (
    blastradius_id  INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Scope of governance: could be a shardid, lane decision scope,
    -- QPU region, or hydrology/healthcare corridor reference.
    scoperef        TEXT NOT NULL,

    -- Region tag ('Phoenix-AZ', 'Gila-River', 'MT6883-Health', etc.)
    region          TEXT NOT NULL,

    -- Plane to which this blast radius applies.
    plane_id        TEXT NOT NULL,

    -- Adjacency graph reference.
    graph_id        INTEGER NOT NULL REFERENCES adjacencygraph(graph_id)
                        ON DELETE CASCADE,

    -- Representative KER band ('SAFE','GOLD','HARD','EXPERIMENT','OFF').
    ker_band        TEXT NOT NULL,

    -- Physical and logical radii metadata.
    radius_m        REAL NOT NULL CHECK (radius_m >= 0.0),      -- r_m
    radius_hops     INTEGER NOT NULL CHECK (radius_hops >= 0),  -- r_hops
    radius_time_s   REAL NOT NULL CHECK (radius_time_s >= 0.0), -- r_t

    -- Topology grade / risk (discretized).
    -- Example: 'A','B','C','D' or 'LOW','MEDIUM','HIGH'.
    topology_grade  TEXT NOT NULL,

    -- Non-actuating scope flag; 1 means this scope cannot directly
    -- actuate physical systems, even if it spans many neighbors.
    non_actuating   INTEGER NOT NULL CHECK (non_actuating IN (0,1)),

    -- Number of direct neighbor nodes touched within this radius.
    neighbor_count  INTEGER NOT NULL CHECK (neighbor_count >= 0),

    -- TBR2026v1 ASCII-hex descriptor summarizing the above fields so
    -- that agents can reason about blast radius without loading the
    -- full adjacencygraph or nodeadjacency tables.
    --
    -- Encoding pattern (conceptual):
    --   TBR2026v1(
    --     scoperef, region, plane_id, ker_band,
    --     radius_m, radius_hops, radius_time_s,
    --     topology_grade, non_actuating, neighbor_count
    --   ) -> ascii-hex string
    tbr2026v1_hex   TEXT NOT NULL,

    created_utc     TEXT NOT NULL DEFAULT (datetime('now')),

    UNIQUE (scoperef, plane_id, ker_band, graph_id)
);

CREATE INDEX IF NOT EXISTS idx_blastradius_scope_plane
    ON blastradiusindex (scoperef, plane_id);

CREATE INDEX IF NOT EXISTS idx_blastradius_region_plane
    ON blastradiusindex (region, plane_id);
