# Artifact Registry and Provenance Guide

This document explains how to use the `artifactregistry` and `artifactprovenance` tables, plus the companion views in `dbartifactregistry_index.sql`, to query artifacts, governance context, and CI provenance across the EcoNet constellation.

## 1. Tables and Views

### 1.1 Core tables

- `artifactregistry`  
  One row per registered artifact (binary, kernel, QPU data shard, governance log, healthcare plan, index DB). Each row links a repo file to shardinstance, QPU catalog, MT6883 registry, plane weights, and blast radius metadata.

- `artifactprovenance`  
  One row per provenance event (CI run, build, promotion) for a given artifact. Includes CI workflow identifiers, energy mode, status, shard counts, and a snapshot of KER and topology risk at run time.

### 1.2 Helper views

- `v_artifact_shard_ker`  
  Joins `artifactregistry` to `shardinstance`, `repo`, and `repofile`. Provides lane, KER metrics, region, and file path for each artifact.

- `v_artifact_planeweights`  
  Joins `artifactregistry` to `planeweights` to show which plane contract and weights govern each artifact, including non‑offsettable flags and corridor bands.

- `v_artifact_blastradius`  
  Joins `artifactregistry` to `planeweights` and `blastradiusindex` to expose KER band, radii in meters/hops/time, topology grade, and TBR descriptor for each artifact.

- `v_artifact_provenance_ker`  
  Joins `artifactprovenance` back to `artifactregistry`, `repo`, and `repofile`. Provides CI workflow identifiers, energy mode, status, and the KER snapshot at the time of the run.

## 2. Canonical Agent Queries

This section provides ready‑to‑use query patterns for AI agents and tools.

### 2.1 Find all active PROD Phoenix hydrology kernels

```sql
SELECT
    artifactid,
    reponame,
    reporelpath,
    artifactkind,
    primaryplane,
    artifactlane,
    shard_region,
    shard_k,
    shard_e,
    shard_r,
    shard_kerdeployable
FROM v_artifact_shard_ker
WHERE active = 1
  AND artifactkind = 'KERNEL'
  AND primaryplane = 'hydraulics'
  AND artifactlane = 'PROD'
  AND shard_region = 'Phoenix-AZ'
  AND shard_kerdeployable = 1;
```

### 2.2 Find all RESEARCH healthcare artifacts with high K

```sql
SELECT
    artifactid,
    reponame,
    reporelpath,
    artifactkind,
    primaryplane,
    artifactlane,
    artifact_k,
    artifact_e,
    artifact_r
FROM v_artifact_shard_ker
WHERE active = 1
  AND primaryplane = 'healthcare'
  AND artifactlane = 'RESEARCH'
  AND artifact_k IS NOT NULL
  AND artifact_k >= 0.92;
```

### 2.3 List artifacts governed by a specific plane contract

```sql
SELECT
    artifactid,
    reponame,
    reporelpath,
    primaryplane,
    plane_contract_name,
    plane_weight,
    plane_non_offsettable,
    plane_soft_band,
    plane_hard_band,
    plane_version_tag
FROM v_artifact_planeweights
WHERE plane_contract_name = 'PhoenixEcosafetyContinuity2026v1';
```

### 2.4 Inspect non‑offsettable planes for an artifact

```sql
SELECT
    artifactid,
    reponame,
    primaryplane,
    plane_contract_name,
    plane_non_offsettable,
    plane_soft_band,
    plane_hard_band
FROM v_artifact_planeweights
WHERE artifactid = ?1;
```

Agents can bind `?1` to the artifactid they are inspecting.

### 2.5 Find artifacts with large hydrology blast radius

```sql
SELECT
    artifactid,
    reponame,
    reporelpath,
    primaryplane,
    lane,
    kerband,
    blast_region,
    radius_m,
    radius_hops,
    radius_time_s,
    topology_grade,
    neighbor_count,
    tbr2026v1_hex
FROM v_artifact_blastradius
WHERE primaryplane = 'hydraulics'
  AND lane IN ('EXPPROD','PROD')
  AND radius_m >= 5000.0;
```

### 2.6 Find non‑actuating governance artifacts with wide influence

```sql
SELECT
    artifactid,
    reponame,
    reporelpath,
    primaryplane,
    lane,
    kerband,
    blast_region,
    radius_m,
    topology_grade,
    tbr2026v1_hex
FROM v_artifact_blastradius
WHERE lane = 'RESEARCH'
  AND blast_non_actuating = 1
  AND radius_m >= 10000.0;
```

This is useful for identifying governance or analytics artifacts whose logical reach is broad but non‑actuating.

### 2.7 Trace CI provenance for a detox kernel

```sql
SELECT
    p.provenanceid,
    p.cirunid,
    p.workflowfile,
    p.energymode,
    p.status,
    p.sharddbpath,
    p.shardcount,
    p.run_lane,
    p.run_k,
    p.run_e,
    p.run_r,
    p.run_vtmax,
    p.run_kerdeployable,
    p.rtopology,
    p.wtopology,
    p.evidencehex,
    p.rohanchorhex,
    p.signingdid,
    p.timestamputc
FROM v_artifact_provenance_ker p
JOIN v_artifact_shard_ker a
  ON p.artifactid = a.artifactid
WHERE a.artifactid = ?1
ORDER BY p.timestamputc DESC;
```

Agents can use this to answer “how did this detox kernel reach PROD and under what KER/topology conditions?”

### 2.8 List all LOWPOWER CI runs that produced deployable PROD artifacts

```sql
SELECT
    p.provenanceid,
    p.artifactid,
    p.cirunid,
    p.workflowfile,
    p.energymode,
    p.status,
    p.run_lane,
    p.run_k,
    p.run_e,
    p.run_r,
    p.run_kerdeployable,
    p.timestamputc,
    a.reponame,
    a.relporelpath,
    a.artifactkind
FROM v_artifact_provenance_ker p
JOIN v_artifact_shard_ker a
  ON p.artifactid = a.artifactid
WHERE p.energymode = 'LOWPOWER'
  AND p.status = 'COMPLETED'
  AND p.run_lane = 'PROD'
  AND p.run_kerdeployable = 1;
```

This query is useful for audits and energy‑mode enforcement.

## 3. Agent Usage Guidelines

- Use `artifactregistry` for **identity and wiring** from repo files into shards, catalogs, MT6883 registry, plane weights, and blast radius.
- Use `v_artifact_shard_ker` when you need **lane, KER, and region** context for an artifact.
- Use `v_artifact_planeweights` when you need **plane weights, non‑offsettable flags, and bands**.
- Use `v_artifact_blastradius` when you need **governance reach and TBR descriptors**.
- Use `v_artifact_provenance_ker` to analyze **CI history, energy modes, and KER snapshots** for artifacts.

Agents should prefer these views over manual joins to reduce query complexity and ensure consistent semantics across the constellation.
