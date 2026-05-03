-- filename: dbartifactregistry.sql
-- destination: Eco-Fort/db/dbartifactregistry.sql

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 1. Canonical artifact registry
-- One row per registered machine-code or shard artifact.
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS artifactregistry (
    artifactid        INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Identity and wiring into the constellation spine
    repoid            INTEGER NOT NULL
                         REFERENCES repo(repoid)
                         ON DELETE CASCADE,
    repofileid        INTEGER NOT NULL
                         REFERENCES repofile(fileid)
                         ON DELETE CASCADE,
    shardid           INTEGER
                         REFERENCES shardinstance(shardid)
                         ON DELETE SET NULL,
    catalogid         INTEGER
                         REFERENCES qpushardcatalog(shardid)
                         ON DELETE SET NULL,
    mt6883registryid  INTEGER
                         REFERENCES mt6883registry(registryid)
                         ON DELETE SET NULL,

    -- Semantic file metadata
    repotarget        TEXT    NOT NULL, -- mirror of repo.name
    destinationpath   TEXT    NOT NULL, -- directory path inside repo
    filename          TEXT    NOT NULL,
    fileext           TEXT    NOT NULL, -- rs, so, aln, csv, db, etc.
    artifactkind      TEXT    NOT NULL, -- BINARY,KERNEL,ROUTINE,QPUDATASHARD,GOVLOG,HEALTHCARE_PLAN,INDEX_DB

    -- Immutable content identity
    contenthash       TEXT    NOT NULL, -- generic hex hash, algorithm defined in policy
    sizebytes         INTEGER,

    -- Ecosafety lanes and planes
    primaryplane      TEXT    NOT NULL, -- energy,hydraulics,healthcare,dataquality,topology,finance,...
    secondaryplanes   TEXT,             -- comma-separated planes
    lane              TEXT    NOT NULL CHECK (
                           lane IN ('RESEARCH','EXPPROD','PROD')
                       ),
    kerband           TEXT    NOT NULL CHECK (
                           kerband IN ('SAFE','GUARDED','BLOCKED')
                       ),

    planecontractid   INTEGER
                         REFERENCES planeweightscontract(contractid)
                         ON DELETE SET NULL,
    blastradiusid     INTEGER
                         REFERENCES blastradiusindex(blasthradius_id)
                         ON DELETE SET NULL,

    -- Cached KER / residual metrics at registration time
    kmetric           REAL,
    emetric           REAL,
    rmetric           REAL,
    vtmax             REAL,

    kerdeployable     INTEGER NOT NULL DEFAULT 0 CHECK (
                           kerdeployable IN (0,1)
                       ),

    -- Evidence and RoH anchoring
    evidencehex       TEXT    NOT NULL, -- descriptor of evidence bundle
    rohanchorhex      TEXT,             -- Rule-of-History anchor

    -- Signing / DID
    signingdid        TEXT    NOT NULL,

    -- Provenance link (into artifactprovenance chain)
    provenancehex     TEXT,

    -- Timestamps
    createdutc        TEXT    NOT NULL, -- ISO-8601
    updatedutc        TEXT    NOT NULL, -- ISO-8601

    -- Lifecycle flag; rows are never hard-deleted
    active            INTEGER NOT NULL DEFAULT 1 CHECK (
                           active IN (0,1)
                       ),

    -- Basic uniqueness: same repo + path + filename + hash cannot be duplicated
    UNIQUE (repoid, destinationpath, filename, contenthash)
);

CREATE INDEX IF NOT EXISTS idx_artifact_repo_file
    ON artifactregistry (repoid, repofileid);

CREATE INDEX IF NOT EXISTS idx_artifact_repo_kind
    ON artifactregistry (repoid, artifactkind, lane);

CREATE INDEX IF NOT EXISTS idx_artifact_lane_plane
    ON artifactregistry (lane, primaryplane, kerband);

CREATE INDEX IF NOT EXISTS idx_artifact_ker
    ON artifactregistry (kerdeployable, kerband, kmetric, emetric, rmetric);

CREATE INDEX IF NOT EXISTS idx_artifact_hash
    ON artifactregistry (contenthash);

CREATE INDEX IF NOT EXISTS idx_artifact_shard
    ON artifactregistry (shardid);

CREATE INDEX IF NOT EXISTS idx_artifact_mt6883
    ON artifactregistry (mt6883registryid);

CREATE INDEX IF NOT EXISTS idx_artifact_blastradius
    ON artifactregistry (blastradiusid);

CREATE INDEX IF NOT EXISTS idx_artifact_active
    ON artifactregistry (active);

----------------------------------------------------------------------
-- 2. Provenance registry
-- One row per artifact provenance event (CI run, build, promotion).
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS artifactprovenance (
    provenanceid      INTEGER PRIMARY KEY AUTOINCREMENT,

    artifactid        INTEGER NOT NULL
                         REFERENCES artifactregistry(artifactid)
                         ON DELETE CASCADE,

    cirunid           TEXT NOT NULL,     -- e.g. GitHub run ID
    workflowfile      TEXT NOT NULL,     -- .github/workflows/...
    repo              TEXT NOT NULL,     -- GitHub repo slug
    energymode        TEXT NOT NULL,     -- LOWPOWER,BALANCED,HIGHTHROUGHPUT
    status            TEXT NOT NULL,     -- COMPLETED,FAILED,CANCELLED
    sharddbpath       TEXT,              -- path to DB this run updated
    shardcount        INTEGER,           -- number of shards touched

    -- Snapshot of ecosafety context at build/promotion time
    lane              TEXT NOT NULL CHECK (
                           lane IN ('RESEARCH','EXPPROD','PROD')
                       ),
    kmetric           REAL,
    emetric           REAL,
    rmetric           REAL,
    vtmax             REAL,
    kerdeployable     INTEGER CHECK (
                           kerdeployable IN (0,1)
                       ),
    rtopology         REAL,
    wtopology         REAL,

    planecontractid   INTEGER
                         REFERENCES planeweightscontract(contractid)
                         ON DELETE SET NULL,

    evidencehex       TEXT NOT NULL,
    rohanchorhex      TEXT,
    signingdid        TEXT NOT NULL,

    timestamputc      TEXT NOT NULL,     -- ISO-8601 run completion time

    UNIQUE (artifactid, cirunid)
);

CREATE INDEX IF NOT EXISTS idx_provenance_artifact_time
    ON artifactprovenance (artifactid, timestamputc);

CREATE INDEX IF NOT EXISTS idx_provenance_lane_status
    ON artifactprovenance (lane, status);

CREATE INDEX IF NOT EXISTS idx_provenance_energy
    ON artifactprovenance (energymode, status);
