-- filename ecosafety_grammar_core.sql
-- destination Eco-Fort/db/ecosafety_grammar_core.sql

PRAGMA foreign_keys = ON;

-------------------------------------------------------------------------------
-- 1. Eco-planes: global list of Lyapunov planes with weights and invariants.
-------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS plane (
    plane_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT NOT NULL UNIQUE,    -- energy, carbon, biodiversity, water, health, topology, dataquality, finance
    description   TEXT,
    weight        REAL NOT NULL,           -- contribution weight in V_t, normalized later
    nonoffsettable INTEGER NOT NULL DEFAULT 0 CHECK (nonoffsettable IN (0,1)),
    mandatory     INTEGER NOT NULL DEFAULT 1 CHECK (mandatory IN (0,1)),
    created_utc   TEXT NOT NULL,
    updated_utc   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_plane_nonoffset
    ON plane (nonoffsettable, mandatory);

-------------------------------------------------------------------------------
-- 2. Risk coordinates: each varid lives in exactly one plane.
-------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS risk_coordinate (
    coord_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    varid         TEXT NOT NULL UNIQUE,  -- e.g. CARBON.NETINTENSITY, BIODIV.CONNECTIVITY, ROH.GLOBAL
    plane_id      INTEGER NOT NULL REFERENCES plane(plane_id) ON DELETE RESTRICT,
    units         TEXT,
    description   TEXT,
    is_residual   INTEGER NOT NULL DEFAULT 0 CHECK (is_residual IN (0,1)),
    is_ker_input  INTEGER NOT NULL DEFAULT 1 CHECK (is_ker_input IN (0,1)),
    created_utc   TEXT NOT NULL,
    updated_utc   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_riskcoord_plane
    ON risk_coordinate (plane_id);

-------------------------------------------------------------------------------
-- 3. Corridor bands for each coordinate: mirroring corridordefinition.
-------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS corridor_band (
    corridor_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    coord_id      INTEGER NOT NULL REFERENCES risk_coordinate(coord_id) ON DELETE CASCADE,
    safe          REAL NOT NULL,
    gold          REAL NOT NULL,
    hard          REAL NOT NULL,
    weight        REAL NOT NULL,           -- local weight within the plane
    mandatory     INTEGER NOT NULL DEFAULT 1 CHECK (mandatory IN (0,1)),
    /* Example: lyap_channel redundant, implied by plane, but kept for compatibility. */
    lyap_channel  TEXT NOT NULL,
    spechash_hex  TEXT,                    -- optional ALN schema hash
    created_utc   TEXT NOT NULL,
    updated_utc   TEXT NOT NULL,
    UNIQUE (coord_id)
);

CREATE INDEX IF NOT EXISTS idx_corridor_plane
    ON corridor_band (lyap_channel);

-------------------------------------------------------------------------------
-- 4. KER definitions: how K, E, R are computed from coordinates and planes.
-------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ker_definition (
    ker_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    scope_type    TEXT NOT NULL,  -- REPO, FILE, SCHEMA, PARTICLE, SHARD, COURSE, HOST
    scope_hint    TEXT,           -- e.g. EcoNet-CEIM-PhoenixWater, mt6883treatmentcourse
    description   TEXT,
    k_min_target  REAL NOT NULL DEFAULT 0.90,
    e_min_target  REAL NOT NULL DEFAULT 0.90,
    r_max_target  REAL NOT NULL DEFAULT 0.13,
    v_residual_max REAL NOT NULL DEFAULT 1.0,  -- generic upper bound for V_t in this scope
    created_utc   TEXT NOT NULL,
    updated_utc   TEXT NOT NULL,
    UNIQUE (scope_type, scope_hint)
);

-- Per-plane contributions to K, E, R for this ker_definition.
CREATE TABLE IF NOT EXISTS ker_plane_weight (
    ker_plane_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    ker_id        INTEGER NOT NULL REFERENCES ker_definition(ker_id) ON DELETE CASCADE,
    plane_id      INTEGER NOT NULL REFERENCES plane(plane_id) ON DELETE RESTRICT,
    k_weight      REAL NOT NULL,  -- how much this plane contributes to K
    e_weight      REAL NOT NULL,  -- contribution to E
    r_weight      REAL NOT NULL,  -- contribution to R
    monotone_only INTEGER NOT NULL DEFAULT 1 CHECK (monotone_only IN (0,1)),
    created_utc   TEXT NOT NULL,
    updated_utc   TEXT NOT NULL,
    UNIQUE (ker_id, plane_id)
);

-------------------------------------------------------------------------------
-- 5. Residual kernel definition: how V_t is formed from coordinates.
-------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS residual_kernel (
    kernel_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT NOT NULL UNIQUE,  -- e.g. ecosafety.Vt.core2026v1
    description   TEXT,
    /* normalization convention: V_t = sum_j alpha_j * r_j^2 */
    normalized    INTEGER NOT NULL DEFAULT 1 CHECK (normalized IN (0,1)),
    created_utc   TEXT NOT NULL,
    updated_utc   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS residual_term (
    kernel_term_id INTEGER PRIMARY KEY AUTOINCREMENT,
    kernel_id      INTEGER NOT NULL REFERENCES residual_kernel(kernel_id) ON DELETE CASCADE,
    coord_id       INTEGER NOT NULL REFERENCES risk_coordinate(coord_id) ON DELETE RESTRICT,
    alpha_weight   REAL NOT NULL,  -- coefficient in V_t
    noncompensable INTEGER NOT NULL DEFAULT 0 CHECK (noncompensable IN (0,1)),
    created_utc    TEXT NOT NULL,
    updated_utc    TEXT NOT NULL,
    UNIQUE (kernel_id, coord_id)
);

-------------------------------------------------------------------------------
-- 6. Topology risk r_topology: linking governance drift into V_t.
-------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS topology_risk_metric (
    topology_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name     TEXT NOT NULL,      -- matches econetrepoindex.reponame
    mislabel_count INTEGER NOT NULL DEFAULT 0,
    missing_manifest_count INTEGER NOT NULL DEFAULT 0,
    window_start_utc TEXT NOT NULL,
    window_end_utc   TEXT NOT NULL,
    r_topology_raw   REAL NOT NULL,   -- I_topology before normalization
    r_topology       REAL NOT NULL,   -- 0..1 corridor-mapped
    created_utc      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_topology_risk_repo
    ON topology_risk_metric (repo_name, window_end_utc);

-------------------------------------------------------------------------------
-- 7. View: join shardinstance KER with grammar for cross-system searchability.
-------------------------------------------------------------------------------
/* This assumes shardinstance and knowledgeecoscore are created elsewhere and
   have the shapes described in the Eco-Fort / Virta-Sys design documents. */

CREATE VIEW IF NOT EXISTS v_shard_ker_grammar AS
SELECT
    s.shardid              AS shard_id,
    s.nodeid               AS node_id,
    s.region               AS region,
    s.lane                 AS lane,
    s.kmetric              AS k_metric,
    s.emetric              AS e_metric,
    s.rmetric              AS r_metric,
    s.vtmax                AS v_t_max,
    s.kerdeployable        AS ker_deployable,
    k.scopetype            AS ker_scope_type,
    k.scoperefid           AS ker_scope_refid,
    k.kfactor              AS k_factor_meta,
    k.efactor              AS e_factor_meta,
    k.rfactor              AS r_factor_meta
FROM shardinstance s
LEFT JOIN knowledgeecoscore k
  ON k.scopetype = 'SHARD'
 AND k.scoperefid = s.shardid;
