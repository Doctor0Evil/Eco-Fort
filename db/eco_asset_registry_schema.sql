-- filename: db/eco_asset_registry_schema.sql
-- destination: Eco-Fort/db/eco_asset_registry_schema.sql
-- purpose: Central registry for all eco-restoration assets, substrates, and deployment targets
-- owner: Eco-Fort (SPINE band)
-- ker_impact: K↑ E↑ R↓ (improves discovery, reduces duplication, enforces governance)

PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- Eco Asset Registry: Canonical catalog of restoration assets and targets
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS eco_asset_registry (
    asset_id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Identity and classification
    asset_name TEXT NOT NULL UNIQUE,
    asset_type TEXT NOT NULL CHECK(asset_type IN (
        'SUBSTRATE', 'KERNEL', 'SENSOR', 'ACTUATOR', 'WORKFLOW', 
        'MATERIAL', 'SPECIES_CORRIDOR', 'DATA_PIPELINE', 'GOVERNANCE_RULE'
    )),
    asset_version TEXT NOT NULL,
    description TEXT,
    
    -- Eco-restoration domain mapping
    primary_plane TEXT NOT NULL CHECK(primary_plane IN (
        'energy', 'hydraulics', 'biology', 'carbon', 'materials', 
        'biodiversity', 'dataquality', 'topology'
    )),
    secondary_planes TEXT, -- comma-separated list of additional planes
    region_scope TEXT NOT NULL CHECK(region_scope IN ('Global', 'Continental', 'Basin', 'Local', 'Site')),
    target_regions TEXT, -- comma-separated list of specific regions
    
    -- Technical specifications
    input_schema_ref TEXT, -- ALN schema for inputs (e.g., 'EcoNetSchemaShard2026v2.aln')
    output_schema_ref TEXT, -- ALN schema for outputs
    ker_requirements TEXT, -- JSON: {"k_min":0.90,"e_min":0.90,"r_max":0.13}
    non_actuating_only INTEGER NOT NULL DEFAULT 0 CHECK(non_actuating_only IN (0,1)),
    
    -- Governance and lifecycle
    lane_eligible TEXT NOT NULL CHECK(lane_eligible IN ('RESEARCH', 'EXPPROD', 'PROD', 'ARCHIVE')),
    current_lane TEXT CHECK(current_lane IN ('RESEARCH', 'EXPPROD', 'PROD', 'ARCHIVE')),
    ecosafety_binding TEXT NOT NULL, -- e.g., 'EcosafetyGrammar2026v1.aln'
    shard_protocol TEXT NOT NULL, -- e.g., 'ALN-RFC4180/EcoNetSchemaShard2026v1'
    
    -- Provenance and integrity
    content_hash TEXT NOT NULL, -- SHA2-256 hex of canonical asset representation
    signing_did TEXT NOT NULL, -- Bostrom DID of asset author/curator
    evidence_hex TEXT, -- hexstamp of validation evidence
    
    -- Operational metadata
    created_utc TEXT NOT NULL,
    updated_utc TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
    deprecated INTEGER NOT NULL DEFAULT 0 CHECK(deprecated IN (0,1)),
    
    -- Foreign keys to constellation spine
    repo_name TEXT NOT NULL, -- owning repository
    github_slug TEXT, -- e.g., 'Doctor0Evil/EcoNet'
    
    UNIQUE(asset_name, asset_version)
);

CREATE INDEX IF NOT EXISTS idx_eco_asset_type_plane ON eco_asset_registry(asset_type, primary_plane);
CREATE INDEX IF NOT EXISTS idx_eco_asset_region_lane ON eco_asset_registry(region_scope, current_lane);
CREATE INDEX IF NOT EXISTS idx_eco_asset_active ON eco_asset_registry(active, deprecated);
CREATE INDEX IF NOT EXISTS idx_eco_asset_repo ON eco_asset_registry(repo_name);

--------------------------------------------------------------------------------
-- Asset Deployment Targets: Where assets can be safely deployed
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS asset_deployment_targets (
    target_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id INTEGER NOT NULL REFERENCES eco_asset_registry(asset_id) ON DELETE CASCADE,
    
    -- Target identification
    node_id TEXT NOT NULL, -- e.g., 'CAP-LP-HBUF-01', 'GILA-RCH-SITE-07'
    region TEXT NOT NULL,
    medium TEXT CHECK(medium IN ('water', 'air', 'soil', 'bio', 'hybrid', 'other')),
    
    -- Deployment constraints
    lane_required TEXT NOT NULL CHECK(lane_required IN ('RESEARCH', 'EXPPROD', 'PROD')),
    ker_thresholds TEXT, -- JSON overrides for this target
    corridor_overrides TEXT, -- JSON of varid-specific corridor adjustments
    
    -- Energy and resource profile
    energy_budget_joules REAL, -- max energy per deployment window
    data_retention_days INTEGER, -- how long evidence is kept at this target
    offline_capable INTEGER NOT NULL DEFAULT 0 CHECK(offline_capable IN (0,1)),
    
    -- Governance
    deployment_approved INTEGER NOT NULL DEFAULT 0 CHECK(deployment_approved IN (0,1)),
    approved_by_did TEXT,
    approved_utc TEXT,
    
    UNIQUE(asset_id, node_id, lane_required)
);

CREATE INDEX IF NOT EXISTS idx_deployment_asset_node ON asset_deployment_targets(asset_id, node_id);
CREATE INDEX IF NOT EXISTS idx_deployment_region_lane ON asset_deployment_targets(region, lane_required);

--------------------------------------------------------------------------------
-- Asset Performance History: Track K/E/R outcomes per deployment
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS asset_performance_history (
    perf_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id INTEGER NOT NULL REFERENCES eco_asset_registry(asset_id) ON DELETE CASCADE,
    target_id INTEGER REFERENCES asset_deployment_targets(target_id) ON DELETE SET NULL,
    
    -- Measurement window
    window_start_utc TEXT NOT NULL,
    window_end_utc TEXT NOT NULL,
    
    -- Observed KER metrics
    k_observed REAL NOT NULL CHECK(k_observed >= 0.0 AND k_observed <= 1.0),
    e_observed REAL NOT NULL CHECK(e_observed >= 0.0 AND e_observed <= 1.0),
    r_observed REAL NOT NULL CHECK(r_observed >= 0.0 AND r_observed <= 1.0),
    residual_v REAL NOT NULL CHECK(residual_v >= 0.0),
    
    -- Plane-specific risk coordinates (optional, for detailed analysis)
    plane_risks TEXT, -- JSON: {"energy":0.12,"hydraulics":0.08,...}
    
    -- Evidence and validation
    evidence_shard_id INTEGER, -- reference to shard_instance if applicable
    validation_status TEXT CHECK(validation_status IN ('PENDING', 'VERIFIED', 'FAILED', 'REVIEW')),
    
    -- Operational context
    deployment_config_hash TEXT, -- hash of config used during this window
    notes TEXT,
    
    UNIQUE(asset_id, target_id, window_start_utc, window_end_utc)
);

CREATE INDEX IF NOT EXISTS idx_perf_asset_window ON asset_performance_history(asset_id, window_start_utc);
CREATE INDEX IF NOT EXISTS idx_perf_ker_summary ON asset_performance_history(k_observed, e_observed, r_observed);

--------------------------------------------------------------------------------
-- Asset Compatibility Matrix: Which assets work together safely
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS asset_compatibility_matrix (
    compat_id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    asset_a_id INTEGER NOT NULL REFERENCES eco_asset_registry(asset_id) ON DELETE CASCADE,
    asset_b_id INTEGER NOT NULL REFERENCES eco_asset_registry(asset_id) ON DELETE CASCADE,
    
    -- Compatibility assessment
    compatibility_score REAL NOT NULL CHECK(compatibility_score >= 0.0 AND compatibility_score <= 1.0),
    compatibility_reason TEXT, -- human-readable explanation
    
    -- Interaction effects on KER
    delta_k_estimate REAL, -- expected change in K when used together
    delta_e_estimate REAL, -- expected change in E when used together
    delta_r_estimate REAL, -- expected change in R when used together
    
    -- Constraints and warnings
    requires_same_lane INTEGER NOT NULL DEFAULT 0 CHECK(requires_same_lane IN (0,1)),
    requires_same_region INTEGER NOT NULL DEFAULT 0 CHECK(requires_same_region IN (0,1)),
    non_offsettable_plane_conflicts TEXT, -- comma-separated list of planes that cannot worsen
    
    -- Provenance
    assessed_by_did TEXT NOT NULL,
    assessed_utc TEXT NOT NULL,
    evidence_hex TEXT,
    
    UNIQUE(asset_a_id, asset_b_id)
);

CREATE INDEX IF NOT EXISTS idx_compat_score ON asset_compatibility_matrix(compatibility_score);
CREATE INDEX IF NOT EXISTS idx_compat_planes ON asset_compatibility_matrix(non_offsettable_plane_conflicts);

-- End of eco_asset_registry_schema.sql
