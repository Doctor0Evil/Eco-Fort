-- filename: dbartifactprovenance.sql
-- destination: Eco-Fort/db/dbartifactprovenance.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS artifactprovenance (
    provenanceid      INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Link to artifactregistry
    artifactid        INTEGER NOT NULL
                         REFERENCES artifactregistry(artifactid)
                         ON DELETE CASCADE,

    -- CI / workflow context
    cirunid           TEXT    NOT NULL,
    workflowfile      TEXT    NOT NULL, -- e.g. .github/workflows/build.yml
    repo_slug         TEXT    NOT NULL, -- GitHub org/repo
    energymode        TEXT    NOT NULL, -- LOWPOWER,BALANCED,HIGHTHROUGHPUT,...

    -- Snapshot of ecosafety / KER at build time
    lane              TEXT    NOT NULL CHECK (
                           lane IN ('RESEARCH','EXPPROD','PROD')
                       ),
    kmetric           REAL    NOT NULL,
    emetric           REAL    NOT NULL,
    rmetric           REAL    NOT NULL,
    vtmax             REAL    NOT NULL,
    kerdeployable     INTEGER NOT NULL CHECK (
                           kerdeployable IN (0,1)
                       ),

    -- Status of the CI run
    status            TEXT    NOT NULL CHECK (
                           status IN ('COMPLETED','FAILED','CANCELLED')
                       ),

    -- Optional RoH / contract anchors
    planecontractid   INTEGER
                         REFERENCES planeweightscontract(contractid)
                         ON DELETE SET NULL,
    rohanchorhex      TEXT,

    -- Governance / lane decision linkage
    lanestatusid      INTEGER
                         REFERENCES lanestatusverdict(verdictid)
                         ON DELETE SET NULL,

    -- Timestamps
    createdutc        TEXT    NOT NULL, -- CI run start or artifact commit time
    updatedutc        TEXT    NOT NULL   -- last update for status, not content

    -- No UPDATE/DELETE invariants are enforced at policy level:
    -- CI is responsible for treating rows as append-only receipting.
);

CREATE INDEX IF NOT EXISTS idx_prov_artifact
    ON artifactprovenance (artifactid);

CREATE INDEX IF NOT EXISTS idx_prov_cirun
    ON artifactprovenance (cirunid);

CREATE INDEX IF NOT EXISTS idx_prov_lane_status
    ON artifactprovenance (lane, status);

CREATE INDEX IF NOT EXISTS idx_prov_ker
    ON artifactprovenance (kerdeployable, kmetric, emetric, rmetric, vtmax);
