-- filename: dblanegovernancetopology.sql
-- destination: Eco-Fort/db/dblanegovernancetopology.sql
-- Topology risk integration and governance drift views.

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 1. vshardtopologyker – extend vshardker with topology penalty
--
-- Depends on:
--   vshardker(shardid, ts_startutc, ts_endutc,
--             residual_kernel_code, planecontractid,
--             vt_core, itopology, rtopology, w_topology, vt_with_topology,
--             k_value, e_value, r_value, lane, kerdeployable)
--   topologyriskmetric(shardid, itopology, rtopology)
--   planeweightsplane(contractid, planeid, plane_code, weight)
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
  k.shardid,
  k.ts_startutc      AS timestamp,
  k.vt_core          AS Vt,
  k.k_value          AS K,
  k.e_value          AS E,
  k.r_value          AS R,
  k.lane,
  tr.rtopology,
  tr.itopology,
  COALESCE(tw.w_topology, 0.0) AS w_topology,
  k.vt_core
    + COALESCE(tw.w_topology, 0.0)
      * tr.rtopology * tr.rtopology AS Vt_with_topology,
  k.residual_kernel_code AS kernel_name,
  k.planecontractid       AS kernel_version
FROM vshardker          AS k
LEFT JOIN topologyriskmetric AS tr
  ON tr.shardid = k.shardid
LEFT JOIN topo_weight   AS tw
  ON tw.contractid = k.planecontractid;

CREATE INDEX IF NOT EXISTS idx_vshardtopologyker_lane_time
  ON vshardtopologyker (lane, timestamp);
