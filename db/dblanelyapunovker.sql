-- filename: dblanelyapunovker.sql
-- destination: Eco-Fort/db/dblanelyapunovker.sql
-- Shard-level Lyapunov residual and KER views (vshardresidual, vshardker).

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 1. Core assumptions (existing tables / views)
--
-- shardinstance(
--   shardid TEXT PRIMARY KEY,           -- or INTEGER, depending on spine
--   ts_startutc TEXT,                   -- window start
--   ts_endutc   TEXT,                   -- window end
--   planecontractid INTEGER,           -- FK into planeweightscontract
--   kmetric REAL, emetric REAL, rmetric REAL, vtmax REAL,
--   lane TEXT,                         -- RESEARCH, EXPPROD, PROD
--   kerdeployable INTEGER              -- 0/1
-- )
--
-- shardriskcoord(
--   shardid TEXT,
--   coordid INTEGER,
--   r_value REAL,                      -- normalized 0..1
--   PRIMARY KEY (shardid, coordid)
-- )
--
-- residualkernel(
--   kernelid INTEGER PRIMARY KEY,
--   kernelcode TEXT NOT NULL,          -- ecosafety.Vt.core2026v1, etc.
--   planecontractid INTEGER NOT NULL
-- )
--
-- residualterm(
--   termid INTEGER PRIMARY KEY,
--   kernelid INTEGER NOT NULL,
--   coordid INTEGER NOT NULL,
--   alpha   REAL NOT NULL,             -- coefficient = w_j in frozen math
--   FOREIGN KEY (kernelid) REFERENCES residualkernel(kernelid)
-- )
--
-- topologyriskmetric(
--   shardid TEXT PRIMARY KEY,
--   itopology REAL,                    -- raw inconsistency index
--   rtopology REAL                     -- normalized 0..1 coordinate
-- )
--
-- planeweightscontract / planeweightsplane are already wired in
-- ecosafetygrammarcore.sql; they define w_topology for the topology plane.
----------------------------------------------------------------------

----------------------------------------------------------------------
-- 2. vshardresidual – core Lyapunov residual V_t = Σ alpha * r_j^2
--
-- This view computes the core residual from residualkernel, residualterm,
-- and shardriskcoord, for each shardinstance row.
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS vshardresidual AS
WITH active_kernel AS (
  SELECT
    rk.kernelid,
    rk.kernelcode,
    rk.planecontractid
  FROM residualkernel AS rk
)
SELECT
  si.shardid,
  si.ts_startutc    AS ts_startutc,
  si.ts_endutc      AS ts_endutc,
  ak.kernelcode     AS residual_kernel_code,
  ak.planecontractid,
  SUM(rt.alpha * rc.r_value * rc.r_value) AS vt_value
FROM shardinstance      AS si
JOIN active_kernel      AS ak
  ON ak.planecontractid = si.planecontractid
JOIN residualterm       AS rt
  ON rt.kernelid        = ak.kernelid
JOIN shardriskcoord     AS rc
  ON rc.shardid         = si.shardid
 AND rc.coordid         = rt.coordid
GROUP BY
  si.shardid,
  si.ts_startutc,
  si.ts_endutc,
  ak.kernelcode,
  ak.planecontractid;

CREATE INDEX IF NOT EXISTS idx_vshardresidual_shardid_time
  ON vshardresidual (shardid, ts_endutc);

----------------------------------------------------------------------
-- 3. vshardtopologyker – inject topology risk into residual
--
-- V_t_final = V_t_core + w_topology * r_topology^2
--
-- Assumes:
--   topologyriskmetric(shardid, itopology, rtopology)
--   planeweightsplane(contractid, planeid, weight, plane_code)
--     where plane_code = 'TOPOLOGY' (or similar) identifies topology plane.
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS vshardtopologyker AS
WITH topo_weight AS (
  SELECT
    pwp.contractid,
    pwp.weight AS w_topology
  FROM planeweightsplane AS pwp
  WHERE pwp.plane_code = 'TOPOLOGY'
)
SELECT
  vr.shardid,
  vr.ts_startutc,
  vr.ts_endutc,
  vr.residual_kernel_code,
  vr.planecontractid,
  vr.vt_value                 AS vt_core,
  tr.itopology,
  tr.rtopology,
  COALESCE(tw.w_topology, 0.0)                     AS w_topology,
  vr.vt_value + COALESCE(tw.w_topology, 0.0)
                 * tr.rtopology * tr.rtopology     AS vt_with_topology
FROM vshardresidual      AS vr
LEFT JOIN topologyriskmetric AS tr
  ON tr.shardid = vr.shardid
LEFT JOIN topo_weight    AS tw
  ON tw.contractid = vr.planecontractid;

CREATE INDEX IF NOT EXISTS idx_vshardtopologyker_shardid_time
  ON vshardtopologyker (shardid, ts_endutc);

----------------------------------------------------------------------
-- 4. vshardker – consolidated shard-level KER and Lyapunov view
--
-- Exposes:
--   shardid, ts_startutc, ts_endutc
--   vt_core, vt_with_topology
--   kmetric, emetric, rmetric
--   lane, kerdeployable
--   residual_kernel_code, planecontractid
--   itopology, rtopology, w_topology
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS vshardker AS
SELECT
  si.shardid,
  si.ts_startutc,
  si.ts_endutc,
  vk.residual_kernel_code,
  vk.planecontractid,
  vk.vt_core,
  vk.itopology,
  vk.rtopology,
  vk.w_topology,
  vk.vt_with_topology,
  si.kmetric   AS k_value,
  si.emetric   AS e_value,
  si.rmetric   AS r_value,
  si.lane,
  si.kerdeployable
FROM shardinstance    AS si
JOIN vshardtopologyker AS vk
  ON vk.shardid     = si.shardid
 AND vk.ts_endutc   = si.ts_endutc;

CREATE INDEX IF NOT EXISTS idx_vshardker_lane_time
  ON vshardker (lane, ts_endutc);

----------------------------------------------------------------------
-- 5. vshardker_violation – simple Lyapunov monotonicity check
--
-- Flags rows where V_{t+1} > V_t (beyond a small epsilon), using
-- vshardker ordered by (shardid, ts_endutc).
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS safestepconfig (
  planecontractid INTEGER PRIMARY KEY,
  eps_residual    REAL NOT NULL DEFAULT 1e-6
);

CREATE VIEW IF NOT EXISTS vshardker_violation AS
WITH ordered AS (
  SELECT
    k.*,
    LAG(k.vt_with_topology) OVER (
      PARTITION BY k.shardid
      ORDER BY k.ts_endutc
    ) AS vt_prev
  FROM vshardker AS k
)
SELECT
  o.shardid,
  o.ts_startutc,
  o.ts_endutc,
  o.vt_with_topology AS vt_current,
  o.vt_prev          AS vt_previous,
  (o.vt_with_topology - o.vt_prev) AS delta_vt,
  sc.eps_residual,
  CASE
    WHEN o.vt_prev IS NULL THEN 0
    WHEN o.vt_with_topology <= o.vt_prev + sc.eps_residual THEN 0
    ELSE 1
  END AS violates_lyapunov
FROM ordered AS o
JOIN safestepconfig AS sc
  ON sc.planecontractid = o.planecontractid;

CREATE INDEX IF NOT EXISTS idx_vshardker_violation_flag
  ON vshardker_violation (violates_lyapunov);
