// filename: src/shards/mod.rs
// destination: Virta-Sys/src/shards/mod.rs

//! Shard querying API for Virta-Sys.
//!
//! This module provides typed accessors over the `qpu_shard_catalog`
//! (and optional `qpu_shard_tag`) tables so that Virta-Sys and agents
//! can discover qpudatashards by plane, region, role, and schema.
//!
//! All higher-level components (lane governor, placement advisor, etc.)
//! should use these functions instead of issuing ad hoc SQL.

use std::path::PathBuf;

use anyhow::Result;
use rusqlite::{params, Connection, Row};

#[derive(Debug, Clone)]
pub struct ShardRecord {
    pub shard_id: i64,
    pub repo_name: String,
    pub rel_dir: String,
    pub file_name: String,
    pub file_ext: String,
    pub content_hash: Option<String>,
    pub size_bytes: Option<i64>,
    pub shard_kind: String,
    pub primary_plane: Option<String>,
    pub region: Option<String>,
    pub shard_version: Option<String>,
    pub preferred_role: Option<String>,
    pub schema_ref: Option<String>,
}

impl ShardRecord {
    fn from_row(row: &Row<'_>) -> rusqlite::Result<Self> {
        Ok(Self {
            shard_id: row.get("shard_id")?,
            repo_name: row.get("repo_name")?,
            rel_dir: row.get("rel_dir")?,
            file_name: row.get("file_name")?,
            file_ext: row.get("file_ext")?,
            content_hash: row.get("content_hash")?,
            size_bytes: row.get("size_bytes")?,
            shard_kind: row.get("shard_kind")?,
            primary_plane: row.get("primary_plane")?,
            region: row.get("region")?,
            shard_version: row.get("shard_version")?,
            preferred_role: row.get("preferred_role")?,
            schema_ref: row.get("schema_ref")?,
        })
    }

    pub fn full_path(&self, repo_root: &PathBuf) -> PathBuf {
        repo_root.join(&self.rel_dir).join(&self.file_name)
    }
}

/// Find shards by plane, region, and role.
///
/// Typical use: find ingest/evidence shards for a given plane+region
/// before generating code or making decisions.
pub fn find_shards_by_plane_region_role(
    conn: &Connection,
    repo_name: &str,
    primary_plane: &str,
    region: &str,
    preferred_role: Option<&str>,
) -> Result<Vec<ShardRecord>> {
    let mut sql = String::from(
        r#"
        SELECT
            shard_id, repo_name, rel_dir, file_name, file_ext,
            content_hash, size_bytes,
            shard_kind, primary_plane, region,
            shard_version, preferred_role, schema_ref
        FROM qpu_shard_catalog
        WHERE repo_name     = :repo_name
          AND primary_plane = :primary_plane
          AND region        = :region
          AND active        = 1
        "#,
    );

    if preferred_role.is_some() {
        sql.push_str(" AND preferred_role = :preferred_role");
    }

    let mut stmt = conn.prepare(&sql)?;
    let shards = stmt
        .query_map(
            params![
                repo_name,
                primary_plane,
                region,
                preferred_role.unwrap_or(""),
            ],
            ShardRecord::from_row,
        )?
        .filter_map(|res| res.ok())
        .collect();

    Ok(shards)
}

/// Find all schema shards in a repo.
///
/// Useful when agents need to know which ALN schemas are available
/// before generating new qpudatashards.
pub fn list_schema_shards(conn: &Connection, repo_name: &str) -> Result<Vec<ShardRecord>> {
    let mut stmt = conn.prepare(
        r#"
        SELECT
            shard_id, repo_name, rel_dir, file_name, file_ext,
            content_hash, size_bytes,
            shard_kind, primary_plane, region,
            shard_version, preferred_role, schema_ref
        FROM qpu_shard_catalog
        WHERE repo_name = :repo_name
          AND shard_kind = 'SCHEMA'
          AND active = 1
        ORDER BY file_name;
        "#,
    )?;

    let shards = stmt
        .query_map(params![repo_name], ShardRecord::from_row)?
        .filter_map(|res| res.ok())
        .collect();

    Ok(shards)
}

/// Get a shard by exact file name.
///
/// Use when a request refers to a specific shard file.
pub fn get_shard_by_name(
    conn: &Connection,
    repo_name: &str,
    file_name: &str,
) -> Result<Option<ShardRecord>> {
    let mut stmt = conn.prepare(
        r#"
        SELECT
            shard_id, repo_name, rel_dir, file_name, file_ext,
            content_hash, size_bytes,
            shard_kind, primary_plane, region,
            shard_version, preferred_role, schema_ref
        FROM qpu_shard_catalog
        WHERE repo_name = :repo_name
          AND file_name = :file_name
          AND active = 1
        LIMIT 1;
        "#,
    )?;

    let rec = stmt
        .query_row(params![repo_name, file_name], ShardRecord::from_row)
        .optional()?;

    Ok(rec)
}

/// Find shards that are likely good inputs for Virta-Sys governance tasks.
///
/// Example: evidence for Phoenix hydraulics used by lane-governor or placement advisor.
pub fn find_governance_evidence_shards(
    conn: &Connection,
    repo_name: &str,
    primary_plane: &str,
    region: &str,
) -> Result<Vec<ShardRecord>> {
    let mut stmt = conn.prepare(
        r#"
        SELECT
            shard_id, repo_name, rel_dir, file_name, file_ext,
            content_hash, size_bytes,
            shard_kind, primary_plane, region,
            shard_version, preferred_role, schema_ref
        FROM qpu_shard_catalog
        WHERE repo_name     = :repo_name
          AND primary_plane = :primary_plane
          AND region        = :region
          AND shard_kind    IN ('QPUDATASHARD','EVIDENCE')
          AND active        = 1
        ORDER BY file_name;
        "#,
    )?;

    let shards = stmt
        .query_map(params![repo_name, primary_plane, region], ShardRecord::from_row)?
        .filter_map(|res| res.ok())
        .collect();

    Ok(shards)
}
