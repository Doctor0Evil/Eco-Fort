-- filename dbalienfs_file_index.sql
-- destination Eco-Fort/db/dbalienfs_file_index.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS alienfs_file_index (
  file_id        INTEGER PRIMARY KEY AUTOINCREMENT,
  repotarget     TEXT NOT NULL,         -- e.g. "Alien-Filesystem"
  crate_name     TEXT NOT NULL,         -- e.g. "alienfs-core"
  phase          INTEGER NOT NULL CHECK (phase BETWEEN 1 AND 4),
  destination    TEXT NOT NULL,         -- e.g. "crates/alienfs-core/src/lib.rs"
  filename       TEXT NOT NULL,         -- e.g. "lib.rs"
  role           TEXT NOT NULL,         -- "code","sql","aln","doc","test"
  description    TEXT NOT NULL,
  active         INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  UNIQUE (repotarget, crate_name, destination, filename)
);

CREATE INDEX IF NOT EXISTS idx_alienfs_file_phase_role
  ON alienfs_file_index (phase, role);
