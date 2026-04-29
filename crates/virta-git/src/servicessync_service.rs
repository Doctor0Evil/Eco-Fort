use crate::core::repo_registry::{RepoHandle, RepoRegistry};
use crate::core::policy_engine::{PolicyEngine, ProgressType};
use crate::VirtaGitConfig;
use anyhow::Result;
use std::sync::Arc;

/// Sync service: focuses on re-fetching tracked repositories without creating new commits,
/// keeping Virta-Git aligned with remote state.[file:1]
#[derive(Debug, Clone)]
pub struct SyncService {
    config: Arc<VirtaGitConfig>,
    repo_registry: Arc<RepoRegistry>,
    policy_engine: Arc<PolicyEngine>,
}

impl SyncService {
    pub fn new(
        config: Arc<VirtaGitConfig>,
        repo_registry: Arc<RepoRegistry>,
        policy_engine: Arc<PolicyEngine>,
    ) -> Self {
        Self {
            config,
            repo_registry,
            policy_engine,
        }
    }

    /// Re-run materialization as a lightweight sync step, tagged as `config_refinement`.
    pub async fn sync_all(&self) -> Result<Vec<RepoHandle>> {
        self.policy_engine
            .enforce_progress(&ProgressType::ConfigRefinement)?;
        self.repo_registry.materialize_all().await?;
        Ok(self.repo_registry.list().await)
    }
}
