use anyhow::Result;
use git2::{Commit, Oid, Repository, Signature};
use std::path::{Path, PathBuf};

/// Thin adapter over `git2` to expose commit-level operations in a Virta-Git–friendly way.
///
/// This module does NOT invent content; it only reads and writes concrete Git state.
pub struct GitCli {
    repo: Repository,
    repo_path: PathBuf,
}

pub struct CommitSummary {
    pub id: String,
    pub author_name: String,
    pub author_email: String,
    pub message: String,
}

impl GitCli {
    /// Open a repository at the given path.
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let repo = Repository::open(path.as_ref())?;
        Ok(Self {
            repo,
            repo_path: path.as_ref().to_path_buf(),
        })
    }

    /// Return the local path of this repository.
    pub fn path(&self) -> &Path {
        &self.repo_path
    }

    /// Get the current HEAD commit, if any.
    pub fn head_commit(&self) -> Result<Option<CommitSummary>> {
        let head = match self.repo.head() {
            Ok(h) => h,
            Err(_) => return Ok(None),
        };
        let oid = head.target().ok_or_else(|| anyhow::anyhow!("HEAD has no target"))?;
        let commit = self.repo.find_commit(oid)?;
        Ok(Some(Self::to_summary(&commit)))
    }

    /// List the last `limit` commits on the current HEAD.
    pub fn recent_commits(&self, limit: usize) -> Result<Vec<CommitSummary>> {
        let mut revwalk = self.repo.revwalk()?;
        revwalk.push_head()?;
        revwalk.simplify_first_parent();

        let mut results = Vec::new();
        for (idx, oid_res) in revwalk.enumerate() {
            if idx >= limit {
                break;
            }
            let oid = oid_res?;
            let commit = self.repo.find_commit(oid)?;
            results.push(Self::to_summary(&commit));
        }
        Ok(results)
    }

    /// Create a new commit on top of HEAD, given an already-updated index tree.
    /// This function assumes the caller has updated the index with real file changes.
    pub fn commit_all(
        &self,
        author_name: &str,
        author_email: &str,
        message: &str,
    ) -> Result<String> {
        let sig = Signature::now(author_name, author_email)?;
        let mut index = self.repo.index()?;
        let tree_oid = index.write_tree()?;
        let tree = self.repo.find_tree(tree_oid)?;

        let parent_commit = match self.repo.head() {
            Ok(head) => {
                if let Some(oid) = head.target() {
                    Some(self.repo.find_commit(oid)?)
                } else {
                    None
                }
            }
            Err(_) => None,
        };

        let oid = if let Some(parent) = parent_commit {
            self.repo
                .commit(Some("HEAD"), &sig, &sig, message, &tree, &[&parent])?
        } else {
            self.repo
                .commit(Some("HEAD"), &sig, &sig, message, &tree, &[])?
        };

        Ok(oid.to_string())
    }

    /// Utility: convert a `git2::Commit` into a plain struct.
    fn to_summary(commit: &Commit) -> CommitSummary {
        let author = commit.author();
        CommitSummary {
            id: commit.id().to_string(),
            author_name: author.name().unwrap_or("unknown").to_string(),
            author_email: author.email().unwrap_or("unknown").to_string(),
            message: commit.summary().unwrap_or("").to_string(),
        }
    }

    /// Resolve a commit hash into a summary, if it exists.
    pub fn resolve_commit(&self, oid: &str) -> Result<Option<CommitSummary>> {
        let oid = match Oid::from_str(oid) {
            Ok(o) => o,
            Err(_) => return Ok(None),
        };
        match self.repo.find_commit(oid) {
            Ok(c) => Ok(Some(Self::to_summary(&c))),
            Err(_) => Ok(None),
        }
    }
}
