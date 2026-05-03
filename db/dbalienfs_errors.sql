-- filename dbalienfs_errors.sql
-- destination Eco-Fort/db/dbalienfs_errors.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS alienfs_error_class (
  error_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  code         TEXT NOT NULL UNIQUE,      -- e.g. "GovernanceViolation"
  phase        INTEGER NOT NULL CHECK (phase BETWEEN 1 AND 4),
  shard_ref    TEXT NOT NULL,             -- ALN shard id, e.g. "AlienFSGovernanceCorridor2026v1"
  fatal        INTEGER NOT NULL CHECK (fatal IN (0,1)),
  description  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS alienfs_error_event (
  event_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  code         TEXT NOT NULL,
  phase        INTEGER NOT NULL CHECK (phase BETWEEN 1 AND 4),
  crate_name   TEXT NOT NULL,
  context      TEXT,                      -- JSON snippet, path, query, etc.
  created_utc  TEXT NOT NULL,             -- ISO-8601
  FOREIGN KEY (code) REFERENCES alienfs_error_class(code)
);
