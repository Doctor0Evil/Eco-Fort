-- filename: dbecosafety_math_spine_band1.sql
-- destination: Eco-Fort/db/dbecosafety_math_spine_band1.sql

PRAGMA foreign_keys = ON;

-------------------------------------------------------------------------------
-- 0. Assumed existing core tables (referenced, not redefined here)
--
--   plane            (planeid INTEGER PRIMARY KEY, name TEXT UNIQUE, ...)
--   riskcoordinate   (coordid INTEGER PRIMARY KEY, name TEXT UNIQUE, planeid INTEGER REFERENCES plane(planeid), ...)
--   shardinstance    (shardid INTEGER PRIMARY KEY, planecontractid INTEGER, vtmax REAL, kmetric REAL, emetric REAL, rmetric REAL, ...)
--
-- This file only adds new tables and views needed for the Band‑1 ecosafety math spine.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 1. Plane weights contracts and per‑plane weights
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS planeweightscontract (
    contractid        INTEGER PRIMARY KEY AUTOINCREMENT,
    contract_name     TEXT    NOT NULL UNIQUE,
    description       TEXT    NOT NULL,
    issuedutc         TEXT    NOT NULL,      -- ISO‑8601
    active            INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

CREATE TABLE IF NOT EXISTS planeweightsplane (
    contractid        INTEGER NOT NULL REFERENCES planeweightscontract(contractid) ON DELETE CASCADE,
    planeid           INTEGER NOT NULL REFERENCES plane(planeid) ON DELETE CASCADE,
    weight            REAL    NOT NULL,      -- w_j >= 0
    nonoffsettable    INTEGER NOT NULL DEFAULT 0 CHECK (nonoffsettable IN (0,1)),
    PRIMARY KEY (contractid, planeid)
);

CREATE INDEX IF NOT EXISTS idx_planeweightsplane_plane
    ON planeweightsplane (planeid);

-------------------------------------------------------------------------------
-- 2. Residual kernel and terms (which coordinates enter V_t, with what α)
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS residualkernel (
    kernelid          INTEGER PRIMARY KEY AUTOINCREMENT,
    contractid        INTEGER NOT NULL REFERENCES planeweightscontract(contractid) ON DELETE CASCADE,
    kernel_name       TEXT    NOT NULL,
    description       TEXT    NOT NULL,
    active            INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    UNIQUE (contractid, kernel_name)
);

CREATE TABLE IF NOT EXISTS residualterm (
    kernelid          INTEGER NOT NULL REFERENCES residualkernel(kernelid) ON DELETE CASCADE,
    coordid           INTEGER NOT NULL REFERENCES riskcoordinate(coordid) ON DELETE CASCADE,
    alpha             REAL    NOT NULL,      -- coefficient for this coordinate in the residual
    PRIMARY KEY (kernelid, coordid)
);

CREATE INDEX IF NOT EXISTS idx_residualterm_coord
    ON residualterm (coordid);

-------------------------------------------------------------------------------
-- 3. Safestep configuration (ε, windowing) per contract
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS safestepconfig (
    contractid        INTEGER NOT NULL PRIMARY KEY REFERENCES planeweightscontract(contractid) ON DELETE CASCADE,
    epsilon_v         REAL    NOT NULL,      -- tolerance for V_{t+1} <= V_t + ε
    window_kind       TEXT    NOT NULL,      -- e.g. 'FIXED', 'CALENDAR'
    window_length     INTEGER NOT NULL,      -- unit interpreted by policy (e.g. minutes, samples)
    description       TEXT    NOT NULL
);

-------------------------------------------------------------------------------
-- 4. Definition registry (maps DR identifiers to ALN/SQL/Rust artifacts)
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS definitionregistry (
    dr_id             TEXT    NOT NULL PRIMARY KEY,  -- e.g. 'DR-LYAPUNOV-RESIDUAL'
    kind              TEXT    NOT NULL,              -- 'PLANE','COORDINATE','FUNCTIONAL','POLICY',...
    short_spec        TEXT    NOT NULL,              -- one-paragraph human-readable spec
    aln_path          TEXT    NOT NULL,              -- repo-relative path to .aln
    sql_path          TEXT    NOT NULL,              -- repo-relative path to .sql
    rust_path         TEXT,                          -- optional primary Rust module path
    contract_name     TEXT    NOT NULL,              -- e.g. 'EcosafetyPlaneWeights2026v1'
    issuedutc         TEXT    NOT NULL,
    active            INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

-------------------------------------------------------------------------------
-- 5. Risk vector view: flatten shardinstance + riskcoordinate into rows
--
-- Assumptions:
--   - There exists a table shardriskvalue(shardid, coordid, r_value) or
--     an equivalent structure that stores normalized risk coordinates r_{t,j}.
--   - Each coordid belongs to exactly one planeid via riskcoordinate.
--
-- If your actual storage layout is different, adjust the FROM/JOIN clauses
-- while preserving the output columns (shardid, coordid, planeid, r_value).
-------------------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS v_shard_riskvector AS
SELECT
    rv.shardid      AS shardid,
    rv.coordid      AS coordid,
    rc.planeid      AS planeid,
    CAST(ROUND(rv.r_value, 6) AS REAL) AS r_value
FROM shardriskvalue AS rv
JOIN riskcoordinate AS rc
  ON rc.coordid = rv.coordid;

-------------------------------------------------------------------------------
-- 6. Residual and K/E/R view per shard and plane weights contract
--
-- This view computes:
--   vt     = Σ_j w_plane(j) * α_j * r_j^2
--   rmax   = max_j r_j
--   evalue = 1 - rmax
--
-- Inputs:
--   - shardinstance.shardid, shardinstance.planecontractid
--   - v_shard_riskvector
--   - residualterm (α_j per coordid for a given kernel)
--   - residualkernel (to select active kernel per contract)
--   - planeweightsplane (w_plane per plane per contract)
-------------------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS v_shard_residual AS
WITH active_kernel AS (
    SELECT
        rk.contractid,
        rk.kernelid
    FROM residualkernel AS rk
    WHERE rk.active = 1
)
SELECT
    s.shardid,
    s.planecontractid                     AS contractid,
    SUM(pw.weight * rt.alpha * rv.r_value * rv.r_value) AS vt,
    MAX(rv.r_value)                       AS rmax,
    (1.0 - MAX(rv.r_value))              AS evalue
FROM shardinstance AS s
JOIN active_kernel AS ak
  ON ak.contractid = s.planecontractid
JOIN residualterm AS rt
  ON rt.kernelid = ak.kernelid
JOIN v_shard_riskvector AS rv
  ON rv.shardid = s.shardid
 AND rv.coordid = rt.coordid
JOIN planeweightsplane AS pw
  ON pw.contractid = s.planecontractid
 AND pw.planeid    = rv.planeid
GROUP BY
    s.shardid,
    s.planecontractid;

-------------------------------------------------------------------------------
-- 7. Seed rows for Band‑1 contracts and definitions (non-authoritative, safe defaults)
--
-- These can be updated or extended via migrations in Eco-Fort as your
-- production contracts are finalized.
-------------------------------------------------------------------------------

INSERT OR IGNORE INTO planeweightscontract (contract_name, description, issuedutc, active)
VALUES
  ('EcosafetyPlaneWeights2026v1',
   'Baseline ecosafety plane weights contract for 2026 Lyapunov residual and KER.',
   '2026-01-01T00:00:00Z',
   1);

-- Example SafestepConfig seed: ε = 1e-6, fixed window of 60 samples.
INSERT OR IGNORE INTO safestepconfig (contractid, epsilon_v, window_kind, window_length, description)
SELECT
  contractid,
  1e-6,
  'FIXED',
  60,
  'Default safestep configuration: epsilon_v=1e-6 over fixed 60-sample windows.'
FROM planeweightscontract
WHERE contract_name = 'EcosafetyPlaneWeights2026v1';

-- Definition registry seeds for core Band‑1 concepts.
INSERT OR IGNORE INTO definitionregistry
  (dr_id, kind, short_spec, aln_path, sql_path, rust_path, contract_name, issuedutc, active)
VALUES
  (
    'DR-LYAPUNOV-RESIDUAL',
    'FUNCTIONAL',
    'Defines the Lyapunov residual V_t = Σ w_j r_{t,j}^2 over normalized risk coordinates and plane weights, with K/E/R derived from residual and max-plane risk.',
    'aln/ecosafety.riskvector.v2.aln',
    'db/dbecosafety_math_spine_band1.sql',
    'src/ker_residual.rs',
    'EcosafetyPlaneWeights2026v1',
    '2026-01-01T00:00:00Z',
    1
  ),
  (
    'DR-PLANE-WEIGHTS-CONTRACT',
    'POLICY',
    'Specifies per-plane weights and non-offsettable flags for a given ecosafety contract.',
    'aln/EcosafetyPlaneWeightsShard2026v1.aln',
    'db/dbecosafety_math_spine_band1.sql',
    NULL,
    'EcosafetyPlaneWeights2026v1',
    '2026-01-01T00:00:00Z',
    1
  ),
  (
    'DR-SAFESTEP-CONFIG',
    'POLICY',
    'Defines safestep tolerance epsilon_v and residual windowing parameters for a plane weights contract.',
    'aln/EcosafetySafestepConfig2026v1.aln',
    'db/dbecosafety_math_spine_band1.sql',
    NULL,
    'EcosafetyPlaneWeights2026v1',
    '2026-01-01T00:00:00Z',
    1
  ),
  (
    'DR-RESIDUAL-KERNEL',
    'FUNCTIONAL',
    'Enumerates risk coordinates and coefficients used in the residual for a plane weights contract.',
    'aln/EcosafetyResidualKernel2026v1.aln',
    'db/dbecosafety_math_spine_band1.sql',
    NULL,
    'EcosafetyPlaneWeights2026v1',
    '2026-01-01T00:00:00Z',
    1
  );
