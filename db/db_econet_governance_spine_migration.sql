-- filename: db_econet_governance_spine_migration.sql
-- destination: Eco-Fort/db/db_econet_governance_spine_migration.sql
PRAGMA foreign_keys = ON;

-----------------------------------------------------------------------
-- 1. Plane weights and non-offsettable flags (Eco-Fort, constellation DB)
-----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS planeweights (
    plane_id        TEXT PRIMARY KEY,              -- e.g. ENERGY, HYDRAULICS, CARBON, BIODIVERSITY
    description     TEXT NOT NULL,
    weight          REAL NOT NULL,                 -- w_j in V_t = sum_j w_j r_{t,j}^2
    non_offsettable INTEGER NOT NULL CHECK (non_offsettable IN (0,1)),  -- 1 => cannot trade off
    hard_min        REAL NOT NULL,                 -- corridor "safe" lower bound
    gold_min        REAL NOT NULL,                 -- corridor "gold" lower bound
    hard_max        REAL NOT NULL,                 -- corridor "hard" upper bound
    channel         TEXT NOT NULL,                 -- Lyapunov / risk channel mapping
    created_utc     TEXT NOT NULL,
    updated_utc     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_planeweights_channel
    ON planeweights (channel);

-----------------------------------------------------------------------
-- 2. Blast radius registry (Eco-Fort, constellation DB)
--    Per-kernel / shard blast radius metadata, non-actuating but
--    governs how far effects may propagate in planning.
-----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS blastradius (
    blastradius_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    reponame        TEXT NOT NULL,                 -- EcoNet-CEIM-PhoenixWater, etc.
    layername       TEXT NOT NULL,                 -- kernel / layer logical name
    kernelid        INTEGER,                       -- optional link to kernelidentity.kernelid
    region          TEXT,                          -- Phoenix-AZ, Global, etc.
    radius_class    TEXT NOT NULL,                 -- LOCAL, REGIONAL, BASIN, GLOBAL
    radius_km       REAL,                          -- approximate physical radius, if known
    time_horizon_h  REAL,                          -- hours; temporal extent of influence
    non_actuating   INTEGER NOT NULL CHECK (non_actuating IN (0,1)),  -- should match trait
    notes           TEXT,
    created_utc     TEXT NOT NULL,
    updated_utc     TEXT NOT NULL,
    UNIQUE (reponame, layername, region)
);

CREATE INDEX IF NOT EXISTS idx_blastradius_repo_layer_region
    ON blastradius (reponame, layername, region);

-----------------------------------------------------------------------
-- 3. Lane status shard mirror (Eco-Fort, constellation DB)
--    Already sketched as lanestatusshard; this just ensures the master
--    migration carries the final form.
-----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS lanestatusshard (
    shardid             INTEGER PRIMARY KEY AUTOINCREMENT,
    reponame            TEXT NOT NULL,
    layername           TEXT NOT NULL,
    kernelid            INTEGER NOT NULL,
    region              TEXT NOT NULL,             -- Phoenix-AZ, etc.
    lane                TEXT NOT NULL CHECK (lane IN ('RESEARCH','EXPPROD','PROD')),
    lanesource          TEXT NOT NULL,             -- e.g. Virta-Sys/lane-governor
    lanereason          TEXT NOT NULL,
    windowstartutc      TEXT NOT NULL,
    windowendutc        TEXT NOT NULL,
    evidencecount       INTEGER NOT NULL,
    kavg                REAL NOT NULL,
    eavg                REAL NOT NULL,
    ravg                REAL NOT NULL,
    vttrend             REAL NOT NULL,
    kminrequired        REAL NOT NULL,
    eminrequired        REAL NOT NULL,
    rmaxallowed         REAL NOT NULL,
    corridorok          INTEGER NOT NULL CHECK (corridorok IN (0,1)),
    planesok            INTEGER NOT NULL CHECK (planesok IN (0,1)),
    topologyok          INTEGER NOT NULL CHECK (topologyok IN (0,1)),
    evidencehex         TEXT NOT NULL,
    signingdid          TEXT NOT NULL,
    createdutc          TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lanestatus_kernel_region
    ON lanestatusshard (kernelid, region, lane);

CREATE INDEX IF NOT EXISTS idx_lanestatus_repo_layer
    ON lanestatusshard (reponame, layername, region);

-----------------------------------------------------------------------
-- 4. Lane decision core tables (Virta-Sys governance DB shard)
--    These are mirrored here so Eco-Fort can initialize them when
--    building Virta-Sys DB instances.
-----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS kernelidentity (
    kernelid    INTEGER PRIMARY KEY AUTOINCREMENT,
    reponame    TEXT NOT NULL,
    layername   TEXT NOT NULL,
    UNIQUE (reponame, layername)
);

CREATE TABLE IF NOT EXISTS lanedecision (
    decisionid      INTEGER PRIMARY KEY AUTOINCREMENT,
    kernelid        INTEGER NOT NULL REFERENCES kernelidentity(kernelid) ON DELETE CASCADE,
    region          TEXT,                           -- NULL => global
    lane            TEXT NOT NULL CHECK (lane IN ('RESEARCH','EXPPROD','PROD')),
    kavg            REAL NOT NULL,
    eavg            REAL NOT NULL,
    ravg            REAL NOT NULL,
    vttrend         REAL NOT NULL,
    windowstartutc  TEXT NOT NULL,
    windowendutc    TEXT NOT NULL,
    evidencecount   INTEGER NOT NULL,
    issuedby        TEXT NOT NULL,
    issuedutc       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lanedecision_kernel_region
    ON lanedecision (kernelid, region, lane);

-----------------------------------------------------------------------
-- 5. Topology misalignment audit (Virta-Sys + Eco-Fort)
--    Stores Itopology and rtopology for audits; TOPOLOGY plane in
--    corridordefinition refers to this.
-----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS topologyaudit (
    auditid         INTEGER PRIMARY KEY AUTOINCREMENT,
    scope           TEXT NOT NULL CHECK (scope IN ('CONSTELLATION','ORG','BAND','REPO')),
    scope_id        TEXT NOT NULL,                  -- org id, band name, or reponame
    windowstartutc  TEXT NOT NULL,
    windowendutc    TEXT NOT NULL,
    n_missing       INTEGER NOT NULL,
    n_mislabel      INTEGER NOT NULL,
    itopology       REAL NOT NULL,                  -- raw index
    rtopology       REAL NOT NULL,                  -- normalized 0..1
    notes           TEXT,
    created_utc     TEXT NOT NULL,
    UNIQUE (scope, scope_id, windowstartutc, windowendutc)
);

CREATE INDEX IF NOT EXISTS idx_topologyaudit_scope
    ON topologyaudit (scope, scope_id, windowendutc);

-----------------------------------------------------------------------
-- 6. MT6883 registry (Eco-Fort, hardware abstraction DB)
--    Provides a unified registry for Cortex-A77/MT6883 virtual and
--    physical nodes for Virta-Sys placement and healthcare work.
-----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS mt6883_registry (
    mtid            INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id         TEXT NOT NULL,                  -- logical node identifier
    hardwarefamily  TEXT NOT NULL,                  -- e.g. 'MT6883'
    modelcode       TEXT NOT NULL,                  -- e.g. 'mt6883-handset-2026'
    roleclass       TEXT NOT NULL,                  -- HEALTHCARE, SMARTCITY, SIMULATION, GOV
    region          TEXT NOT NULL,                  -- Phoenix-AZ, etc.
    vcorecount      INTEGER NOT NULL,               -- virtual cores exposed to workloads
    bigcorecount    INTEGER NOT NULL,
    littlecorecount INTEGER NOT NULL,
    max_freq_ghz    REAL NOT NULL,
    mem_mib         INTEGER NOT NULL,
    continuitygrade TEXT NOT NULL,                  -- A,B,C etc.
    notes           TEXT,
    created_utc     TEXT NOT NULL,
    updated_utc     TEXT NOT NULL,
    UNIQUE (node_id)
);

CREATE INDEX IF NOT EXISTS idx_mt6883_region_role
    ON mt6883_registry (region, roleclass);

-----------------------------------------------------------------------
-- 7. SQL file index entry for this migration (Eco-Fort)
-----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS qpusqlfileindex (
    fileid         INTEGER PRIMARY KEY AUTOINCREMENT,
    repotarget     TEXT NOT NULL,
    destinationpath TEXT NOT NULL,
    filename       TEXT NOT NULL,
    description    TEXT,
    active         INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    UNIQUE (repotarget, destinationpath, filename)
);

INSERT OR IGNORE INTO qpusqlfileindex (repotarget, destinationpath, filename, description)
VALUES (
    'Eco-Fort',
    'db/db_econet_governance_spine_migration.sql',
    'db_econet_governance_spine_migration.sql',
    'Master migration for EcoNet governance spine: planeweights, blastradius, lane status, topology audit, MT6883 registry.'
);
