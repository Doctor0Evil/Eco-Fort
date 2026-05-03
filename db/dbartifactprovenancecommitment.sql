-- filename dbartifactprovenancecommitment.sql
-- destination Eco-Fort/db/dbartifactprovenancecommitment.sql

CREATE TABLE IF NOT EXISTS artifactprovenance_commitment (
  commitment_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  createdutc      TEXT    NOT NULL,
  scope           TEXT    NOT NULL, -- e.g. CONSTELLATION, REPO
  scoperef        TEXT    NOT NULL,
  root_hash       TEXT    NOT NULL, -- hex root over per-artifact heads
  signingdid      TEXT    NOT NULL
);
