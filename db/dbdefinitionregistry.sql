-- filename: dbdefinitionregistry.sql
-- destination: Eco-Fort/db/dbdefinitionregistry.sql
-- DefinitionRegistry2026v1 spine for DR-1 through DR-10.

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 0. Core registry tables
----------------------------------------------------------------------

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
-- 1. DR-1 – SQLite Lyapunov residual V_t = Σ w_j r_j^2
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
-- 2. DR-2 – Topology waste penalties
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
-- 3. DR-3 – Canal velocity coordinate r_canal
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
-- 4. DR-4 – largeparticlefile chunk & hash cost profile
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
-- 5. DR-5 – MT6883 continuity score and grade
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
-- 6. DR-6 – Artifact provenance commitment
--
-- Assumes:
--   artifactregistry(artifact_id, ...)
--   artifactprovenance(prov_id, artifact_id, ts, prev_prov_id, payload_hash)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS dr6_provenance_chain_view AS
SELECT
    p.artifact_id,
    p.prov_id,
    p.prev_prov_id,
    p.ts,
    p.payload_hash,
    p.rowid AS chain_height
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
-- 7. DR-7 – Lane quarantine states
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
-- 8. DR-8 – Emergent planes under frozen grammar
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS emergent_plane_registry (
    plane_id          INTEGER PRIMARY KEY,
    plane_code        TEXT NOT NULL UNIQUE,   -- microbiome, noise, ...
    core_version      TEXT NOT NULL,          -- EcosafetyGrammarCore2026v1
    extension_contract TEXT NOT NULL,         -- EcosafetyContinuity2030v1
    enabled_since     TEXT NOT NULL,
    description       TEXT NOT NULL
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
-- 9. DR-9 – knowledgeecoscore time windows
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
-- 10. DR-10 – IoT telemetry → shardinstance federation
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
-- 11. Seed DR-1 → DR-10 codes into definition_registry
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
