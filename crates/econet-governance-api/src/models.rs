// filename: src/models.rs
// destination: Eco-Fort/crates/econet-governance-api/src/models.rs
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum GovernanceError {
    #[error("Database error: {0}")]
    Db(#[from] rusqlite::Error),
    #[error("Not found: {0}")]
    NotFound(String),
    #[error("Invalid invariant: {0}")]
    InvariantViolation(String),
}

pub type Result<T> = std::result::Result<T, GovernanceError>;

#[derive(Debug, Serialize, Deserialize)]
pub struct LaneDecision {
    pub workload_id: String,
    pub target_lane: String,
    pub is_admissible: bool,
    pub k_avg: f64,
    pub e_avg: f64,
    pub r_avg: f64,
    pub vt_trend: f64,
    pub issued_utc: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PlacementVerdict {
    pub workload_id: String,
    pub node_id: String,
    pub admissible: bool,
    pub j_cost: f64,
    pub non_offsettable_ok: bool,
    pub issued_utc: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TopologyStatus {
    pub scope_kind: String,
    pub scope_ref: String,
    pub r_topology: f64,
    pub n_missing_manifest: i64,
    pub n_mislabel_role: i64,
    pub last_audit_utc: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ContractStatus {
    pub workload_id: String,
    pub repo_name: String,
    pub trait_name: String,
    pub verified_status: String,
    pub compliance_state: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpgradeRecord {
    pub target_scope: String,
    pub target_ref: String,
    pub version_to: String,
    pub k_before: f64,
    pub e_before: f64,
    pub r_before: f64,
    pub vt_before: f64,
    pub k_after: f64,
    pub e_after: f64,
    pub r_after: f64,
    pub vt_after: f64,
    pub authorized_did: String,
    pub evidence_before_hex: Option<String>,
    pub evidence_after_hex: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ShardQuery {
    pub repo_name: String,
    pub primary_plane: String,
    pub region: String,
    pub preferred_role: Option<String>,
}
