// filename: src/lib.rs

use rusqlite::{Connection, NO_PARAMS};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepoIndex {
    pub repo_name: String,
    pub github_slug: String,
    pub role_band: String,
    pub visibility: String,
    pub language_primary: String,
    pub description: Option<String>,
    pub ecosafety_binding: String,
    pub shard_protocol: String,
    pub lane_default: String,
    pub ker_target_k: f64,
    pub ker_target_e: f64,
    pub ker_target_r: f64,
    pub non_actuating_only: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Layer {
    pub layer_name: String,
    pub layer_tier: String,
    pub languages: String,
    pub description: Option<String>,
    pub contracts: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoleHint {
    pub key: String,
    pub value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepoManifest {
    pub index: RepoIndex,
    pub layers: Vec<Layer>,
    pub hints: Vec<RoleHint>,
}

impl RepoManifest {
    pub fn ker_tuple(&self) -> (f64, f64, f64) {
        (
            self.index.ker_target_k,
            self.index.ker_target_e,
            self.index.ker_target_r,
        )
    }

    pub fn is_non_actuating(&self) -> bool {
        self.index.non_actuating_only
    }

    pub fn has_layer_named(&self, name: &str) -> bool {
        self.layers.iter().any(|l| l.layer_name == name)
    }
}

#[derive(Debug, thiserror::Error)]
pub enum ManifestError {
    #[error("IO error while reading manifest SQL: {0}")]
    Io(#[from] std::io::Error),

    #[error("SQLite error while loading manifest: {0}")]
    Sql(#[from] rusqlite::Error),

    #[error("No econet_repo_index row found in manifest SQL")]
    NoRepoIndex,

    #[error("Manifest file not found at {0}")]
    NotFound(String),
}

pub fn default_manifest_path(repo_root: &Path) -> PathBuf {
    repo_root.join(".econet").join("econet_repo_index.sql")
}

pub fn load_manifest_from_repo(repo_root: &Path) -> Result<RepoManifest, ManifestError> {
    let path = default_manifest_path(repo_root);
    if !path.exists() {
        return Err(ManifestError::NotFound(path.display().to_string()));
    }
    let sql = fs::read_to_string(&path)?;
    load_manifest_from_sql(&sql)
}

pub fn load_manifest_from_sql(sql: &str) -> Result<RepoManifest, ManifestError> {
    let conn = Connection::open_in_memory()?;
    conn.execute_batch(sql)?;

    let mut stmt = conn.prepare(
        r#"SELECT
               repo_name,
               github_slug,
               role_band,
               visibility,
               language_primary,
               description,
               ecosafety_binding,
               shard_protocol,
               lane_default,
               ker_target_k,
               ker_target_e,
               ker_target_r,
               non_actuating_only
           FROM econet_repo_index
           LIMIT 1"#,
    )?;

    let idx_iter = stmt.query_map(NO_PARAMS, |row| {
        Ok(RepoIndex {
            repo_name: row.get(0)?,
            github_slug: row.get(1)?,
            role_band: row.get(2)?,
            visibility: row.get(3)?,
            language_primary: row.get(4)?,
            description: row.get(5)?,
            ecosafety_binding: row.get(6)?,
            shard_protocol: row.get(7)?,
            lane_default: row.get(8)?,
            ker_target_k: row.get(9)?,
            ker_target_e: row.get(10)?,
            ker_target_r: row.get(11)?,
            non_actuating_only: {
                let v: i64 = row.get(12)?;
                v != 0
            },
        })
    })?;

    let index = idx_iter
        .into_iter()
        .next()
        .transpose()?
        .ok_or(ManifestError::NoRepoIndex)?;

    let mut layer_stmt = conn.prepare(
        r#"SELECT
               layer_name,
               layer_tier,
               languages,
               description,
               contracts
           FROM econet_layer
           WHERE repo_name = ?1
           ORDER BY layer_id ASC"#,
    )?;

    let layer_iter = layer_stmt.query_map([&index.repo_name], |row| {
        Ok(Layer {
            layer_name: row.get(0)?,
            layer_tier: row.get(1)?,
            languages: row.get(2)?,
            description: row.get(3)?,
            contracts: row.get(4)?,
        })
    })?;

    let mut layers = Vec::new();
    for layer in layer_iter {
        layers.push(layer?);
    }

    let mut hint_stmt = conn.prepare(
        r#"SELECT key, value
           FROM econet_role_hint
           WHERE repo_name = ?1
           ORDER BY hint_id ASC"#,
    )?;

    let hint_iter = hint_stmt.query_map([&index.repo_name], |row| {
        Ok(RoleHint {
            key: row.get(0)?,
            value: row.get(1)?,
        })
    })?;

    let mut hints = Vec::new();
    for hint in hint_iter {
        hints.push(hint?);
    }

    Ok(RepoManifest {
        index,
        layers,
        hints,
    })
}
