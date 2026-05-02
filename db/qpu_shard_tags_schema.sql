-- filename: db/qpu_shard_tags_schema.sql
-- destination: Eco-Fort/db/qpu_shard_tags_schema.sql

CREATE TABLE IF NOT EXISTS qpu_shard_tag (
    tag_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    shard_id INTEGER NOT NULL REFERENCES qpu_shard_catalog(shard_id) ON DELETE CASCADE,
    tag_key  TEXT NOT NULL,
    tag_val  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_qpu_shard_tag_key_val
    ON qpu_shard_tag (tag_key, tag_val);
