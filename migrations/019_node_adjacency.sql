-- filename: migrations/019_node_adjacency.sql

CREATE TABLE IF NOT EXISTS node_adjacency (
    edge_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    from_nodeid      TEXT NOT NULL,
    to_nodeid        TEXT NOT NULL,
    -- Hop distance (typically 1).
    hop_weight       INTEGER NOT NULL DEFAULT 1 CHECK (hop_weight > 0),
    -- Optional topology risk contribution for this edge.
    rtopology_local  REAL NOT NULL DEFAULT 0.0 CHECK (rtopology_local >= 0.0),
    -- Optional hex-cell for this edge if using DGGS cells.
    hex_index        TEXT,
    UNIQUE (from_nodeid, to_nodeid)
);
CREATE INDEX IF NOT EXISTS idx_node_adjacency_from
    ON node_adjacency (from_nodeid);
CREATE INDEX IF NOT EXISTS idx_node_adjacency_to
    ON node_adjacency (to_nodeid);
