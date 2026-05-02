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
