-- filename dbalienfs_crate_graph.sql
-- destination Eco-Fort/db/dbalienfs_crate_graph.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS alienfs_crate (
  crate_id      INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL UNIQUE,    -- e.g. "alienfs-core"
  phase         INTEGER NOT NULL CHECK (phase BETWEEN 1 AND 4),
  description   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS alienfs_crate_dep (
  dep_id        INTEGER PRIMARY KEY AUTOINCREMENT,
  from_crate    TEXT NOT NULL,
  to_crate      TEXT NOT NULL,
  allowed       INTEGER NOT NULL DEFAULT 1 CHECK (allowed IN (0,1)),
  note          TEXT,
  UNIQUE (from_crate, to_crate),
  FOREIGN KEY (from_crate) REFERENCES alienfs_crate(name),
  FOREIGN KEY (to_crate)   REFERENCES alienfs_crate(name)
);

-- Seed AlienFS phases.
INSERT OR IGNORE INTO alienfs_crate (name, phase, description) VALUES
  ('alienfs-core',  1, 'Phase 1 VFS, path invariants, mount caps, governance clamps'),
  ('alienfs-index', 2, 'Phase 2 indexing, SQLite schemas, staleness metrics'),
  ('alienfs-graph', 3, 'Phase 3 dependency graph and governance checks'),
  ('alienfs-ai',    4, 'Phase 4 AI surface, ReadSession, token budgets');

-- Allowed dependency edges (downwards only).
INSERT OR IGNORE INTO alienfs_crate_dep (from_crate, to_crate, allowed, note) VALUES
  ('alienfs-core',  'alienfs-core',  1, 'Self'),
  ('alienfs-index', 'alienfs-core',  1, 'Index depends on VFS and invariants'),
  ('alienfs-graph', 'alienfs-core',  1, 'Graph depends on VFS and invariants'),
  ('alienfs-graph', 'alienfs-index', 1, 'Graph depends on SearchIndex'),
  ('alienfs-ai',    'alienfs-core',  1, 'AI surface uses VFS'),
  ('alienfs-ai',    'alienfs-index', 1, 'AI surface uses SearchIndex'),
  ('alienfs-ai',    'alienfs-graph', 1, 'AI surface uses DependencyGraph');
