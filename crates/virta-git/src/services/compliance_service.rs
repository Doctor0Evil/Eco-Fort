use crate::core::authorship_registry::{AuthorshipRecord, AuthorshipRegistry, AuthorshipRegistryError, ClaimScope};
use crate::core::repo_registry::{RepoHandle, RepoRegistry, RepoRegistryError};
use crate::core::policy_engine::{ContentClassification, PolicyEngine, PolicyError, ProgressType};
use crate::adapters::git_cli::{CommitSummary, GitCli};
use crate::VirtaGitConfig;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use thiserror::Error;
use tokio::sync::RwLock;

/// Composite compliance error type surfacing all underlying domains.
#[derive(Debug, Error)]
pub enum ComplianceError {
    #[error("repo registry error: {0}")]
    RepoRegistry(#[from] RepoRegistryError),

    #[error("authorship registry error: {0}")]
    AuthorshipRegistry(#[from] AuthorshipRegistryError),

    #[error("policy error: {0}")]
    Policy(#[from] PolicyError),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("generic error: {0}")]
    Generic(String),
}

/// Result of validating a single commit against Virta-Git policies.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommitComplianceReport {
    pub repository_id: String,
    pub commit_id: String,
    pub non_fiction_ok: bool,
    pub progress_ok: bool,
    pub authorship_record_id: Option<String>,
}

/// High-level compliance service that ties together:
/// - RepoRegistry (concrete Git repos),
/// - PolicyEngine (non-fiction and progress),
/// - AuthorshipRegistry (Typewriter-style authorship).
#[derive(Debug, Clone)]
pub struct ComplianceService {
    config: Arc<VirtaGitConfig>,
    repo_registry: Arc<RepoRegistry>,
    authorship_registry: Arc<AuthorshipRegistry>,
    policy_engine: Arc<PolicyEngine>,
    reports: Arc<RwLock<Vec<CommitComplianceReport>>>,
}

impl ComplianceService {
    pub fn new(
        config: Arc<VirtaGitConfig>,
        repo_registry: Arc<RepoRegistry>,
        authorship_registry: Arc<AuthorshipRegistry>,
        policy_engine: Arc<PolicyEngine>,
    ) -> Self {
        Self {
            config,
            repo_registry,
            authorship_registry,
            policy_engine,
            reports: Arc::new(RwLock::new(Vec::new())),
        }
    }

    /// Validate the latest commit of all tracked repositories.
    pub async fn validate_all_latest(&self) -> Result<Vec<CommitComplianceReport>, ComplianceError> {
        let repos = self.repo_registry.list().await;
        let mut out = Vec::new();

        for repo in repos {
            if let Some(report) = self.validate_latest_commit(&repo).await? {
                out.push(report);
            }
        }

        let mut lock = self.reports.write().await;
        lock.extend(out.clone());
        Ok(out)
    }

    /// Validate the latest commit of a specific repository.
    pub async fn validate_latest_commit(
        &self,
        repo: &RepoHandle,
    ) -> Result<Option<CommitComplianceReport>, ComplianceError> {
        let git = GitCli::open(&repo.local_path)?;
        let head = match git.head_commit()? {
            Some(h) => h,
            None => return Ok(None),
        };

        // Step 1: classify content at a coarse level.
        let classification = self.classify_commit(&git, &head)?;

        // Step 2: enforce non-fiction policy.
        self.policy_engine.enforce_non_fiction(&classification)?;

        // Step 3: enforce progress requirement; here, we treat each validated commit as a new code asset.
        self.policy_engine
            .enforce_progress(&ProgressType::NewCodeAsset)?;

        // Step 4: create an authorship record anchored to this commit.
        let holder_id = self
            .config
            .authorship
            .primary_rights_holders
            .get(0)
            .map(|h| h.id.clone())
            .ok_or_else(|| ComplianceError::Generic("no primary rights holder configured".into()))?;

        let authorship_record = self
            .authorship_registry
            .append(
                &repo.id,
                &repo.url,
                &head.id,
                ClaimScope::Repository,
                "TYPEWRITER:SIGNED-METADATA-PLACEHOLDER",
                "VM-CLUSTER-SIGNAL-PLACEHOLDER",
                &holder_id,
            )
            .await?;

        let report = CommitComplianceReport {
            repository_id: repo.id.clone(),
            commit_id: head.id.clone(),
            non_fiction_ok: true,
            progress_ok: true,
            authorship_record_id: Some(authorship_record.record_id.to_string()),
        };

        Ok(Some(report))
    }

    /// Very coarse classification: for this initial wiring, only the presence of a commit message
    /// and repository URL are treated as real-world anchors.[file:1]
    fn classify_commit(&self, git: &GitCli, head: &CommitSummary) -> Result<ContentClassification, ComplianceError> {
        let has_real_world_anchors = !head.message.trim().is_empty() && git.path().exists();

        // In this initial version, Virta-Git does not attempt to infer fiction from commit text.
        // All fictional/hypothetical/theoretical flags are false, and higher layers can plug in
        // more advanced detectors if needed.[file:1]
        Ok(ContentClassification {
            has_fictional_indicators: false,
            has_hypothetical_indicators: false,
            has_theoretical_only_indicators: false,
            has_real_world_anchors,
        })
    }

    /// Retrieve all stored compliance reports.
    pub async fn reports(&self) -> Vec<CommitComplianceReport> {
        let lock = self.reports.read().await;
        lock.clone()
    }
}
