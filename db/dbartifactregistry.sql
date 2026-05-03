-- filename dbartifactregistry.sql
-- destination Eco-Fort/db/dbartifactregistry.sql

PRAGMA foreign_keys = ON;

-- 1. Canonical artifact registry
-- One row per registered machine-code or shard artifact.

CREATE TABLE IF NOT EXISTS artifactregistry (
  artifactid        INTEGER PRIMARY KEY AUTOINCREMENT,

  -- Identity and wiring into the constellation spine
  repoid            INTEGER NOT NULL,
  repofileid        INTEGER NOT NULL,
  shardid           INTEGER,              -- optional FK into shardinstance
  catalogid         INTEGER,              -- optional FK into qpushardcatalog
  mt6883registryid  INTEGER,              -- optional FK into mt6883registry

  -- File identity and content
  repotarget        TEXT NOT NULL,        -- repo.name mirror for convenience
  destinationpath   TEXT NOT NULL,        -- directory path inside repo
  filename          TEXT NOT NULL,
  fileext           TEXT NOT NULL,        -- rs, so, aln, csv, db, etc.
  artifactkind      TEXT NOT NULL,        -- BINARY,KERNEL,ROUTINE,QPUDATASHARD,GOVLOG,HEALTHCARE_PLAN,INDEX_DB
  contenthash       TEXT NOT NULL,        -- canonical hex hash of artifact bytes
  sizebytes         INTEGER,              -- optional size hint

  -- Ecosafety lanes and planes
  primaryplane      TEXT NOT NULL,        -- energy,hydraulics,health,dataquality,topology,finance,...
  secondaryplanes   TEXT,                 -- comma-separated planes
  lane              TEXT NOT NULL,        -- RESEARCH,EXPPROD,PROD
  kerband           TEXT NOT NULL,        -- SAFE,GUARDED,BLOCKED
  planecontractid   INTEGER,              -- FK into planeweightscontract
  blastradiusid     INTEGER,              -- FK into blastradiusobject

  -- Cached KER snapshot at registration time (from shardinstance if present)
  kmetric           REAL,
  emetric           REAL,
  rmetric           REAL,
  vtmax             REAL,
  kerdeployable     INTEGER,              -- 0/1 mirror of shardinstance.kerdeployable

  -- Governance and evidence
  evidencehex       TEXT NOT NULL,        -- hex descriptor of evidence bundle
  rohanchorhex      TEXT,                 -- RoH contract / rule-of-history anchor
  signingdid        TEXT NOT NULL,        -- DID responsible for this artifact
  provenancehex     TEXT,                 -- hex link into ArtifactRegistryShard2026v1 chain

  -- Lifecycle (non-rollback semantics: no destructive delete, only deactivate)
  createdutc        TEXT NOT NULL,        -- ISO-8601 creation time
  updatedutc        TEXT NOT NULL,        -- ISO-8601 last metadata update
  active            INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),

  -- Foreign keys into existing spine tables
  FOREIGN KEY (repoid)           REFERENCES repo(repoid) ON DELETE CASCADE,
  FOREIGN KEY (repofileid)       REFERENCES repofile(fileid) ON DELETE CASCADE,
  FOREIGN KEY (shardid)          REFERENCES shardinstance(shardid) ON DELETE SET NULL,
  FOREIGN KEY (catalogid)        REFERENCES qpushardcatalog(shardid) ON DELETE SET NULL,
  FOREIGN KEY (mt6883registryid) REFERENCES mt6883registry(registryid) ON DELETE SET NULL,
  FOREIGN KEY (planecontractid)  REFERENCES planeweightscontract(contractid) ON DELETE SET NULL,
  FOREIGN KEY (blastradiusid)    REFERENCES blastradiusobject(broid) ON DELETE SET NULL,

  UNIQUE (repotarget, destinationpath, filename, artifactkind),
  UNIQUE (repofileid, artifactkind)
);

CREATE INDEX IF NOT EXISTS idx_artifact_repo_kind
  ON artifactregistry (repoid, artifactkind, lane);

CREATE INDEX IF NOT EXISTS idx_artifact_plane_lane
  ON artifactregistry (primaryplane, lane, kerband);

CREATE INDEX IF NOT EXISTS idx_artifact_hash
  ON artifactregistry (contenthash);

CREATE INDEX IF NOT EXISTS idx_artifact_blastradius
  ON artifactregistry (blastradiusid);

CREATE INDEX IF NOT EXISTS idx_artifact_active
  ON artifactregistry (active);

-- 2. Provenance registry
-- One row per artifact provenance event (CI run, build, promotion).

CREATE TABLE IF NOT EXISTS artifactprovenance (
  provenanceid      INTEGER PRIMARY KEY AUTOINCREMENT,

  artifactid        INTEGER NOT NULL
                     REFERENCES artifactregistry(artifactid) ON DELETE CASCADE,

  cirunid           TEXT NOT NULL,     -- e.g. GitHub run ID
  workflowfile      TEXT NOT NULL,     -- .github/workflows/...
  repo              TEXT NOT NULL,     -- GitHub repo slug
  energymode        TEXT NOT NULL,     -- LOWPOWER,BALANCED,HIGHTHROUGHPUT
  status            TEXT NOT NULL,     -- COMPLETED,FAILED,CANCELLED
  sharddbpath       TEXT,              -- path to DB this run updated
  shardcount        INTEGER,           -- e.g. number of shards touched

  -- Snapshot of ecosafety context at build/promotion time
  lane              TEXT NOT NULL,     -- lane in effect during this run
  kmetric           REAL,
  emetric           REAL,
  rmetric           REAL,
  vtmax             REAL,
  kerdeployable     INTEGER,           -- 0/1 at run time
  rtopology         REAL,              -- optional topology risk contribution
  wtopology         REAL,              -- weight used in residual

  planecontractid   INTEGER REFERENCES planeweightscontract(contractid)
                    ON DELETE SET NULL,

  evidencehex       TEXT NOT NULL,     -- hex descriptor for this run's evidence bundle
  rohanchorhex      TEXT,              -- RoH contract / rule-of-history anchor
  signingdid        TEXT NOT NULL,     -- CI or human DID that issued this run

  timestamputc      TEXT NOT NULL,     -- ISO-8601 run completion time

  UNIQUE (artifactid, cirunid)
);

CREATE INDEX IF NOT EXISTS idx_provenance_artifact_time
  ON artifactprovenance (artifactid, timestamputc);

CREATE INDEX IF NOT EXISTS idx_provenance_lane_status
  ON artifactprovenance (lane, status);

CREATE INDEX IF NOT EXISTS idx_provenance_energy
  ON artifactprovenance (energymode, status);
