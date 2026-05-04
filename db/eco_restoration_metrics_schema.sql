-- filename: db/eco_restoration_metrics_schema.sql
-- destination: Eco-Fort/db/eco_restoration_metrics_schema.sql
-- purpose: Standardized metrics collection for eco-restoration project evaluation
-- owner: Eco-Fort (SPINE band)
-- ker_impact: K↑ E↑ (enables evidence-based improvement, reduces guesswork)

PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- Restoration Project Registry: Track eco-restoration initiatives
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS restoration_project_registry (
    project_id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Project identity
    project_name TEXT NOT NULL UNIQUE,
    project_code TEXT UNIQUE, -- short code for references (e.g., 'PHX-HYDRO-2026')
    description TEXT NOT NULL,
    
    -- Ecological scope
    primary_restoration_goal TEXT NOT NULL CHECK(primary_restoration_goal IN (
        'water_quality', 'habitat_restoration', 'carbon_sequestration', 
        'biodiversity_enhancement', 'pollution_remediation', 'erosion_control',
        'species_corridor', 'waste_reduction', 'energy_efficiency', 'multi_goal'
    )),
    target_ecosystems TEXT NOT NULL, -- comma-separated: 'freshwater,wetland,riparian'
    geographic_bounds TEXT NOT NULL, -- GeoJSON or WKT polygon
    
    -- Temporal scope
    project_start_utc TEXT NOT NULL,
    project_end_utc TEXT, -- NULL for ongoing projects
    monitoring_frequency TEXT CHECK(monitoring_frequency IN ('hourly', 'daily', 'weekly', 'monthly', 'quarterly')),
    
    -- Governance and funding
    lead_repo TEXT NOT NULL, -- primary repository managing this project
    funding_source TEXT,
    governance_model TEXT CHECK(governance_model IN ('centralized', 'federated', 'community', 'hybrid')),
    
    -- KER targets for project success
    target_k REAL CHECK(target_k >= 0.0 AND target_k <= 1.0),
    target_e REAL CHECK(target_e >= 0.0 AND target_e <= 1.0),
    target_r_max REAL CHECK(target_r_max >= 0.0 AND target_r_max <= 1.0),
    
    -- Provenance
    created_by_did TEXT NOT NULL,
    created_utc TEXT NOT NULL,
    updated_utc TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1))
);

CREATE INDEX IF NOT EXISTS idx_project_goal_ecosystem ON restoration_project_registry(primary_restoration_goal, target_ecosystems);
CREATE INDEX IF NOT EXISTS idx_project_active ON restoration_project_registry(active);

--------------------------------------------------------------------------------
-- Standardized Restoration Metrics: Common measurement schema
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS restoration_metric_definitions (
    metric_id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Metric identity
    metric_name TEXT NOT NULL UNIQUE, -- e.g., 'PFAS_CONCENTRATION_NG_L', 'MACROINVERTEBRATE_RICHNESS'
    metric_code TEXT NOT NULL UNIQUE, -- short code: 'PFAS_NG', 'MACRO_RICH'
    description TEXT NOT NULL,
    
    -- Measurement characteristics
    data_type TEXT NOT NULL CHECK(data_type IN ('continuous', 'categorical', 'count', 'boolean', 'text')),
    units TEXT, -- e.g., 'ng/L', 'cfu/100mL', 'species_count', 'dimensionless'
    valid_range_min REAL,
    valid_range_max REAL,
    
    -- Ecological relevance
    related_planes TEXT NOT NULL, -- comma-separated: 'biology,water_quality'
    restoration_goals TEXT, -- which goals this metric informs
    sensitivity_to_change TEXT CHECK(sensitivity_to_change IN ('high', 'medium', 'low')),
    
    -- Data quality requirements
    required_precision REAL, -- e.g., 0.01 for 2 decimal places
    required_accuracy REAL, -- e.g., 0.95 for 95% accuracy target
    calibration_frequency TEXT, -- e.g., 'monthly', 'per_deployment'
    
    -- Governance
    metric_authority TEXT NOT NULL, -- organization or standard defining this metric
    version TEXT NOT NULL,
    deprecated INTEGER NOT NULL DEFAULT 0 CHECK(deprecated IN (0,1)),
    
    UNIQUE(metric_name, version)
);

CREATE INDEX IF NOT EXISTS idx_metric_planes ON restoration_metric_definitions(related_planes);
CREATE INDEX IF NOT EXISTS idx_metric_active ON restoration_metric_definitions(deprecated);

--------------------------------------------------------------------------------
-- Metric Observations: Actual measurements from restoration projects
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS restoration_metric_observations (
    observation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Linkage
    project_id INTEGER NOT NULL REFERENCES restoration_project_registry(project_id) ON DELETE CASCADE,
    metric_id INTEGER NOT NULL REFERENCES restoration_metric_definitions(metric_id) ON DELETE CASCADE,
    asset_id INTEGER REFERENCES eco_asset_registry(asset_id) ON DELETE SET NULL, -- which asset collected this
    
    -- Observation context
    observation_utc TEXT NOT NULL,
    location_geojson TEXT NOT NULL, -- point or polygon where measurement was taken
    medium TEXT CHECK(medium IN ('water', 'air', 'soil', 'bio', 'sediment', 'other')),
    depth_or_height_m REAL, -- vertical position if relevant
    
    -- Measurement value
    metric_value REAL, -- for continuous/count metrics
    metric_text_value TEXT, -- for categorical/text metrics
    metric_boolean_value INTEGER CHECK(metric_boolean_value IN (0,1)), -- for boolean metrics
    
    -- Data quality indicators
    measurement_uncertainty REAL, -- standard error or confidence interval half-width
    detection_limit REAL, -- for non-detects
    quality_flag TEXT CHECK(quality_flag IN ('verified', 'provisional', 'estimated', 'invalid')),
    
    -- Provenance and integrity
    instrument_id TEXT, -- which sensor/device collected this
    operator_did TEXT, -- who performed/validated the measurement
    evidence_hex TEXT NOT NULL, -- hexstamp of raw data + processing steps
    signing_did TEXT NOT NULL,
    
    -- Derived KER contribution (optional, computed)
    contributes_to_k REAL,
    contributes_to_e REAL,
    contributes_to_r REAL,
    
    UNIQUE(project_id, metric_id, observation_utc, location_geojson)
);

CREATE INDEX IF NOT EXISTS idx_observation_project_metric ON restoration_metric_observations(project_id, metric_id);
CREATE INDEX IF NOT EXISTS idx_observation_time_location ON restoration_metric_observations(observation_utc, location_geojson);
CREATE INDEX IF NOT EXISTS idx_observation_quality ON restoration_metric_observations(quality_flag);

--------------------------------------------------------------------------------
-- Metric Aggregations: Pre-computed summaries for dashboards and decisions
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS restoration_metric_aggregates (
    aggregate_id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Scope of aggregation
    project_id INTEGER NOT NULL REFERENCES restoration_project_registry(project_id) ON DELETE CASCADE,
    metric_id INTEGER NOT NULL REFERENCES restoration_metric_definitions(metric_id) ON DELETE CASCADE,
    aggregation_region TEXT, -- NULL for project-wide, or specific region code
    aggregation_medium TEXT,
    
    -- Time window
    window_start_utc TEXT NOT NULL,
    window_end_utc TEXT NOT NULL,
    aggregation_period TEXT CHECK(aggregation_period IN ('hourly', 'daily', 'weekly', 'monthly', 'project')),
    
    -- Statistical summaries
    observation_count INTEGER NOT NULL,
    value_mean REAL,
    value_median REAL,
    value_stddev REAL,
    value_min REAL,
    value_max REAL,
    value_p05 REAL, -- 5th percentile
    value_p95 REAL, -- 95th percentile
    
    -- Quality summaries
    verified_count INTEGER,
    provisional_count INTEGER,
    estimated_count INTEGER,
    invalid_count INTEGER,
    
    -- Trend indicators
    trend_slope REAL, -- linear regression slope over window
    trend_significance REAL, -- p-value for trend
    change_from_baseline REAL, -- if baseline is defined for this metric
    
    -- Computed at aggregation time
    computed_utc TEXT NOT NULL,
    computation_method TEXT NOT NULL, -- e.g., 'simple_mean', 'weighted_by_uncertainty'
    
    UNIQUE(project_id, metric_id, aggregation_region, aggregation_medium, window_start_utc, window_end_utc)
);

CREATE INDEX IF NOT EXISTS idx_aggregate_project_window ON restoration_metric_aggregates(project_id, window_start_utc);
CREATE INDEX IF NOT EXISTS idx_aggregate_metric ON restoration_metric_aggregates(metric_id);

-- End of eco_restoration_metrics_schema.sql
