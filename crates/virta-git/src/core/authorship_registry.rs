use crate::VirtaGitConfig;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use thiserror::Error;
use tokio::sync::RwLock;
use uuid::Uuid;

/// A single authorship record, aligned with Typewriter semantics and Virta-Git policies.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthorshipRecord {
    pub record_id: Uuid,
    pub rights_holder_id: String,
    pub rights_holder_name: String,
    pub rights_holder_role: String,
    pub repository_id: String,
    pub repository_url: String,
    pub commit_hash: String,
    pub claim_scope: ClaimScope,
    pub claims: Vec<String>,
    pub signed_metadata_reference: String,
    pub vm_cluster_signal_reference: String,
    pub created_at_utc: DateTime<Utc>,
    pub verification_status: VerificationStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ClaimScope {
    Repository,
    Subtree { path_prefix: String },
    File { path: String },
    Concept { identifier: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum VerificationStatus {
    Pending,
    Verified,
    Rejected { reason: String },
}

/// Errors emitted by the AuthorshipRegistry.
#[derive(Debug, Error)]
pub enum AuthorshipRegistryError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("serialization error: {0}")]
    SerdeJson(#[from] serde_json::Error),

    #[error("invalid configuration: {0}")]
    InvalidConfig(String),

    #[error("unknown rights holder: {0}")]
    UnknownRightsHolder(String),
}

/// Authorship registry for Virta-Git, backed by JSONL storage and aligned with Typewriter.
#[derive(Debug, Clone)]
pub struct AuthorshipRegistry {
    config: Arc<VirtaGitConfig>,
    storage_path: PathBuf,
    records: Arc<RwLock<HashMap<Uuid, AuthorshipRecord>>>,
}

impl AuthorshipRegistry {
    /// Create a new registry instance with an on-disk JSONL log.
    pub fn new(config: Arc<VirtaGitConfig>, storage_root: impl Into<PathBuf>) -> Result<Self, AuthorshipRegistryError> {
        if !config.authorship.typewriter_binding {
            return Err(AuthorshipRegistryError::InvalidConfig(
                "Virta-Git requires Typewriter binding for authorship".into(),
            ));
        }
        if !config.authorship.requirements.signed_metadata_required {
            return Err(AuthorshipRegistryError::InvalidConfig(
                "signed_metadata_required must be true for Virta-Git authorship".into(),
            ));
        }
        if !config.authorship.requirements.vm_cluster_signals_required {
            return Err(AuthorshipRegistryError::InvalidConfig(
                "vm_cluster_signals_required must be true for Virta-Git authorship".into(),
            ));
        }

        let mut storage_path: PathBuf = storage_root.into();
        storage_path.push("authorship_records.jsonl");
        if let Some(parent) = storage_path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        if !storage_path.exists() {
            std::fs::File::create(&storage_path)?;
        }

        Ok(Self {
            config,
            storage_path,
            records: Arc::new(RwLock::new(HashMap::new())),
        })
    }

    /// Load all existing records from disk into memory.
    pub async fn load(&self) -> Result<(), AuthorshipRegistryError> {
        let data = std::fs::read_to_string(&self.storage_path)?;
        let mut map = HashMap::new();

        for line in data.lines() {
            if line.trim().is_empty() {
                continue;
            }
            let record: AuthorshipRecord = serde_json::from_str(line)?;
            map.insert(record.record_id, record);
        }

        let mut lock = self.records.write().await;
        *lock = map;
        Ok(())
    }

    /// Append a new authorship record, ensuring the rights holder exists in config.
    pub async fn append(
        &self,
        repository_id: &str,
        repository_url: &str,
        commit_hash: &str,
        claim_scope: ClaimScope,
        signed_metadata_reference: &str,
        vm_cluster_signal_reference: &str,
        holder_id: &str,
    ) -> Result<AuthorshipRecord, AuthorshipRegistryError> {
        let holder = self
            .config
            .authorship
            .primary_rights_holders
            .iter()
            .find(|h| h.id == holder_id)
            .ok_or_else(|| AuthorshipRegistryError::UnknownRightsHolder(holder_id.to_string()))?;

        let record = AuthorshipRecord {
            record_id: Uuid::new_v4(),
            rights_holder_id: holder.id.clone(),
            rights_holder_name: holder.name.clone(),
            rights_holder_role: holder.role.clone(),
            repository_id: repository_id.to_string(),
            repository_url: repository_url.to_string(),
            commit_hash: commit_hash.to_string(),
            claim_scope,
            claims: holder.claims.clone(),
            signed_metadata_reference: signed_metadata_reference.to_string(),
            vm_cluster_signal_reference: vm_cluster_signal_reference.to_string(),
            created_at_utc: Utc::now(),
            verification_status: VerificationStatus::Pending,
        };

        {
            let mut lock = self.records.write().await;
            lock.insert(record.record_id, record.clone());
        }

        self.append_to_disk(&record)?;
        Ok(record)
    }

    /// Mark an existing record as verified.
    pub async fn mark_verified(&self, id: Uuid) -> Result<(), AuthorshipRegistryError> {
        let mut lock = self.records.write().await;
        if let Some(rec) = lock.get_mut(&id) {
            rec.verification_status = VerificationStatus::Verified;
            self.rewrite_all_to_disk(&lock.values().cloned().collect::<Vec<_>>())?;
        }
        Ok(())
    }

    /// Mark an existing record as rejected with a reason.
    pub async fn mark_rejected(&self, id: Uuid, reason: String) -> Result<(), AuthorshipRegistryError> {
        let mut lock = self.records.write().await;
        if let Some(rec) = lock.get_mut(&id) {
            rec.verification_status = VerificationStatus::Rejected { reason };
            self.rewrite_all_to_disk(&lock.values().cloned().collect::<Vec<_>>())?;
        }
        Ok(())
    }

    /// List all records.
    pub async fn list_all(&self) -> Vec<AuthorshipRecord> {
        let lock = self.records.read().await;
        lock.values().cloned().collect()
    }

    /// List records for a specific repository.
    pub async fn list_by_repository(&self, repository_id: &str) -> Vec<AuthorshipRecord> {
        let lock = self.records.read().await;
        lock.values()
            .cloned()
            .filter(|r| r.repository_id == repository_id)
            .collect()
    }

    /// List records for a specific rights holder.
    pub async fn list_by_holder(&self, holder_id: &str) -> Vec<AuthorshipRecord> {
        let lock = self.records.read().await;
        lock.values()
            .cloned()
            .filter(|r| r.rights_holder_id == holder_id)
            .collect()
    }

    fn append_to_disk(&self, record: &AuthorshipRecord) -> Result<(), AuthorshipRegistryError> {
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.storage_path)?;
        let line = serde_json::to_string(record)?;
        use std::io::Write;
        writeln!(file, "{}", line)?;
        Ok(())
    }

    fn rewrite_all_to_disk(&self, records: &[AuthorshipRecord]) -> Result<(), AuthorshipRegistryError> {
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .write(true)
            .truncate(true)
            .open(&self.storage_path)?;
        use std::io::Write;
        for rec in records {
            let line = serde_json::to_string(rec)?;
            writeln!(file, "{}", line)?;
        }
        Ok(())
    }
}
