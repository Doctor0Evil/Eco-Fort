use crate::core::repo_registry::{RepoHandle, RepoRegistry};
use crate::core::policy_engine::{PolicyEngine, ProgressType};
use crate::VirtaGitConfig;
use anyhow::Result;
use std::sync::Arc;

/// Ingest service: ensures tracked repositories are materialized and treated as a single
/// Virta-Git input surface, while marking each run as progress for policy purposes.[file:1]
#[derive(Debug, Clone)]
pub struct IngestService {
    config: Arc<VirtaGitConfig>,
    repo_registry: Arc<RepoRegistry>,
    policy_engine: Arc<PolicyEngine>,
}

impl IngestService {
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

    /// Materialize all tracked repositories; this is treated as a `config_refinement`
    /// progress type, since it updates concrete Git state.[file:1]
    pub async fn ingest_all(&self) -> Result<Vec<RepoHandle>> {
        self.policy_engine
            .enforce_progress(&ProgressType::ConfigRefinement)?;
        self.repo_registry.materialize_all().await?;
        Ok(self.repo_registry.list().await)
    }
}
