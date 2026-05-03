-- filename: dbdefinitionregistry.sql
-- destination: Eco-Fort/db/dbdefinitionregistry.sql
-- DefinitionRegistry2026v1 spine for contracts and DR-1 through DR-10.

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 0. Core registry tables: contracts and definition registry
----------------------------------------------------------------------

-- High-level contracts for frozen grammars and governance definitions.
CREATE TABLE IF NOT EXISTS definitioncontract (
  contractid        TEXT PRIMARY KEY,
  scope             TEXT NOT NULL,          -- ECOSAFETY_CORE, PLANE_WEIGHTS, etc.
  registryversion   TEXT NOT NULL,          -- e.g. 2026v1
  description       TEXT NOT NULL,
  created_utc       TEXT NOT NULL,          -- ISO-8601
  updated_utc       TEXT NOT NULL           -- ISO-8601
);

-- Canonical mapping from logical definition names to concrete artifacts.
CREATE TABLE IF NOT EXISTS definitionregistry (
  definitionid      INTEGER PRIMARY KEY AUTOINCREMENT,

  contractid        TEXT NOT NULL
                    REFERENCES definitioncontract(contractid)
                    ON DELETE CASCADE,

  scope             TEXT NOT NULL,          -- ECOSAFETY_CORE, LANE_GOVERNANCE, etc.
  logicalname       TEXT NOT NULL,          -- ecosafety.grammar.core.2026v1
  kind              TEXT NOT NULL,          -- ALN_SCHEMA, SQL_SCHEMA, SQL_VIEW, RUST_MODULE, DOC_SPEC

  repo              TEXT NOT NULL,          -- Eco-Fort, EcoNet, Virta-Sys, ...
  destinationpath   TEXT NOT NULL,          -- db/..., src/..., aln/...
  filename          TEXT NOT NULL,
  language          TEXT NOT NULL,          -- SQLite, ALN, Rust, Markdown

  versiontag        TEXT NOT NULL,          -- 2026v1, v1.0.0, etc.
  active            INTEGER NOT NULL DEFAULT 1
                    CHECK (active IN (0,1)),

  primaryplane      TEXT NOT NULL,          -- 'all' or specific plane; '' if N/A
  appliescope       TEXT NOT NULL,          -- CONSTELLATION, REPO, SHARD, NODE, MT6883

  summary           TEXT NOT NULL,

  signingdid        TEXT NOT NULL,
  issued_utc        TEXT NOT NULL,
  updated_utc       TEXT NOT NULL,

  UNIQUE (logicalname, versiontag),
  UNIQUE (repo, destinationpath, filename, versiontag)
);

-- Lightweight table indexing DR-1 → DR-10 view bindings for fast lookup.
CREATE TABLE IF NOT EXISTS definition_registry (
    def_id       INTEGER PRIMARY KEY,
    def_code     TEXT NOT NULL UNIQUE,   -- DR1_SQLITE_LYAPUNOV, ...
    scope        TEXT NOT NULL,          -- LyapunovResidual, TopologyWaste, ...
    version      TEXT NOT NULL DEFAULT '2026v1',
    aln_particle TEXT NOT NULL,          -- DefinitionRegistry2026v1
    db_anchor    TEXT NOT NULL,          -- dbdefinitionregistry.sql#dr1_shard_residual_view
    description  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS definition_param (
    def_id  INTEGER NOT NULL,
    key     TEXT NOT NULL,
    value   TEXT NOT NULL,
    PRIMARY KEY (def_id, key),
    FOREIGN KEY (def_id) REFERENCES definition_registry(def_id) ON DELETE CASCADE
);

----------------------------------------------------------------------
-- 1. Helpful indexes for definitionregistry
----------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_definition_scope_active
  ON definitionregistry (scope, active);

CREATE INDEX IF NOT EXISTS idx_definition_repo_active
  ON definitionregistry (repo, active);

CREATE INDEX IF NOT EXISTS idx_definition_contract
  ON definitionregistry (contractid, active);

CREATE INDEX IF NOT EXISTS idx_definition_kind_language
  ON definitionregistry (kind, language);

----------------------------------------------------------------------
-- 2. Seed rows for 2026v1 contracts (extend as needed)
----------------------------------------------------------------------

INSERT OR IGNORE INTO definitioncontract (
  contractid, scope, registryversion, description, created_utc, updated_utc
) VALUES
  ('EcosafetyContinuity2026v1', 'ECOSAFETY_CORE', '2026v1',
   'Frozen ecosafety grammar: planes, coordinates, corridors, KER, residual.',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),
  ('EcosafetyPlaneWeights2026v1', 'PLANE_WEIGHTS', '2026v1',
   'Plane weights, non-compensation invariants, and topology plane wiring.',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),
  ('LaneGovernance2026v1', 'LANE_GOVERNANCE', '2026v1',
   'Lane predicates, lane status shards, lane verdicts, and CI gates.',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),
  ('TopologyRisk2026v1', 'TOPOLOGY_RISK', '2026v1',
   'Topology audit, Itopology/rtopology metrics, and governance drift.',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),
  ('BlastRadius2026v1', 'BLAST_RADIUS', '2026v1',
   'Blast radius, adjacency graph, and tbr2026v1hex descriptors.',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),
  ('ArtifactRegistry2026v1', 'ARTIFACT_REGISTRY', '2026v1',
   'Universal artifact registry and provenance for governed artifacts.',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),
  ('MT6883Continuity2026v1', 'MT6883_CONTINUITY', '2026v1',
   'Continuity grades, RoH envelopes, and governance bindings for MT6883.',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z');

----------------------------------------------------------------------
-- 3. Seed rows for key grammar and governance definitions
----------------------------------------------------------------------

INSERT OR IGNORE INTO definitionregistry (
  contractid, scope, logicalname, kind,
  repo, destinationpath, filename, language,
  versiontag, active, primaryplane, appliescope,
  summary, signingdid, issued_utc, updated_utc
) VALUES
  ('EcosafetyContinuity2026v1', 'ECOSAFETY_CORE',
   'ecosafety.grammar.core.2026v1', 'SQL_SCHEMA',
   'Eco-Fort', 'db/ecosafetygrammarcore.sql', 'ecosafetygrammarcore.sql', 'SQLite',
   '2026v1', 1, 'all', 'CONSTELLATION',
   'Canonical ecosafety grammar: planes, coordinates, corridors, KER, residualkernel, residualterm.',
   'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),

  ('EcosafetyPlaneWeights2026v1', 'PLANE_WEIGHTS',
   'ecosafety.planeweights.2026v1', 'ALN_SCHEMA',
   'aln-platform-ecosystem', 'aln/ecosafetyPlaneWeightsShard2026v1.aln', 'ecosafetyPlaneWeightsShard2026v1.aln', 'ALN',
   '2026v1', 1, 'all', 'CONSTELLATION',
   'Plane weights and non-compensation contract including topology plane.',
   'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),

  ('LaneGovernance2026v1', 'LANE_GOVERNANCE',
   'lane.status.shard.2026v1', 'ALN_SCHEMA',
   'aln-platform-ecosystem', 'aln/LaneStatusShard2026v1.aln', 'LaneStatusShard2026v1.aln', 'ALN',
   '2026v1', 1, 'all', 'SHARD',
   'Lane status shard schema for Virta-Sys lane governor and CI.',
   'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),

  ('TopologyRisk2026v1', 'TOPOLOGY_RISK',
   'virtasys.topology.audit.sql.2026v1', 'SQL_SCHEMA',
   'Eco-Fort', 'db/dbvirtatopologyaudit.sql', 'dbvirtatopologyaudit.sql', 'SQLite',
   '2026v1', 1, 'topology', 'CONSTELLATION',
   'Topology audit schema computing Itopology and rtopology.',
   'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),

  ('BlastRadius2026v1', 'BLAST_RADIUS',
   'econet.blastradius.schema.2026v1', 'SQL_SCHEMA',
   'Eco-Fort', 'db/dbblastradiusindex.sql', 'dbblastradiusindex.sql', 'SQLite',
   '2026v1', 1, 'all', 'NODE',
   'Blast radius and adjacency schema with tbr2026v1hex descriptors.',
   'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z'),

  ('ArtifactRegistry2026v1', 'ARTIFACT_REGISTRY',
   'econet.artifact.registry.sql.2026v1', 'SQL_SCHEMA',
   'Eco-Fort', 'db/dbartifactregistry.sql', 'dbartifactregistry.sql', 'SQLite',
   '2026v1', 1, 'dataquality', 'REPO',
   'Universal artifact registry and provenance tables.',
   'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
   '2026-05-03T07:15:00Z', '2026-05-03T07:15:00Z');

----------------------------------------------------------------------
-- 4. DR-1 – SQLite Lyapunov residual V_t = Σ w_j r_j^2
--
-- Assumes:
--   residualterm(def_code, coord_id, alpha)
--   shardriskcoord(shard_id, coord_id, r_value)
--   shardinstance(shard_id, ts)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS dr1_shard_residual_view AS
SELECT
    s.shard_id,
    s.ts,
    SUM(t.alpha * r.r_value * r.r_value) AS vt_value
FROM shardinstance AS s
JOIN shardriskcoord AS r
  ON r.shard_id = s.shard_id
JOIN residualterm AS t
  ON t.coord_id = r.coord_id
WHERE t.def_code = 'LYAPUNOV_CORE_2026'
GROUP BY s.shard_id, s.ts;

----------------------------------------------------------------------
-- 5. DR-2 – Topology waste penalties
--
-- Assumes:
--   nodeenergyprofile(node_id, ts_window, non_actuating_joules, joules_min_efficient)
--   largeparticlefile(file_id, source_id)
--   nodeworkload(node_id, file_id)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS dr2_topology_waste_view AS
SELECT
    n.node_id,
    n.ts_window,
    MIN(1.0, MAX(0.0,
        n.non_actuating_joules / NULLIF(n.joules_min_efficient, 0.0)
    ))                           AS r_waste_idle,
    MIN(1.0, MAX(0.0,
        CAST(COUNT(DISTINCT lpf.source_id) AS REAL) /
        (1.0 + CAST(COUNT(lpf.file_id) AS REAL))
    ))                           AS r_waste_frag
FROM nodeenergyprofile AS n
LEFT JOIN nodeworkload AS nw
  ON nw.node_id = n.node_id
LEFT JOIN largeparticlefile AS lpf
  ON lpf.file_id = nw.file_id
GROUP BY n.node_id, n.ts_window;

----------------------------------------------------------------------
-- 6. DR-3 – Canal velocity coordinate r_canal
--
-- Assumes:
--   blastradiusindex(scope_id, plane, radius_meters, radius_hours)
--   scope_to_shard(scope_id, shard_id)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS dr3_canal_velocity_view AS
SELECT
    s.shard_id,
    bri.plane,
    (bri.radius_meters / (bri.radius_hours + 1e-6))           AS canal_velocity_m_per_h,
    MIN(1.0, MAX(0.0,
        (bri.radius_meters / (bri.radius_hours + 1e-6)) / 1000.0
    ))                                                        AS r_canal
FROM blastradiusindex AS bri
JOIN scope_to_shard AS s
  ON s.scope_id = bri.scope_id;

----------------------------------------------------------------------
-- 7. DR-4 – largeparticlefile chunk & hash cost profile
--
-- Assumes:
--   largeparticlefile(file_id, sizebytes, chunksizebytes, hashstrategy)
--   largeparticleblock(file_id, block_index, sizebytes)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS dr4_largeparticle_cost_view AS
SELECT
    f.file_id,
    f.sizebytes,
    f.chunksizebytes,
    f.hashstrategy,
    COUNT(b.block_index)                  AS block_count,
    SUM(b.sizebytes)                      AS total_block_bytes,
    CAST(COUNT(b.block_index) AS REAL)    AS e_io_units,
    CAST(f.sizebytes AS REAL) / 1000000.0 AS t_tokens_units,
    CASE
        WHEN f.hashstrategy = 'FULL'   THEN 0.001
        WHEN f.hashstrategy = 'SAMPLE' THEN 0.01
        ELSE 0.1
    END                                   AS p_miss_proxy
FROM largeparticlefile AS f
LEFT JOIN largeparticleblock AS b
  ON b.file_id = f.file_id
GROUP BY f.file_id;

----------------------------------------------------------------------
-- 8. DR-5 – MT6883 continuity score and grade
--
-- Assumes:
--   mt6883registry(mt_id, shard_id)
--   shardinstance(shard_id, ts, ker_k, ker_e, ker_r, vt)
--   blastradiusobject(mt_id, radius_meters, radius_hours)
--   adjacencygraph(mt_id, neighbor_id, hop_count, neighbor_risk)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS dr5_mt6883_continuity_view AS
WITH ker_stats AS (
    SELECT
        s.shard_id,
        AVG(s.ker_k) AS k_avg,
        AVG(s.ker_e) AS e_avg,
        AVG(s.ker_r) AS r_avg,
        AVG(s.vt)    AS v_avg,
        AVG(ABS(s.vt - lag_vt.vt)) AS v_volatility
    FROM shardinstance AS s
    LEFT JOIN shardinstance AS lag_vt
      ON lag_vt.shard_id = s.shard_id
     AND lag_vt.rowid    = s.rowid - 1
    GROUP BY s.shard_id
),
blast AS (
    SELECT
        m.mt_id,
        b.radius_meters,
        b.radius_hours
    FROM mt6883registry AS m
    JOIN blastradiusobject AS b
      ON b.mt_id = m.mt_id
),
neighbors AS (
    SELECT
        a.mt_id,
        AVG(a.neighbor_risk) AS neighbor_risk_avg,
        AVG(a.hop_count)     AS avg_hops
    FROM adjacencygraph AS a
    GROUP BY a.mt_id
)
SELECT
    m.mt_id,
    m.shard_id,
    k.k_avg,
    k.e_avg,
    k.r_avg,
    k.v_avg,
    k.v_volatility,
    b.radius_meters,
    b.radius_hours,
    n.neighbor_risk_avg,
    n.avg_hops,
    MIN(1.0, MAX(0.0,
        (1.0 - MIN(k.v_volatility, 1.0)) *
        (1.0 / (1.0 + b.radius_meters / 1000.0)) *
        (1.0 / (1.0 + n.neighbor_risk_avg))
    )) AS c_mt6883,
    CASE
        WHEN MIN(1.0, MAX(0.0,
             (1.0 - MIN(k.v_volatility, 1.0)) *
             (1.0 / (1.0 + b.radius_meters / 1000.0)) *
             (1.0 / (1.0 + n.neighbor_risk_avg))
        )) >= 0.8 THEN 'A'
        WHEN MIN(1.0, MAX(0.0,
             (1.0 - MIN(k.v_volatility, 1.0)) *
             (1.0 / (1.0 + b.radius_meters / 1000.0)) *
             (1.0 / (1.0 + n.neighbor_risk_avg))
        )) >= 0.5 THEN 'B'
        ELSE 'C'
    END AS continuitygrade_auto
FROM mt6883registry AS m
JOIN ker_stats AS k
  ON k.shard_id = m.shard_id
LEFT JOIN blast AS b
  ON b.mt_id = m.mt_id
LEFT JOIN neighbors AS n
  ON n.mt_id = m.mt_id;

----------------------------------------------------------------------
-- 9. DR-6 – Artifact provenance commitment
--
-- Assumes:
--   artifactregistry(artifactid, ...)
--   artifactprovenance(provenanceid, artifactid, ts, prev_prov_id, payload_hash)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS dr6_provenance_chain_view AS
SELECT
    p.artifactid      AS artifact_id,
    p.provenanceid    AS prov_id,
    p.prev_prov_id    AS prev_prov_id,
    p.ts              AS ts,
    p.payload_hash    AS payload_hash,
    p.rowid           AS chain_height
FROM artifactprovenance AS p;

CREATE TABLE IF NOT EXISTS artifactprovenance_commitment (
    artifact_id    INTEGER PRIMARY KEY,
    latest_prov_id INTEGER NOT NULL,
    chain_hash     BLOB    NOT NULL,
    ts_committed   TEXT    NOT NULL,
    FOREIGN KEY (artifact_id)    REFERENCES artifactregistry(artifactid) ON DELETE CASCADE,
    FOREIGN KEY (latest_prov_id) REFERENCES artifactprovenance(provenanceid) ON DELETE CASCADE
);

----------------------------------------------------------------------
-- 10. DR-7 – Lane quarantine states
--
-- Assumes:
--   shardlane(shard_id, lanecode)
--   shardmetrics(shard_id, ts, vt, c_mt6883)
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS shardlane_quarantine (
    shard_id          INTEGER PRIMARY KEY,
    lanecode          TEXT NOT NULL,
    lane_quarantined  INTEGER NOT NULL DEFAULT 0,
    quarantine_reason TEXT
);

CREATE VIEW IF NOT EXISTS dr7_lane_quarantine_view AS
WITH latest AS (
    SELECT
        m.shard_id,
        m.lanecode,
        m.vt,
        m.c_mt6883,
        ROW_NUMBER() OVER (
            PARTITION BY m.shard_id
            ORDER BY m.ts DESC
        ) AS rn
    FROM shardmetrics AS m
)
SELECT
    q.shard_id,
    l.lanecode,
    q.lane_quarantined,
    q.quarantine_reason,
    l.vt,
    l.c_mt6883
FROM shardlane_quarantine AS q
JOIN latest AS l
  ON l.shard_id = q.shard_id
 AND l.rn = 1;

----------------------------------------------------------------------
-- 11. DR-8 – Emergent planes under frozen grammar
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS emergent_plane_registry (
    plane_id           INTEGER PRIMARY KEY,
    plane_code         TEXT NOT NULL UNIQUE,
    core_version       TEXT NOT NULL,          -- EcosafetyGrammarCore2026v1
    extension_contract TEXT NOT NULL,          -- EcosafetyContinuity2030v1
    enabled_since      TEXT NOT NULL,
    description        TEXT NOT NULL
);

CREATE VIEW IF NOT EXISTS dr8_emergent_planes_view AS
SELECT
    plane_id,
    plane_code,
    core_version,
    extension_contract,
    enabled_since,
    description
FROM emergent_plane_registry;

----------------------------------------------------------------------
-- 12. DR-9 – knowledgeecoscore time windows
--
-- Assumes:
--   knowledgeecoscore(shard_id, ts, k_value, e_value, r_value)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS dr9_knowledge_windows_view AS
WITH base AS (
    SELECT
        k.shard_id,
        k.ts,
        k.k_value,
        k.e_value,
        k.r_value
    FROM knowledgeecoscore AS k
),
short_window AS (
    SELECT
        shard_id,
        AVG(k_value) AS k_short,
        AVG(e_value) AS e_short,
        AVG(r_value) AS r_short
    FROM base
    WHERE ts >= datetime('now','-7 days')
    GROUP BY shard_id
),
medium_window AS (
    SELECT
        shard_id,
        AVG(k_value) AS k_medium,
        AVG(e_value) AS e_medium,
        AVG(r_value) AS r_medium
    FROM base
    WHERE ts >= datetime('now','-90 days')
    GROUP BY shard_id
),
long_window AS (
    SELECT
        shard_id,
        AVG(k_value) AS k_long,
        AVG(e_value) AS e_long,
        AVG(r_value) AS r_long
    FROM base
    WHERE ts >= datetime('now','-365 days')
    GROUP BY shard_id
)
SELECT
    s.shard_id,
    s.k_short,
    s.e_short,
    s.r_short,
    m.k_medium,
    m.e_medium,
    m.r_medium,
    l.k_long,
    l.e_long,
    l.r_long
FROM short_window  AS s
LEFT JOIN medium_window AS m ON m.shard_id = s.shard_id
LEFT JOIN long_window   AS l ON l.shard_id = s.shard_id;

----------------------------------------------------------------------
-- 13. DR-10 – IoT telemetry → shardinstance federation
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS iot_telemetry_raw (
    sensor_id TEXT NOT NULL,
    plane     TEXT NOT NULL,
    ts        TEXT NOT NULL,
    value     REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS iot_telemetry_window (
    window_id  INTEGER PRIMARY KEY,
    scope_id   INTEGER NOT NULL,
    plane      TEXT NOT NULL,
    ts_start   TEXT NOT NULL,
    ts_end     TEXT NOT NULL,
    value_avg  REAL NOT NULL,
    value_max  REAL NOT NULL
);

CREATE VIEW IF NOT EXISTS dr10_iot_aggregates_view AS
SELECT
    w.scope_id,
    w.plane,
    w.ts_end AS ts_effective,
    w.value_avg,
    w.value_max
FROM iot_telemetry_window AS w;

----------------------------------------------------------------------
-- 14. Seed DR-1 → DR-10 codes into definition_registry
----------------------------------------------------------------------

INSERT OR IGNORE INTO definition_registry
    (def_code, scope, aln_particle, db_anchor, description)
VALUES
('DR1_SQLITE_LYAPUNOV',    'LyapunovResidual',   'DefinitionRegistry2026v1', 'dbdefinitionregistry.sql#dr1_shard_residual_view',
 'SQLite-only computation of Vt = Σ w_j r_j^2 per shard.'),
('DR2_TOPOLOGY_PENALTIES', 'TopologyWaste',      'DefinitionRegistry2026v1', 'dbdefinitionregistry.sql#dr2_topology_waste_view',
 'Idle congestion and fragmentation penalties on shared nodes.'),
('DR3_CANAL_VELOCITY',     'CanalVelocity',      'DefinitionRegistry2026v1', 'dbdefinitionregistry.sql#dr3_canal_velocity_view',
 'Canal velocity coordinate r_canal from blast-radius metrics.'),
('DR4_LARGEPARTICLE_PROFILE', 'LargeParticleProfile','DefinitionRegistry2026v1','dbdefinitionregistry.sql#dr4_largeparticle_cost_view',
 'Chunk/hash cost profile for largeparticlefile artifacts.'),
('DR5_MT6883_CONTINUITY',  'ContinuityGrade',    'DefinitionRegistry2026v1', 'dbdefinitionregistry.sql#dr5_mt6883_continuity_view',
 'Automatic MT6883 continuity score and grade.'),
('DR6_PROVENANCE_COMMITMENT', 'ArtifactProvenance','DefinitionRegistry2026v1','dbdefinitionregistry.sql#dr6_provenance_chain_view',
 'Hash-chained artifact provenance with commitment table.'),
('DR7_LANE_QUARANTINE',    'LaneQuarantine',     'DefinitionRegistry2026v1', 'dbdefinitionregistry.sql#dr7_lane_quarantine_view',
 'Quarantine flags that never reduce lane but tighten guards.'),
('DR8_EMERGENT_PLANES',    'EcosafetyExtension', 'DefinitionRegistry2026v1', 'dbdefinitionregistry.sql#dr8_emergent_planes_view',
 'Registry of emergent ecosafety planes under extension contracts.'),
('DR9_KNOWLEDGE_WINDOW_SET', 'KnowledgeEcoScore','DefinitionRegistry2026v1','dbdefinitionregistry.sql#dr9_knowledge_windows_view',
 'Short/medium/long knowledgeecoscore windows for rewards.'),
('DR10_IOT_FEDERATION',    'SmartCityTelemetry', 'DefinitionRegistry2026v1', 'dbdefinitionregistry.sql#dr10_iot_aggregates_view',
 'IoT aggregation windows feeding shardinstance safely.');
