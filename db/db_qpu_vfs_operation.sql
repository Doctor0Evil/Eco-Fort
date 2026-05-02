-- filename db_qpu_vfs_operation.sql
-- destination Eco-Fort/db/db_qpu_vfs_operation.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS qpu_vfs_operation (
    vfs_op_code            TEXT PRIMARY KEY,   -- 'VOP_ROUTE_ENERGY', 'VOP_SNAPSHOT_STATE', etc.
    vfs_namespace          TEXT NOT NULL,      -- 'qpu://','qpu://phoenix','qpu://hydro'
    description            TEXT NOT NULL,      -- human-readable description
    op_kind                TEXT NOT NULL,      -- 'READ','WRITE','TRANSFORM','ROUTE','SNAPSHOT'
    non_actuating_required INTEGER NOT NULL DEFAULT 1
                               CHECK (non_actuating_required IN (0,1)),
    idempotent             INTEGER NOT NULL DEFAULT 0
                               CHECK (idempotent IN (0,1)),
    min_continuity_secs    INTEGER,           -- recommended minimum continuity window
    required_hw_family     TEXT,              -- e.g. 'MT6883','EDGE_NODE'
    notes                  TEXT
);

CREATE INDEX IF NOT EXISTS idx_qpu_vfs_namespace_kind
    ON qpu_vfs_operation (vfs_namespace, op_kind);
