-- filename dbresidualkernelschema.sql
-- destination Eco-Fort/db/dbresidualkernelschema.sql

CREATE VIEW IF NOT EXISTS v_shard_residual AS
SELECT
  s.shardid,
  s.planecontractid,
  SUM(pw.weight * rt.alpha * rv.r_value * rv.r_value) AS vt,
  MAX(rv.r_value) AS rmax,
  (1.0 - MAX(rv.r_value)) AS evalue
FROM shardinstance AS s
JOIN v_shard_riskvector AS rv
  ON rv.shardid = s.shardid
JOIN residualterm AS rt
  ON rt.coordid = rv.coordid
JOIN planeweightsplane AS pw
  ON pw.planeid = rv.planeid
 AND pw.contractid = s.planecontractid
GROUP BY s.shardid, s.planecontractid;
