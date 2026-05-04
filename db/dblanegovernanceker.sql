-- filename: dblanegovernanceker.sql
-- destination: Eco-Fort/db/dblanegovernanceker.sql
-- Lane admissibility and reward corridor views.

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 4. vshardker_windows – windowed K/E/R per shard (short/med/long)
--
-- Depends on:
--   shardinstance(shardid, ts_endutc, kmetric, emetric, rmetric, lane)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS vshardker_windows AS
WITH base AS (
  SELECT
    s.shardid,
    s.ts_endutc        AS ts,
    s.kmetric          AS K,
    s.emetric          AS E,
    s.rmetric          AS R,
    s.lane
  FROM shardinstance AS s
)
SELECT
  b.shardid,
  b.lane,
  AVG(CASE WHEN b.ts >= datetime('now','-7 days')   THEN b.K END) AS K_short,
  AVG(CASE WHEN b.ts >= datetime('now','-7 days')   THEN b.E END) AS E_short,
  AVG(CASE WHEN b.ts >= datetime('now','-7 days')   THEN b.R END) AS R_short,
  AVG(CASE WHEN b.ts >= datetime('now','-90 days')  THEN b.K END) AS K_medium,
  AVG(CASE WHEN b.ts >= datetime('now','-90 days')  THEN b.E END) AS E_medium,
  AVG(CASE WHEN b.ts >= datetime('now','-90 days')  THEN b.R END) AS R_medium,
  AVG(CASE WHEN b.ts >= datetime('now','-365 days') THEN b.K END) AS K_long,
  AVG(CASE WHEN b.ts >= datetime('now','-365 days') THEN b.E END) AS E_long,
  AVG(CASE WHEN b.ts >= datetime('now','-365 days') THEN b.R END) AS R_long
FROM base AS b
GROUP BY b.shardid, b.lane;

----------------------------------------------------------------------
-- 5. vshardker_trend – simple residual trend slope per shard
--
-- Depends on:
--   vshardker(shardid, ts_endutc, vt_with_topology)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS vshardker_trend AS
WITH ordered AS (
  SELECT
    k.shardid,
    k.ts_endutc,
    k.vt_with_topology,
    ROW_NUMBER() OVER (
      PARTITION BY k.shardid
      ORDER BY k.ts_endutc
    ) AS rn
  FROM vshardker AS k
),
diffs AS (
  SELECT
    o1.shardid,
    o1.ts_endutc,
    o1.vt_with_topology,
    (o1.vt_with_topology - o0.vt_with_topology) AS delta_vt
  FROM ordered AS o1
  JOIN ordered  AS o0
    ON o0.shardid = o1.shardid
   AND o0.rn      = o1.rn - 1
)
SELECT
  shardid,
  AVG(delta_vt) AS Vtrend_b
FROM diffs
GROUP BY shardid;

----------------------------------------------------------------------
-- 6. vlane_admissibility – lane transition predicate
--
-- Depends on:
--   vshardker_windows
--   vshardker_trend
--   lanepolicy(target_lane, k_min, e_min, r_max)
--   lanestatusshard(shardid, corridorsok, planesok, topologyok)
--   shardlane_quarantine(shardid, lane_quarantined)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS vlane_admissibility AS
SELECT
  w.shardid          AS workload_id,
  lp.target_lane     AS target_lane,
  CASE
    WHEN COALESCE(q.lane_quarantined, 0) = 1 THEN 0
    WHEN w.K_short   < lp.k_min OR
         w.E_short   < lp.e_min OR
         w.R_short   > lp.r_max THEN 0
    WHEN w.K_medium  < lp.k_min OR
         w.E_medium  < lp.e_min OR
         w.R_medium  > lp.r_max THEN 0
    WHEN w.K_long    < lp.k_min OR
         w.E_long    < lp.e_min OR
         w.R_long    > lp.r_max THEN 0
    WHEN t.Vtrend_b  IS NOT NULL
         AND t.Vtrend_b > 0.0 THEN 0
    WHEN COALESCE(ls.corridorsok, 0) = 0 OR
         COALESCE(ls.planesok,    0) = 0 OR
         COALESCE(ls.topologyok,  0) = 0 THEN 0
    ELSE 1
  END AS is_admissible,
  w.K_short,  w.E_short,  w.R_short,
  w.K_medium, w.E_medium, w.R_medium,
  w.K_long,   w.E_long,   w.R_long,
  t.Vtrend_b,
  COALESCE(ls.corridorsok, 0) AS corridors_ok,
  COALESCE(ls.planesok,    0) AS planesok,
  COALESCE(ls.topologyok,  0) AS topologyok,
  COALESCE(q.lane_quarantined, 0) AS lane_quarantined
FROM vshardker_windows    AS w
JOIN lanepolicy           AS lp
  ON lp.current_lane = w.lane
JOIN vshardker_trend      AS t
  ON t.shardid = w.shardid
LEFT JOIN lanestatusshard AS ls
  ON ls.shardid = w.shardid
LEFT JOIN shardlane_quarantine AS q
  ON q.shard_id = w.shardid;

CREATE INDEX IF NOT EXISTS idx_vlane_admissibility_target
  ON vlane_admissibility (target_lane, is_admissible);

----------------------------------------------------------------------
-- 7. vreward_window_lane – reward eligibility by lane and window
--
-- Depends on:
--   dr9_knowledge_windows_view(shard_id, k_short, e_short, r_short,
--                              k_medium, e_medium, r_medium,
--                              k_long, e_long, r_long)
--   lane_reward_thresholds(lane, k_min, e_min, r_max)
--   shardinstance(shardid, lane)
----------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS vreward_window_lane AS
WITH base AS (
  SELECT
    s.shardid,
    s.lane,
    kw.k_short,
    kw.e_short,
    kw.r_short,
    kw.k_medium,
    kw.e_medium,
    kw.r_medium,
    kw.k_long,
    kw.e_long,
    kw.r_long
  FROM shardinstance             AS s
  JOIN dr9_knowledge_windows_view AS kw
    ON kw.shard_id = s.shardid
)
SELECT
  b.shardid,
  b.lane,
  CASE
    WHEN b.k_short >= lrt.k_min
     AND b.e_short >= lrt.e_min
     AND b.r_short <= lrt.r_max THEN 1
    ELSE 0
  END AS short_eligible,
  CASE
    WHEN b.k_medium >= lrt.k_min
     AND b.e_medium >= lrt.e_min
     AND b.r_medium <= lrt.r_max THEN 1
    ELSE 0
  END AS medium_eligible,
  CASE
    WHEN b.k_long >= lrt.k_min
     AND b.e_long >= lrt.e_min
     AND b.r_long <= lrt.r_max THEN 1
    ELSE 0
  END AS long_eligible,
  CASE
    WHEN b.k_short >= lrt.k_min
     AND b.e_short >= lrt.e_min
     AND b.r_short <= lrt.r_max
     AND b.k_medium >= lrt.k_min
     AND b.e_medium >= lrt.e_min
     AND b.r_medium <= lrt.r_max
     AND b.k_long >= lrt.k_min
     AND b.e_long >= lrt.e_min
     AND b.r_long <= lrt.r_max THEN 1
    ELSE 0
  END AS reward_eligible
FROM base AS b
JOIN lane_reward_thresholds AS lrt
  ON lrt.lane = b.lane;

CREATE INDEX IF NOT EXISTS idx_vreward_window_lane_reward
  ON vreward_window_lane (reward_eligible);
