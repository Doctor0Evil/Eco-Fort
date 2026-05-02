-- filename: db/eco_constellation_index.sql
-- destination: Eco-Fort (or ecological-orchestrator)/db/eco_constellation_index.sql

PRAGMA foreign_keys = ON;

------------------------------------------------------------------------------
-- 1. Role band table
------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS repo_role_band (
    role_band   TEXT PRIMARY KEY,              -- 'SPINE','RESEARCH','ENGINE','MATERIAL','GOV','APP'
    description TEXT NOT NULL
);

INSERT OR IGNORE INTO repo_role_band (role_band, description) VALUES
    ('SPINE',   'Core ecosafety grammar, ALN schemas, qpudatashard invariants, and tooling'),
    ('RESEARCH','Non-actuating research and shard-generation workloads that feed planning'),
    ('ENGINE',  'Physical-domain kernels and controllers, fenced by ecosafety spine'),
    ('MATERIAL','Material and biology repositories for substrates, species, and corridors'),
    ('GOV',     'Governance, finance, rights, orchestration, and reward logic'),
    ('APP',     'Specialized deployments, clients, dashboards, and city-specific bridges');

------------------------------------------------------------------------------
-- 2. Canonical repo registry
------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS repo (
    repo_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name             TEXT NOT NULL UNIQUE,      -- e.g. 'EcoNet-CEIM-PhoenixWater'
    github_slug      TEXT NOT NULL,            -- e.g. 'Doctor0Evil/EcoNet-CEIM-PhoenixWater'
    visibility       TEXT NOT NULL CHECK (visibility IN ('Public','Private')),
    language_primary TEXT NOT NULL,            -- 'Rust','C++','C#','HTML','JS', etc.
    role_band        TEXT NOT NULL REFERENCES repo_role_band(role_band),
    description      TEXT,
    last_updated_utc TEXT                      -- Optional: ISO8601, can be NULL at seed time
);

CREATE INDEX IF NOT EXISTS idx_repo_role_band ON repo (role_band);
CREATE INDEX IF NOT NOT EXISTS idx_repo_visibility ON repo (visibility);

------------------------------------------------------------------------------
-- 3. Seed data: repos you listed
--    NOTE: last_updated_utc is left NULL here; you can backfill from GitHub API.
------------------------------------------------------------------------------

INSERT OR IGNORE INTO repo
    (name, github_slug, visibility, language_primary, role_band, description, last_updated_utc)
VALUES
    -- Spine / grammar / schemas / tooling (SPINE)
    ('EcoNet',
     'Doctor0Evil/EcoNet',
     'Private',
     'Rust',
     'SPINE',
     'Primary ecosafety and CEIM/CPVM host; defines RiskCoord, RiskVector, Lyapunov residual Vt, KER windows, and planning kernels.',
     NULL),

    ('aln-platform-ecosystem',
     'Doctor0Evil/aln-platform-ecosystem',
     'Public',
     'Rust',
     'SPINE',
     'Canonical ALN spec library; hosts ecosafety.riskvector.v2, ecosafety.corridors.v2, and FlowVac-style shard schemas.',
     NULL),

    ('Eco-Fort',
     'Doctor0Evil/Eco-Fort',
     'Public',
     'Rust',
     'SPINE',
     'Centralized repository of data schemas, validation rules, and reference implementations; canonical home for qpudatashards.',
     NULL),

    ('cydroid-toolkit',
     'Doctor0Evil/cydroid-toolkit',
     'Public',
     'Rust',
     'SPINE',
     'ALN-driven stack that auto-generates cross-language schemas, neuromorphic encoders, ledgers, and CLIs for eco-restorative missions.',
     NULL),

    -- Research and shard-generation band (RESEARCH)
    ('eco_restoration_shard',
     'Doctor0Evil/eco_restoration_shard',
     'Public',
     'Rust',
     'RESEARCH',
     'Continuous-ingestion eco-restoration research shard emitter that produces ALN shards and KER scores.',
     NULL),

    ('SnowGlobe',
     'Doctor0Evil/SnowGlobe',
     'Public',
     'Rust',
     'RESEARCH',
     'Global eco-sustainability research feed; produces non-actuating shards and corridor candidates.',
     NULL),

    ('EcoNet-CERG',
     'Doctor0Evil/EcoNet-CERG',
     'Public',
     'Rust',
     'RESEARCH',
     'Guaranteed-Evolution Reward logic; binds KER improvements to augmented-citizen DIDs and reward flows.',
     NULL),

    -- Engine / controller band (ENGINE)
    ('EcoNet-CEIM-PhoenixWater',
     'Doctor0Evil/EcoNet-CEIM-PhoenixWater',
     'Public',
     'Rust',
     'ENGINE',
     'CEIM/CPVM kernels and controllers for Phoenix water nodes (PFBS, E. coli, salinity, etc.).',
     NULL),

    ('Eco-Sys',
     'Doctor0Evil/Eco-Sys',
     'Public',
     'Rust',
     'ENGINE',
     'Public-infrastructure eco-systems for transit and water-lines; precision calculations for restoration-oriented components.',
     NULL),

    ('EcoNetPhoenix',
     'Doctor0Evil/EcoNetPhoenix',
     'Public',
     'C++',
     'ENGINE',
     'Phoenix-specific hydraulic and eco-device engines integrated with EcoNet corridors and KER.',
     NULL),

    ('PhoenixMicroEcoNodesCEIM',
     'Doctor0Evil/PhoenixMicroEcoNodesCEIM',
     'Public',
     'C++',
     'ENGINE',
     'Micro eco-nodes and CEIM kernels for Phoenix, handling localized sensing and scoring.',
     NULL),

    ('PhoenixCorridorEcoHUDServer',
     'Doctor0Evil/PhoenixCorridorEcoHUDServer',
     'Public',
     'C++',
     'ENGINE',
     'Heads-up display server for Phoenix corridor status and eco-kernel outputs.',
     NULL),

    ('CEIM-EcoDeviceScore',
     'Doctor0Evil/CEIM-EcoDeviceScore',
     'Public',
     'C++',
     'ENGINE',
     'CEIM-based eco-device scoring engine for hardware endpoints and smart-city devices.',
     NULL),

    ('Sewer-FOG-Monitoring-Network',
     'Doctor0Evil/Sewer-FOG-Monitoring-Network',
     'Public',
     'C++',
     'ENGINE',
     'Production-grade C++/IoT project for FOG monitoring and hydrological buffering in sewer networks.',
     NULL),

    ('EcoNetHumanoidEcoCore',
     'Doctor0Evil/EcoNetHumanoidEcoCore',
     'Public',
     'C++',
     'ENGINE',
     'Eco-governed humanoid core controllers, fenced by ecosafety limits and RiskVector corridors.',
     NULL),

    ('AirGlobeEcoKernel',
     'Doctor0Evil/AirGlobeEcoKernel',
     'Public',
     'C#',
     'ENGINE',
     'Air quality and air–water coupling kernels for atmospheric eco-restoration workloads.',
     NULL),

    -- Material / biology band (MATERIAL)
    ('BugsLife',
     'Doctor0Evil/BugsLife',
     'Public',
     'Rust',
     'MATERIAL',
     'Eco-friendly pest-control substrates and tactics that avoid hazardous chemicals and protect ecosystems.',
     NULL),

    ('Ant-One-Net',
     'Doctor0Evil/Ant-One-Net',
     'Public',
     'Unknown',
     'MATERIAL',
     'Biodegradable composites for ant-fed packaging and structures; material kinetics and toxicity shards.',
     NULL),

    ('EcoNet-BeeSafeAI',
     'Doctor0Evil/EcoNet-BeeSafeAI',
     'Public',
     'Rust',
     'MATERIAL',
     'Habitat-centered bee protection kernels that focus on non-invasive, eco-safe interventions.',
     NULL),

    -- Governance / finance / rights band (GOV)
    ('eco_infra-governance',
     'Doctor0Evil/eco_infra-governance',
     'Public',
     'Rust',
     'GOV',
     'Infrastructure-level governance, CI contracts, and virtual-machine constellation definitions.',
     NULL),

    ('ecological-orchestrator',
     'Doctor0Evil/ecological-orchestrator',
     'Public',
     'Rust',
     'GOV',
     'Workload orchestration across nodes with routing and KER-aware scheduling for eco-restorative tasks.',
     NULL),

    ('Paycomp',
     'Doctor0Evil/Paycomp',
     'Public',
     'Rust',
     'GOV',
     'Augmented-citizen financial infrastructure for smart-city payments linked to eco-impact and KER.',
     NULL),

    ('Ocu-Trust',
     'Doctor0Evil/Ocu-Trust',
     'Public',
     'Rust',
     'GOV',
     'Decentralized identity and trust orchestration for biophysical oculus systems and eco-friendly interfaces.',
     NULL),

    ('Globe',
     'Doctor0Evil/Globe',
     'Private',
     'Rust',
     'GOV',
     'City-scale eco-finance and energy-cost modeling project for smart-city infrastructure planning.',
     NULL),

    -- Specialized application band (APP)
    ('EcoNetCybocinderPhoenix',
     'Doctor0Evil/EcoNetCybocinderPhoenix',
     'Public',
     'HTML',
     'APP',
     'Web entry point and dashboards for Phoenix EcoNet deployments.',
     NULL),

    ('Eco_Build',
     'Doctor0Evil/Eco_Build',
     'Public',
     'JS',
     'APP',
     'Eco-build frontends and configuration tools for eco-restorative systems.',
     NULL),

    ('Windminer',
     'Doctor0Evil/Windminer',
     'Public',
     'C++',
     'APP',
     'Computational framework for deploying wind-driven litter interception nets in urban street canyons.',
     NULL),

    ('Swarm-x',
     'Doctor0Evil/Swarm-x',
     'Private',
     'Unknown',
     'APP',
     'Nanoswarm-technology project for eco-sustainable quantum-energy core design and energy-cost reduction.',
     NULL),

    ('Phoenix-AWP-Gila-EcoBridge',
     'Doctor0Evil/Phoenix-AWP-Gila-EcoBridge',
     'Private',
     'C++',
     'APP',
     'Bridge between Phoenix deployments and Gila watershed eco-kernels.',
     NULL),

    ('PhoenixNeurostackEcoGov',
     'Doctor0Evil/PhoenixNeurostackEcoGov',
     'Public',
     'C++',
     'APP',
     'Neurostack-based eco-governance controllers under ecosafety constraints for Phoenix.',
     NULL);

-- End of eco_constellation_index.sql
