-- filename: db_bioscale_workspace.sql
-- destination: Eco-Fort/db/db_bioscale_workspace.sql

PRAGMA foreign_keys = ON;

-- 1. Register the repo in the constellation index.
INSERT OR IGNORE INTO repo (
    name,
    githubslug,
    visibility,
    languageprimary,
    roleband,
    description,
    lastupdatedutc
)
VALUES (
    'bioscale-evolution',
    'Doctor0Evil/bioscale-evolution',
    'Public',
    'Rust',
    'ENGINE',
    'Host-sovereign bioscale evolution workspace (BCI/EEG/MCI, biomechanical, neuromorphic, organic).',
    '2026-05-03T00:00:00Z'
);

-- 2. Optional: register the master index shard for this repo
-- if you decide to ship a .econet.econetrepoindex.sql alongside it.
-- (Assumes you already inserted a row into repofile for that shard.)

-- Example knowledge-ecoscore entry marking this workspace as high-K, high-E, low-R.
INSERT INTO knowledgeecoscore (
    scopetype,
    scoperefid,
    kfactor,
    efactor,
    rfactor,
    rationale,
    timestamputc,
    issuedby
)
SELECT
    'REPO',
    repoid,
    0.95,
    0.92,
    0.12,
    'Bioscale evolution workspace: non-actuating, CI-gated, anti-rollback fairness validator for host-sovereign cybernetic upgrades.',
    '2026-05-03T00:00:00Z',
    'did:bostrom:bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7'
FROM repo
WHERE name = 'bioscale-evolution';
