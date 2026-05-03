-- filename: dbartifactregistry_index.sql
-- destination: Eco-Fort/db/dbartifactregistry_index.sql

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- Helper indexes on referenced tables (no-ops if already present)
----------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_shardinstance_region_lane
    ON shardinstance (region, lane, kmetric, emetric, rmetric);

CREATE INDEX IF NOT EXISTS idx_shardinstance_shardid
    ON shardinstance (shardid);

CREATE INDEX IF NOT EXISTS idx_planeweights_contract_plane
    ON planeweights (contract_id, plane_id);

CREATE INDEX IF NOT EXISTS idx_repo_repoid_name
    ON repo (repoid, name);

CREATE INDEX IF NOT EXISTS idx_repofile_fileid_path
    ON repofile (fileid, relpath);

----------------------------------------------------------------------
-- 1. View: artifacts joined to shardinstance (KER + lane + region)
--
-- Example queries:
--  - "find all active PROD Phoenix hydrology kernels"
--  - "find all RESEARCH healthcare artifacts with K >= 0.92"
----------------------------------------------------------------------

DROP VIEW IF EXISTS v_artifact_shard_ker;

CREATE VIEW v_artifact_shard_ker AS
SELECT
    a.artifactid,
    a.repoid,
    r.name                 AS reponame,
    a.repofileid,
    f.relpath              AS reporelpath,
    a.repotarget,
    a.destinationpath,
    a.filename,
    a.fileext,
    a.artifactkind,
    a.primaryplane,
    a.secondaryplanes,
    a.lane                 AS artifactlane,
    a.kerband,
    a.kmetric              AS artifact_k,
    a.emetric              AS artifact_e,
    a.rmetric              AS artifact_r,
    a.vtmax                AS artifact_vtmax,
    a.kerdeployable        AS artifact_kerdeployable,
    a.shardid,
    s.region               AS shard_region,
    s.lane                 AS shard_lane,
    s.kmetric              AS shard_k,
    s.emetric              AS shard_e,
    s.rmetric              AS shard_r,
    s.vtmax                AS shard_vtmax,
    s.kerdeployable        AS shard_kerdeployable,
    a.evidencehex,
    a.signingdid,
    a.createdutc,
    a.updatedutc,
    a.active
FROM artifactregistry a
LEFT JOIN shardinstance s
       ON a.shardid = s.shardid
LEFT JOIN repo r
       ON a.repoid = r.repoid
LEFT JOIN repofile f
       ON a.repofileid = f.fileid;

----------------------------------------------------------------------
-- 2. View: artifacts with planeweights contract
--
-- Example queries:
--  - "list all artifacts governed by PhoenixEcosafetyContinuity2026v1"
--  - "show non-offsettable planes and bands for this artifact"
----------------------------------------------------------------------

DROP VIEW IF EXISTS v_artifact_planeweights;

CREATE VIEW v_artifact_planeweights AS
SELECT
    a.artifactid,
    a.repoid,
    r.name                    AS reponame,
    a.repofileid,
    f.relpath                 AS reporelpath,
    a.primaryplane,
    a.secondaryplanes,
    a.lane,
    a.kerband,
    a.kmetric,
    a.emetric,
    a.rmetric,
    a.vtmax,
    a.planecontractid,
    pw.contract_id            AS plane_contract_name,
    pw.plane_id               AS planeweights_plane_id,
    pw.weight                 AS plane_weight,
    pw.non_offsettable        AS plane_non_offsettable,
    pw.soft_band              AS plane_soft_band,
    pw.hard_band              AS plane_hard_band,
    pw.uncertainty_cap        AS plane_uncertainty_cap,
    pw.version_tag            AS plane_version_tag
FROM artifactregistry a
LEFT JOIN repo r
       ON a.repoid = r.repoid
LEFT JOIN repofile f
       ON a.repofileid = f.fileid
LEFT JOIN planeweights pw
       ON a.planecontractid = pw.planeweights_id
      AND a.primaryplane    = pw.plane_id;

----------------------------------------------------------------------
-- 3. View: artifacts with blast radius and planeweights
--
-- Example queries:
--  - "find PROD artifacts whose blast radius in hydrology exceeds X meters"
--  - "inspect TBR descriptor for a given artifact"
----------------------------------------------------------------------

DROP VIEW IF EXISTS v_artifact_blastradius;

CREATE VIEW v_artifact_blastradius AS
SELECT
    a.artifactid,
    a.repoid,
    r.name                 AS reponame,
    a.repofileid,
    f.relpath              AS reporelpath,
    a.primaryplane,
    a.secondaryplanes,
    a.lane,
    a.kerband,
    a.kmetric,
    a.emetric,
    a.rmetric,
    a.vtmax,
    a.planecontractid,
    pw.contract_id         AS plane_contract_name,
    pw.weight              AS plane_weight,
    pw.non_offsettable     AS plane_non_offsettable,
    a.blastradiusid,
    br.scoperef,
    br.region              AS blast_region,
    br.plane_id            AS blast_plane_id,
    br.ker_band            AS blast_ker_band,
    br.radius_m,
    br.radius_hops,
    br.radius_time_s,
    br.topology_grade,
    br.non_actuating       AS blast_non_actuating,
    br.neighbor_count,
    br.tbr2026v1_hex,
    a.active
FROM artifactregistry a
LEFT JOIN repo r
       ON a.repoid = r.repoid
LEFT JOIN repofile f
       ON a.repofileid = f.fileid
LEFT JOIN planeweights pw
       ON a.planecontractid = pw.planeweights_id
      AND a.primaryplane    = pw.plane_id
LEFT JOIN blastradiusindex br
       ON a.blastradiusid = br.blastradius_id;

----------------------------------------------------------------------
-- 4. View: artifact provenance with KER snapshot
--
-- Example queries:
--  - "trace CI provenance for this detox kernel"
--  - "list all LOWPOWER runs that produced deployable PROD artifacts"
----------------------------------------------------------------------

DROP VIEW IF EXISTS v_artifact_provenance_ker;

CREATE VIEW v_artifact_provenance_ker AS
SELECT
    p.provenanceid,
    p.artifactid,
    a.repoid,
    r.name            AS reponame,
    a.repofileid,
    f.relpath         AS reporelpath,
    a.filename,
    a.artifactkind,
    p.cirunid,
    p.workflowfile,
    p.repo            AS cirun_repo_slug,
    p.energymode,
    p.status,
    p.sharddbpath,
    p.shardcount,
    p.lane            AS run_lane,
    p.kmetric         AS run_k,
    p.emetric         AS run_e,
    p.rmetric         AS run_r,
    p.vtmax           AS run_vtmax,
    p.kerdeployable   AS run_kerdeployable,
    p.rtopology,
    p.wtopology,
    p.planecontractid,
    p.evidencehex,
    p.rohanchorhex,
    p.signingdid,
    p.timestamputc
FROM artifactprovenance p
JOIN artifactregistry a
  ON p.artifactid = a.artifactid
LEFT JOIN repo r
  ON a.repoid = r.repoid
LEFT JOIN repofile f
  ON a.repofileid = f.fileid;
