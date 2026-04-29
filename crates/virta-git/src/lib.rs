use serde::{Deserialize, Serialize};

pub mod core;
pub mod adapters;
pub mod services;

/// High-level Virta-Git manifest, loaded from `virta-git.config.json`.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct VirtaGitConfig {
    pub system: String,
    pub version: String,
    pub updated_at_utc: String,
    pub description: String,
    pub anchors: Anchors,
    pub repositories: RepositorySection,
    pub authorship: AuthorshipSection,
    pub policies: PolicySection,
    pub io_policies: IoPolicies,
    pub interaction_policy: InteractionPolicy,
    pub logging: LoggingSection,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Anchors {
    pub virta_sys: AnchorRef,
    pub vsc_artemis: AnchorRef,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AnchorRef {
    pub role: String,
    #[serde(default)]
    pub policy_ref: Option<String>,
    #[serde(default)]
    pub integration: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct RepositorySection {
    pub tracked: Vec<TrackedRepository>,
    pub constraints: RepoConstraints,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TrackedRepository {
    pub id: String,
    pub name: String,
    pub url: String,
    #[serde(rename = "type")]
    pub r#type: String,
    pub required: bool,
    pub policy_profile: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct RepoConstraints {
    pub require_signed_commits: bool,
    pub require_cryptographic_authorship: bool,
    pub allow_shallow_clones: bool,
    pub allow_untracked_repositories: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AuthorshipSection {
    pub typewriter_binding: bool,
    pub requirements: AuthorshipRequirements,
    pub primary_rights_holders: Vec<RightsHolder>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AuthorshipRequirements {
    pub signed_metadata_required: bool,
    pub vm_cluster_signals_required: bool,
    pub ownership_assertion_storage: String,
    pub dispute_evidence_storage: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct RightsHolder {
    pub id: String,
    pub name: String,
    pub role: String,
    pub claims: Vec<String>,
    pub verification: RightsHolderVerification,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct RightsHolderVerification {
    pub metadata_source: String,
    pub repository_signals: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct PolicySection {
    pub non_fiction: PolicyRef,
    pub progress_requirement: PolicyRef,
    pub authorship: PolicyRef,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct PolicyRef {
    pub config_path: String,
    pub enforced: bool,
    #[serde(default)]
    pub rules: Option<serde_json::Value>,
    #[serde(default)]
    pub acceptable_progress_types: Option<Vec<String>>,
    #[serde(default)]
    pub require_cryptographically_signed_authorship: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct IoPolicies {
    pub sanitization: SanitizationPolicy,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SanitizationPolicy {
    pub on_input: bool,
    pub pipeline: Vec<String>,
    pub fiction_detection: FictionDetection,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FictionDetection {
    pub mode: String,
    pub on_detection: DetectionActions,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct DetectionActions {
    pub actions: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct InteractionPolicy {
    pub progress_requirement: ProgressRequirement,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ProgressRequirement {
    pub enforced: bool,
    pub on_non_progress: DetectionActions,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct LoggingSection {
    pub audit_trail: AuditTrail,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AuditTrail {
    pub enabled: bool,
    pub scope: Vec<String>,
    pub storage_target: String,
}

impl VirtaGitConfig {
    /// Lightweight guard used at startup to ensure non-fiction and progress policies are enforced.
    pub fn validate_strict_policies(&self) -> Result<(), String> {
        if !self.policies.non_fiction.enforced {
            return Err("non_fiction policy must be enforced for Virta-Git".into());
        }
        if !self.interaction_policy.progress_requirement.enforced {
            return Err("progress_requirement policy must be enforced for Virta-Git".into());
        }
        Ok(())
    }
}
