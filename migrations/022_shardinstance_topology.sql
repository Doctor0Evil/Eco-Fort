-- filename: migrations/022_shardinstance_topology.sql

ALTER TABLE shardinstance
    ADD COLUMN rtopology REAL
        CHECK (rtopology IS NULL OR (rtopology >= 0.0 AND rtopology <= 1.0));

ALTER TABLE shardinstance
    ADD COLUMN wtopology REAL
        CHECK (wtopology IS NULL OR wtopology >= 0.0);
