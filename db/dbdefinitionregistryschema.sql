-- filename dbdefinitionregistryschema.sql
-- destination Eco-Fort/db/dbdefinitionregistryschema.sql

CREATE TABLE IF NOT EXISTS definitionregistry (
  dr_id          TEXT PRIMARY KEY, -- e.g. DR-ENERGY-IDLE-CONGESTION
  kind           TEXT NOT NULL,    -- PLANE, COORDINATE, FUNCTIONAL, POLICY
  short_spec     TEXT NOT NULL,    -- one-paragraph prose
  aln_path       TEXT NOT NULL,    -- repo-relative path to .aln file
  sql_path       TEXT NOT NULL,    -- repo-relative path to .sql schema/view
  rust_path      TEXT,             -- optional primary Rust module path
  contract_name  TEXT NOT NULL,    -- e.g. EcosafetyPlaneWeights2026v1
  issuedutc      TEXT NOT NULL,
  active         INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);
