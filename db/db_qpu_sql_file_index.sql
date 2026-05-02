-- filename db_qpu_sql_file_index.sql
-- destination Eco-Fort/db/db_qpu_sql_file_index.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS qpu_sql_file_index (
    file_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_target      TEXT NOT NULL,    -- 'Eco-Fort','Virta-Sys','EcoNet'
    destination_path TEXT NOT NULL,    -- e.g. 'db/db_qpu_shard_catalog.sql'
    filename         TEXT NOT NULL,    -- e.g. 'db_qpu_shard_catalog.sql'
    description      TEXT,             -- what the file is used for
    active           INTEGER NOT NULL DEFAULT 1
                          CHECK (active IN (0,1)),

    UNIQUE (repo_target, destination_path, filename)
);

CREATE INDEX IF NOT EXISTS idx_qpu_sql_repo
    ON qpu_sql_file_index (repo_target);
