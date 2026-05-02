-- filename: migrations/018_blastradius.sql

-- One row per blast-radius descriptor.
CREATE TABLE IF NOT EXISTS blastradius (
    blastradius_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    -- H3 / ISEA3H index or equivalent hex-cell key.
    hex_index         TEXT NOT NULL,
    -- Radius in adjacency hops (integer), not meters.
    adjacency_depth   INTEGER NOT NULL CHECK (adjacency_depth >= 0),
    -- Temporal influence window in milliseconds.
    adjacency_decay_ms INTEGER NOT NULL CHECK (adjacency_decay_ms >= 0),
    -- K/E/R tag for primary risk mode of this radius ('K','E','R').
    ker_tag           TEXT NOT NULL CHECK (ker_tag IN ('K','E','R')),
    -- Contract / invariant reference (e.g. 'blast-radius.v1', RoH tag).
    roh_anchor_hex    TEXT NOT NULL,
    -- Immutable spec: once frozen=1, row is read-only by CI policy.
    frozen            INTEGER NOT NULL DEFAULT 0 CHECK (frozen IN (0,1)),
    UNIQUE (hex_index, adjacency_depth, adjacency_decay_ms, ker_tag)
);

-- Attach blast-radius to shards and catalog entries.
ALTER TABLE shardinstance
    ADD COLUMN blastradius_id INTEGER
        REFERENCES blastradius(blastradius_id)
        ON DELETE SET NULL;

-- qpushardcatalog is not fully defined in the exposed text, but we can
-- safely add a foreign-key stub for when it exists.
CREATE TABLE IF NOT EXISTS qpushardcatalog (
    catalog_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    shardid           INTEGER NOT NULL
                         REFERENCES shardinstance(shardid)
                         ON DELETE CASCADE,
    -- FG: link to blast radius, if this shard carries an influence zone.
    blastradius_id    INTEGER
                         REFERENCES blastradius(blastradius_id)
                         ON DELETE SET NULL,
    -- Additional lineage / topology fields can be added as you freeze them.
    lineage_tag_hex   TEXT,
    roh_anchor_hex    TEXT
);
CREATE INDEX IF NOT EXISTS idx_qpushardcatalog_blast
    ON qpushardcatalog (blastradius_id);
