-- filename db_node_adjacency.sql
-- destination Eco-Fort/db/db_node_adjacency.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS node_adjacency (
    edge_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    graph_name     TEXT NOT NULL,   -- HYDRO_PHOENIX, STREET_PHOENIX, GRID_ENERGY, HEALTH_ORGAN
    from_node      TEXT NOT NULL,
    to_node        TEXT NOT NULL,
    relation       TEXT NOT NULL,   -- UPSTREAM, DOWNSTREAM, ADJACENT, FEEDS, DRAINS, CONNECTS
    distance_m     REAL,            -- if applicable
    travel_time_h  REAL,            -- if applicable
    active         INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

CREATE INDEX IF NOT EXISTS idx_node_adj_from
    ON node_adjacency (graph_name, from_node);

CREATE INDEX IF NOT EXISTS idx_node_adj_to
    ON node_adjacency (graph_name, to_node);
