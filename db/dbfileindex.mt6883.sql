-- filename: dbfileindex.mt6883.sql
-- destination: Eco-Fort/db/dbfileindex.mt6883.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS mt6883_fileindex (
    file_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    filename       TEXT NOT NULL,
    destination    TEXT NOT NULL,
    repo_target    TEXT NOT NULL,
    role           TEXT NOT NULL,  -- SQL_SCHEMA, RUST_MODULE
    description    TEXT NOT NULL,
    created_utc    TEXT NOT NULL
);

INSERT INTO mt6883_fileindex
    (filename, destination, repo_target, role, description, created_utc)
VALUES
    (
        'dbmt6883registry.sql',
        'Eco-Fort/db/dbmt6883registry.sql',
        'Eco-Fort',
        'SQL_SCHEMA',
        'MT6883 healthcare and large-particle registry over shardinstance, with lane and continuity fields.',
        datetime('now')
    ),
    (
        'mt6883_lane_continuity.rs',
        'Virta-Sys/src/mt6883_lane_continuity.rs',
        'Virta-Sys',
        'RUST_MODULE',
        'Virta-Sys continuity module enforcing non-rollback and Lyapunov continuity for MT6883 workloads using mt6883registry and lanestatusverdict.',
        datetime('now')
    );
