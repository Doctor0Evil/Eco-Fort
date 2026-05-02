# QpuShardCatalog: Wiring Map for qpudatashards

This document explains the purpose of the `qpu_shard_catalog` and `qpu_shard_tag` tables and how agents and tools should use them when generating code or new qpudatashards.

## 1. Purpose

The `qpu_shard_catalog` table is the machine-readable index of all qpudatashards and related artifacts under each repository’s `qpudatashards/` tree, with a focus on the `particles/` directory.

It answers three questions for agents:

1. **Discovery**: Which shards exist for a given region, plane, or role (ingest, kernel input, governance log, dashboard)?  
2. **Wiring**: For a given shard, which ALN schema governs its columns and how should code interact with it?  
3. **Generation**: When creating new shards, where should they be placed, what should they be named, and which schema should they follow?

The table is intentionally metadata-only. Full ALN/CSV content is handled by `aln_schema` and `aln_particle`.

## 2. Table overview

The schema is defined in `db/qpu_shard_catalog_schema.sql` and created by tools such as `tools/shard-indexer`.

Key columns:

- `repo_name`: Repository that owns the shard (e.g., `EcoNet`).  
- `rel_dir`: Directory path under the repo, typically `qpudatashards/particles`.  
- `file_name`: Filename, e.g., `CyboquaticHydroEcoPhoenix2026v1.aln`.  
- `file_ext`: Extension (`aln`, `csv`, `bmx`, `pdf`).  
- `content_hash`: Hex hash (sha2) of file contents, for dedup and integrity.  
- `size_bytes`: File size in bytes.

Semantic columns:

- `shard_kind`: High-level type: `QPUDATASHARD`, `SCHEMA`, `WORKFLOW`, `EVIDENCE`, `KPI`, `SIMULATION`, `DOC`, or `OTHER`.  
- `primary_plane`: Dominant ecosafety plane: `hydraulics`, `energy`, `materials`, `biodiversity`, `dataquality`, `topology`, `finance`, etc.  
- `region`: Geographic region or scope: `Phoenix-AZ`, `Central-AZ`, `Global`, etc.  
- `shard_version`: Version string extracted from filename when available (e.g., `2026v1`, `2024-2026`).  
- `preferred_role`: Suggested role for this shard: `INGEST`, `KERNEL_INPUT`, `KERNEL_OUTPUT`, `GOVERNANCE_LOG`, `DASHBOARD_SOURCE`.  
- `schema_ref`: Name of the ALN schema shard that defines this shard’s column structure (e.g., `EcoNetSchemaShard2026v2.aln`, `IngestRcalibPhoenix2026v1.aln`).

Governance columns:

- `created_utc`, `updated_utc`: Catalog timestamps.  
- `active`: 1 if the shard is current; 0 if logically retired.

The optional `qpu_shard_tag` table allows arbitrary key/value tags attached to `shard_id` for higher granularity.

## 3. How agents should interact with the catalog

When an agent receives a coding or file-generation request, it should:

### 3.1. Locate relevant shards

Use the catalog to discover existing shards before generating new code or files.

Examples:

- **Find Phoenix hydraulics evidence shards**:

  ```sql
  SELECT file_name, rel_dir, schema_ref, preferred_role
  FROM qpu_shard_catalog
  WHERE repo_name     = 'EcoNet'
    AND rel_dir       LIKE 'qpudatashards/particles%'
    AND primary_plane = 'hydraulics'
    AND region        = 'Phoenix-AZ'
    AND shard_kind    IN ('QPUDATASHARD','EVIDENCE')
    AND active        = 1;
  ```

- **Find global plastic materials shards**:

  ```sql
  SELECT file_name, schema_ref
  FROM qpu_shard_catalog
  WHERE repo_name     = 'EcoNet'
    AND primary_plane = 'materials'
    AND region        = 'Global'
    AND shard_kind    IN ('QPUDATASHARD','EVIDENCE')
    AND active        = 1;
  ```

Agents should prefer using existing shards as inputs to new code rather than inventing new input formats.

### 3.2. Determine wiring patterns for code

For each shard the agent plans to interact with:

1. **Read `schema_ref`**: This points to an ALN schema shard (e.g., `EcoNetSchemaShard2026v2.aln` or `IngestRcalibPhoenix2026v1.aln`). Agents must use this schema to define struct fields, CSV column names, and data types.

2. **Check `preferred_role`**:

   - `INGEST`: Write code that reads this shard (ALN/CSV) and converts it into internal types such as `RiskVector`, `KerSnapshot`, or domain-specific structs.  
   - `KERNEL_INPUT`: Treat this shard as canonical input for kernels (e.g., CEIM/CPVM kernels).  
   - `GOVERNANCE_LOG`: Treat this as a log shard produced by Virta-Sys or GOV repos; do not overwrite; append or query only.  
   - `DASHBOARD_SOURCE`: Use this as a data source for UI and reporting, not as an actuator input.

3. **Use `primary_plane` and `region`** to select the correct KER math, corridor checks, and residual functions. For example:

   - For `primary_plane='hydraulics'`, map fields into hydraulics risk coordinates and use the corresponding corridor definitions.  
   - For `region='Phoenix-AZ'`, use region-specific thresholds and ingest windows.

### 3.3. Creating new shards

When asked to generate a new shard (CSV or ALN):

1. **Choose a base pattern**:

   - Query `qpu_shard_catalog` for shards with similar `primary_plane`, `region`, and `preferred_role`.  
   - Mirror naming conventions (e.g., `PhoenixWaterWaste_qpudatashard.csv`) and directory placement (`qpudatashards/particles`).

2. **Select or define `schema_ref`**:

   - Prefer existing schema shards (e.g., `EcoNetSchemaShard2026v2.aln`, `IngestRcalibPhoenix2026v1.aln`).  
   - Only introduce new schemas when necessary, and ensure they are added to the ALN schema registry and linked back via `schema_ref`.

3. **Update the catalog**:

   - After creating the file, agents (or CI tasks) should run `shard-indexer` to update `qpu_shard_catalog`, or write a new row explicitly with the correct metadata.  
   - The entry must set `repo_name`, `rel_dir`, `file_name`, `file_ext`, `shard_kind`, `primary_plane`, `region`, `preferred_role`, and `schema_ref` where applicable.

This ensures that every new shard is immediately discoverable and wired into the ecosystem.

## 4. Responsibilities of tools and CI

- `tools/shard-indexer` is responsible for:

  - Walking `qpudatashards/particles` in a repo.  
  - Computing `content_hash` and `size_bytes`.  
  - Inferring initial values for `shard_kind`, `primary_plane`, `region`, `shard_version`, `preferred_role`, and `schema_ref` based on filenames and known patterns.

- CI jobs should:

  - Run the indexer after changes to qpudatashards.  
  - Validate that shards with certain roles (e.g., `GOVERNANCE_LOG`, `KERNEL_INPUT`) have a valid `schema_ref`.  
  - Optionally enforce naming conventions for shards in critical planes and regions.

## 5. Best practices for agents

- Never write directly into governance log shards (`GOVERNANCE_LOG`) unless you are the designated GOV or Virta-Sys component.  
- When generating ingest or kernel code, always align column names and types with the ALN schema referenced by `schema_ref`.  
- Prefer reusing existing shard patterns (names, directory structure, schema) to keep the constellation coherent and predictable.  
- When in doubt, query `qpu_shard_catalog` first; do not assume filenames or structures.

By following this spec, agents and tools can treat `qpu_shard_catalog` as the wiring map for qpudatashards, leading to higher-quality, governance-aligned code and file generation across the entire EcoNet constellation.
