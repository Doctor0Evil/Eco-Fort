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

-- 2. vshardblast – per-shard blast radius summary
--
-- Depends on:
--   shardinstance(shardid, region, nodeid, blastradiusid, ...)
--   blastradiusobject(broid, region, nodeid,
--                     radiusmeters, radiustimehours, radiushops,
--                     primaryplanes, secondaryplanes,
--                     continuitygrade, tbr2026v1hex)

CREATE VIEW IF NOT EXISTS vshardblast AS
SELECT
  si.shardid,
  br.region,
  br.nodeid,
  br.radiusmeters      AS radius_meters,
  br.radiustimehours   AS radius_hours,
  br.radiushops        AS hops,
  br.primaryplanes     AS primary_planes,
  br.secondaryplanes   AS secondary_planes,
  br.continuitygrade   AS continuity_grade,
  br.tbr2026v1hex
FROM shardinstance    AS si
JOIN blastradiusobject AS br
  ON br.broid = si.blastradiusid;

CREATE INDEX IF NOT EXISTS idx_vshardblast_region_node
  ON vshardblast (region, nodeid);

----------------------------------------------------------------------
-- 3. vshardcanal – canal velocity and r_canal coordinate
--
-- Depends on:
--   vshardblast(shardid, region, nodeid, radius_meters, radius_hours, ...)
--   corridordefinition(coordid, coordcode, vmax_m_per_h, ...)
--     where coordcode = 'CANAL_VELOCITY' captures v_max per region/plane.
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS vshardcanal AS
WITH canal_params AS (
  SELECT
    cd.coordid,
    cd.coordcode,
    cd.vmax_m_per_h,
    cd.region
  FROM corridordefinition AS cd
  WHERE cd.coordcode = 'CANAL_VELOCITY'
)
SELECT
  vb.shardid,
  vb.region,
  vb.nodeid,
  vb.radius_meters,
  vb.radius_hours,
  (vb.radius_meters / (vb.radius_hours + 1e-6)) AS canal_velocity_m_per_h,
  cp.vmax_m_per_h,
  MIN(
    1.0,
    MAX(
      0.0,
      (vb.radius_meters / (vb.radius_hours + 1e-6))
      / NULLIF(cp.vmax_m_per_h, 0.0)
    )
  ) AS r_canal
FROM vshardblast AS vb
LEFT JOIN canal_params AS cp
  ON cp.region = vb.region;

CREATE INDEX IF NOT EXISTS idx_vshardcanal_region_node
  ON vshardcanal (region, nodeid);
