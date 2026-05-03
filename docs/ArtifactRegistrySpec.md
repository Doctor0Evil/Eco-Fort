# Artifact Registry Spec

This document defines how artifacts and their provenance are registered into the EcoNet constellation using `artifactregistry`, `artifactprovenance`, and companion views.

## 1. Artifact Lifecycle Overview

An **artifact** is any machine‑readable asset that participates in ecosafety governance:

- Binaries and shared objects.
- Kernels and routines.
- QPU data shards and governance logs.
- Healthcare and detox plans.
- Index and state databases.

Each artifact has:

1. A filesystem identity (repo, path, filename).
2. A semantic identity (kind, planes, lane, KER band).
3. A wiring identity (links into `shardinstance`, `qpushardcatalog`, `mt6883registry`, `planeweights`, `blastradiusindex`).
4. A provenance chain (CI runs and promotions).

## 2. `artifactregistry` Canonical Fields

Every row in `artifactregistry` must populate:

- **Identity and wiring**
  - `repoid`, `repofileid`: link to `repo` and `repofile`.
  - Optional: `shardid`, `catalogid`, `mt6883registryid`.

- **File metadata**
  - `repotarget`: mirror of `repo.name`.
  - `destinationpath`: directory path inside the repo.
  - `filename`, `fileext`.

- **Kind and content**
  - `artifactkind`: one of `BINARY`, `KERNEL`, `ROUTINE`, `QPUDATASHARD`, `GOVLOG`, `HEALTHCARE_PLAN`, `INDEX_DB`.
  - `contenthash`: canonical hex hash of bytes (algorithm defined in policy).
  - Optional: `sizebytes`.

- **Ecosafety semantics**
  - `primaryplane`: main plane (e.g. `energy`, `hydraulics`, `healthcare`, `materials`, `dataquality`, `topology`).
  - `secondaryplanes`: comma‑separated planes when relevant.
  - `lane`: `RESEARCH`, `EXPPROD`, or `PROD`.
  - `kerband`: `SAFE`, `GUARDED`, or `BLOCKED`.
  - Optional: `planecontractid` (→ `planeweightscontract`), `blastradiusid` (→ `blastradiusindex`).

- **Cached KER metrics**
  - Optional: `kmetric`, `emetric`, `rmetric`, `vtmax`.
  - `kerdeployable`: `0` or `1` (default `0`).

- **Governance and evidence**
  - `evidencehex`: descriptor for the evidence bundle used to register the artifact.
  - Optional: `rohanchorhex`: RoH chain anchor.
  - `signingdid`: DID that attested this artifact.
  - Optional: `provenancehex`: pointer into a higher‑level provenance chain.

- **Lifecycle**
  - `createdutc`, `updatedutc`: ISO‑8601 timestamps.
  - `active`: `1` for active, `0` for retired (no hard deletes).

Uniqueness is enforced on `(repoid, destinationpath, filename, contenthash)` so the same exact file cannot be registered multiple times under different semantics.

## 3. `artifactprovenance` Canonical Fields

Each row in `artifactprovenance` represents a single CI or governance run that touched an artifact:

- **Run identity**
  - `artifactid`: FK into `artifactregistry`.
  - `cirunid`: CI run ID.
  - `workflowfile`: path to the workflow (e.g. `.github/workflows/shard-indexer-ci.yml`).
  - `repo`: CI repo slug.

- **Run configuration**
  - `energymode`: `LOWPOWER`, `BALANCED`, `HIGHTHROUGHPUT`.
  - `status`: `COMPLETED`, `FAILED`, `CANCELLED`.
  - Optional: `sharddbpath`, `shardcount`.

- **Ecosafety context**
  - `lane`: lane in effect during the run.
  - Optional: `kmetric`, `emetric`, `rmetric`, `vtmax`.
  - Optional: `kerdeployable` (0/1).
  - Optional: `rtopology`, `wtopology`.
  - Optional: `planecontractid`.

- **Evidence and signing**
  - `evidencehex`: descriptor for the run’s evidence bundle.
  - Optional: `rohanchorhex`.
  - `signingdid`: CI or human DID.

- **Time**
  - `timestamputc`: ISO‑8601 completion time.

Uniqueness is enforced on `(artifactid, cirunid)`.

## 4. Canonical Registration Flow

1. **Discovery phase**
   - CI or agent identifies a candidate artifact (e.g. a built kernel or a new shard file).
   - Looks up `repoid` and `repofileid` from `repo` and `repofile`.

2. **Semantics and KER snapshot**
   - Determines `artifactkind`, `primaryplane`, `secondaryplanes`.
   - Reads current lane and KER values from `shardinstance` (if applicable).
   - Resolves `planecontractid` from `planeweightscontract` / `planeweights`.
   - Resolves `blastradiusid` from `blastradiusindex` if blast radius has been computed.

3. **Registry insert**
   - Computes `contenthash`, populates `evidencehex`, `signingdid`, timestamps.
   - Inserts into `artifactregistry` (or updates `updatedutc` if identical hash and path match).

4. **Provenance insert**
   - Once CI run completes, inserts into `artifactprovenance` with run metadata and KER snapshot.
   - Links back to the artifact via `artifactid`.

5. **Query via views**
   - Agents and tools use `v_artifact_shard_ker`, `v_artifact_planeweights`, `v_artifact_blastradius`, and `v_artifact_provenance_ker` to explore artifacts, KER context, blast radii, and CI history.

## 5. Agent Patterns

### 5.1 Discover candidate artifacts to extend

- Query `v_artifact_shard_ker` for `lane = 'RESEARCH'`, `kerdeployable = 0`, and promising K/E scores.
- Propose new code, tests, or shard summaries targeting those artifacts.

### 5.2 Check deployability

- Query `v_artifact_shard_ker` for `artifactlane = 'PROD'` and ensure `shard_kerdeployable = 1`, `shard_k >= 0.90`, `shard_e >= 0.90`, `shard_r <= 0.13`.

### 5.3 Reason about blast radius

- Query `v_artifact_blastradius` for artifacts with large `radius_m` or `radius_hops`, and inspect `tbr2026v1_hex` to decide whether to tighten corridors or lane policies.

### 5.4 Trace CI lineage

- Query `v_artifact_provenance_ker` by `artifactid` to see which CI runs, energy modes, and KER conditions produced the current artifact state.

Agents should always prefer these views and the spec above rather than inferring semantics from file paths or ad‑hoc naming conventions.
