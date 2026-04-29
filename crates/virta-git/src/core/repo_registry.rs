use crate::VirtaGitConfig;
use git2::{Cred, Error as GitError, FetchOptions, RemoteCallbacks, Repository};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use thiserror::Error;
use tokio::sync::RwLock;

/// In-memory registry of all tracked repositories defined in Virta-Git config.
#[derive(Debug, Clone)]
pub struct RepoRegistry {
    config: Arc<VirtaGitConfig>,
    roots: PathBuf,
    repos: Arc<RwLock<HashMap<String, RepoHandle>>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepoHandle {
    pub id: String,
    pub name: String,
    pub url: String,
    pub local_path: PathBuf,
    pub required: bool,
    pub policy_profile: String,
}

/// Errors emitted by the RepoRegistry.
#[derive(Debug, Error)]
pub enum RepoRegistryError {
    #[error("git error: {0}")]
    Git(#[from] GitError),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("missing required repository: {0}")]
    MissingRequiredRepo(String),

    #[error("invalid configuration: {0}")]
    InvalidConfig(String),
}

impl RepoRegistry {
    /// Create a new registry from config and a root directory where all repos will be stored.
    pub fn new(config: Arc<VirtaGitConfig>, roots: impl AsRef<Path>) -> Result<Self, RepoRegistryError> {
        if !config.repositories.constraints.require_signed_commits {
            return Err(RepoRegistryError::InvalidConfig(
                "Virta-Git requires signed commits for all tracked repositories".into(),
            ));
        }
        if !config.repositories.constraints.require_cryptographic_authorship {
            return Err(RepoRegistryError::InvalidConfig(
                "Virta-Git requires cryptographic authorship enforcement".into(),
            ));
        }

        let roots = roots.as_ref().to_path_buf();
        std::fs::create_dir_all(&roots)?;

        Ok(Self {
            config,
            roots,
            repos: Arc::new(RwLock::new(HashMap::new())),
        })
    }

    /// Returns the directory where repositories are stored.
    pub fn root_dir(&self) -> &Path {
        &self.roots
    }

    /// Materialize all tracked repositories locally (clone if missing, fetch if present).
    /// This is the main entry used by higher layers to ensure a consistent Git state.
    pub async fn materialize_all(&self) -> Result<(), RepoRegistryError> {
        let tracked = self.config.repositories.tracked.clone();
        for repo in tracked {
            let local_path = self.roots.join(&repo.id);
            let handle = self.clone_or_fetch_repo(
                &repo.id,
                &repo.name,
                &repo.url,
                &local_path,
                repo.required,
                &repo.policy_profile,
            )?;

            let mut lock = self.repos.write().await;
            lock.insert(repo.id.clone(), handle);
        }

        // Verify that all required repositories are present
        self.ensure_required_present().await?;
        Ok(())
    }

    /// Get a handle for a repository by ID.
    pub async fn get(&self, id: &str) -> Option<RepoHandle> {
        let lock = self.repos.read().await;
        lock.get(id).cloned()
    }

    /// List all registered repositories.
    pub async fn list(&self) -> Vec<RepoHandle> {
        let lock = self.repos.read().await;
        lock.values().cloned().collect()
    }

    fn clone_or_fetch_repo(
        &self,
        id: &str,
        name: &str,
        url: &str,
        local_path: &Path,
        required: bool,
        policy_profile: &str,
    ) -> Result<RepoHandle, RepoRegistryError> {
        let repo = if local_path.exists() {
            let repo = Repository::open(local_path)?;
            Self::fetch_default_remote(&repo, url)?;
            repo
        } else {
            // Constraints from config: no shallow clone, full history required.
            let mut builder = git2::build::RepoBuilder::new();
            let mut callbacks = Self::default_callbacks();
            let mut fetch_opts = FetchOptions::new();
            fetch_opts.remote_callbacks(callbacks);
            builder.fetch_options(fetch_opts);
            builder.clone(url, local_path)?
        };

        // Optionally, future extension: enforce signed commits here by scanning refs.
        // For now this is delegated to compliance_service.

        Ok(RepoHandle {
            id: id.to_string(),
            name: name.to_string(),
            url: url.to_string(),
            local_path: local_path.to_path_buf(),
            required,
            policy_profile: policy_profile.to_string(),
        })
    }

    fn default_callbacks() -> RemoteCallbacks<'static> {
        let mut callbacks = RemoteCallbacks::new();
        callbacks.credentials(|_url, username_from_url, _allowed_types| {
            // For public GitHub repos, anonymous HTTPS is sufficient.
            // If authentication is required, this hook can be extended to use tokens.
            Cred::credential_helper(
                &Repository::discover(".").unwrap_or_else(|_| Repository::init_bare(".git").unwrap()),
                username_from_url.unwrap_or("git"),
                None,
            )
        });
        callbacks
    }

    fn fetch_default_remote(repo: &Repository, url: &str) -> Result<(), GitError> {
        let mut remote = match repo.find_remote("origin") {
            Ok(r) => r,
            Err(_) => repo.remote("origin", url)?,
        };

        let mut callbacks = Self::default_callbacks();
        let mut fetch_opts = FetchOptions::new();
        fetch_opts.remote_callbacks(callbacks);

        remote.fetch(&["refs/heads/*:refs/heads/*"], Some(&mut fetch_opts), None)?;
        Ok(())
    }

    async fn ensure_required_present(&self) -> Result<(), RepoRegistryError> {
        let lock = self.repos.read().await;
        for repo in &self.config.repositories.tracked {
            if repo.required && !lock.contains_key(&repo.id) {
                return Err(RepoRegistryError::MissingRequiredRepo(repo.id.clone()));
            }
        }
        Ok(())
    }
}
