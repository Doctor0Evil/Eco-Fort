// filename: src/migrations/constellation_index/migrations.rs
// destination: Eco-Fort/src/migrations/constellation_index/migrations.rs

use std::fs;
use std::path::{Path, PathBuf};

use rusqlite::{Connection, NO_PARAMS};

/// Location of the constellation index database file relative to the repo root.
///
/// Example on disk (Eco-Fort checkout):
///   Eco-Fort/var/db/constellation_index.db
const DB_REL_PATH: &str = "var/db/constellation_index.db";

/// Location of the seed SQL used to initialize the constellation index schema.
///
/// Example on disk:
///   Eco-Fort/db/eco_constellation_index.sql
const SEED_SQL_REL_PATH: &str = "db/eco_constellation_index.sql";

/// High-level error type for migration/initialization failures.
#[derive(thiserror::Error, Debug)]
pub enum ConstellationIndexError {
    #[error("I/O error while accessing paths or files: {0}")]
    Io(#[from] std::io::Error),

    #[error("SQLite error during constellation index migration: {0}")]
    Sqlite(#[from] rusqlite::Error),

    #[error("Seed SQL file not found at {0}")]
    SeedSqlMissing(String),
}

/// Helper structure representing an open constellation index database.
///
/// Agents should use this to execute read-only queries against the repo registry.
pub struct ConstellationIndexDb {
    conn: Connection,
}

impl ConstellationIndexDb {
    /// Opens the constellation index database, running migrations if needed.
    ///
    /// `repo_root` should point at the Eco-Fort repository root on disk.
    pub fn open_or_init<P: AsRef<Path>>(repo_root: P) -> Result<Self, ConstellationIndexError> {
        let db_path = repo_root.as_ref().join(DB_REL_PATH);

        if let Some(parent) = db_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let mut is_new = false;
        if !db_path.exists() {
            is_new = true;
        }

        let conn = Connection::open(&db_path)?;

        if is_new {
            run_seed_sql(&conn, repo_root.as_ref())?;
        } else {
            ensure_core_tables_exist(&conn)?;
        }

        Ok(Self { conn })
    }

    /// Returns all repositories in the constellation index.
    ///
    /// This is intended as a minimal query surface that other crates (or FFI layers)
    /// can call to discover repos and their role bands.
    pub fn list_repos(&self) -> Result<Vec<RepoRow>, ConstellationIndexError> {
        let mut stmt = self.conn.prepare(
            "SELECT name, github_slug, visibility, language_primary, role_band, description
             FROM repo
             ORDER BY role_band, name",
        )?;

        let rows = stmt
            .query_map(NO_PARAMS, |row| {
                Ok(RepoRow {
                    name: row.get(0)?,
                    github_slug: row.get(1)?,
                    visibility: row.get(2)?,
                    language_primary: row.get(3)?,
                    role_band: row.get(4)?,
                    description: row.get(5)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(rows)
    }

    /// Returns all repositories in a given role band, such as "SPINE" or "ENGINE".
    pub fn list_repos_by_role_band(
        &self,
        role_band: &str,
    ) -> Result<Vec<RepoRow>, ConstellationIndexError> {
        let mut stmt = self.conn.prepare(
            "SELECT name, github_slug, visibility, language_primary, role_band, description
             FROM repo
             WHERE role_band = ?
             ORDER BY name",
        )?;

        let rows = stmt
            .query_map([role_band], |row| {
                Ok(RepoRow {
                    name: row.get(0)?,
                    github_slug: row.get(1)?,
                    visibility: row.get(2)?,
                    language_primary: row.get(3)?,
                    role_band: row.get(4)?,
                    description: row.get(5)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(rows)
    }

    /// Returns a single repo row by its canonical name, if it exists.
    pub fn get_repo_by_name(
        &self,
        name: &str,
    ) -> Result<Option<RepoRow>, ConstellationIndexError> {
        let mut stmt = self.conn.prepare(
            "SELECT name, github_slug, visibility, language_primary, role_band, description
             FROM repo
             WHERE name = ?",
        )?;

        let mut rows = stmt.query([name])?;
        if let Some(row) = rows.next()? {
            Ok(Some(RepoRow {
                name: row.get(0)?,
                github_slug: row.get(1)?,
                visibility: row.get(2)?,
                language_primary: row.get(3)?,
                role_band: row.get(4)?,
                description: row.get(5)?,
            }))
        } else {
            Ok(None)
        }
    }

    /// Exposes the underlying rusqlite connection for advanced read-only queries.
    ///
    /// Write/migration operations should remain centralized here.
    pub fn connection(&self) -> &Connection {
        &self.conn
    }
}

/// A simple value type mirroring the `repo` table schema.
#[derive(Debug, Clone)]
pub struct RepoRow {
    pub name: String,
    pub github_slug: String,
    pub visibility: String,
    pub language_primary: String,
    pub role_band: String,
    pub description: Option<String>,
}

/// Runs the seed SQL script to initialize the constellation index database.
///
/// This function assumes the caller has already created the parent directory for the DB file.
fn run_seed_sql(
    conn: &Connection,
    repo_root: &Path,
) -> Result<(), ConstellationIndexError> {
    let seed_path: PathBuf = repo_root.join(SEED_SQL_REL_PATH);

    if !seed_path.exists() {
        return Err(ConstellationIndexError::SeedSqlMissing(
            seed_path.display().to_string(),
        ));
    }

    let sql = fs::read_to_string(&seed_path)?;

    conn.execute_batch(&sql)?;

    Ok(())
}

/// Ensures that the core tables exist in an already-initialized database.
///
/// If the database was created earlier by another version of the code, this provides
/// a light sanity check before we expose it to agents.
fn ensure_core_tables_exist(conn: &Connection) -> Result<(), ConstellationIndexError> {
    // We intentionally keep this very simple; more complex migrations can be
    // layered on top later if needed.
    conn.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'repo_role_band'",
        NO_PARAMS,
    )?;

    conn.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'repo'",
        NO_PARAMS,
    )?;

    Ok(())
}
