-- filename: db_api_endpoint_calibration.sql
-- destination: Eco-Fort/db/db_api_endpoint_calibration.sql

PRAGMA foreign_keys = ON;

-------------------------------------------------------------------------------
-- API Endpoint Calibration Registry
-- Stable, fail-safe calibration methods for secure handoff, IP routing,
-- and hex-array seed distance calculations prioritizing complexity-handling.
-------------------------------------------------------------------------------

-- Main endpoint calibration table for constellation-wide API surface
CREATE TABLE IF NOT EXISTS api_endpoint_calibration (
    endpoint_id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Domain category and naming
    domain_category TEXT NOT NULL CHECK(domain_category IN (
        'GOVERNANCE_QUERY',
        'SHARD_DISCOVERY',
        'LANE_VERIFICATION',
        'KER_ASSESSMENT',
        'PLACEMENT_ADVISORY',
        'TOPOLOGY_AUDIT',
        'HEALTH_CORRIDOR',
        'ENERGY_ROUTING',
        'SECURE_HANDOFF',
        'BLAST_RADIUS_CALC'
    )),
    endpoint_name TEXT NOT NULL,
    endpoint_pattern TEXT NOT NULL, -- e.g., '/api/v1/shard/{shard_id}/ker'

    -- Calibration method for stable operation
    calibration_method TEXT NOT NULL CHECK(calibration_method IN (
        'HEX_SEED_DISTANCE',
        'COMPLEXITY_WEIGHTED',
        'SESSION_FREE_HASH',
        'DID_ANCHOR_CHAIN',
        'GEOMETRIC_PROXIMITY',
        'LYAPUNOV_BOUNDED',
        'KER_THRESHOLD_GATE',
        'CORRIDOR_POLYTOPE'
    )),

    -- Hex-array configuration for seed distance
    hex_seed_base TEXT, -- Base hex value for distance calculation
    hex_array_length INTEGER DEFAULT 32, -- Bytes in hex array
    seed_distance_formula TEXT, -- e.g., 'hamming(H1,H2) + geometric_dist'

    -- Complexity handling priority
    complexity_priority INTEGER NOT NULL DEFAULT 1 CHECK(complexity_priority >= 1 AND complexity_priority <= 10),
    max_complexity_score REAL, -- Upper bound on computational complexity

    -- Session token alternative (session-free preferred)
    uses_session_tokens INTEGER NOT NULL DEFAULT 0 CHECK(uses_session_tokens IN (0,1)),
    session_free_mechanism TEXT, -- 'DID_CHAIN', 'HEX_PROOF', 'TIME_BOUNDED_NONCE'

    -- IP routing and handoff configuration
    ip_routing_policy TEXT NOT NULL CHECK(ip_routing_policy IN (
        'DIRECT_NODE',
        'BLAST_RADIUS_AWARE',
        'CORRIDOR_CONSTRAINED',
        'MULTI_HOP_GOVERNED',
        'SOVEREIGN_LOCAL_ONLY'
    )),

    -- Security and governance
    requires_signing_did INTEGER NOT NULL DEFAULT 1 CHECK(requires_signing_did IN (0,1)),
    governance_contract_ref TEXT, -- Link to ALN governance shard

    -- Additional field specifications (JSON-encoded for flexibility)
    additional_fields TEXT, -- JSON: {"field_name": "type", "constraints": [...]}

    -- Metadata
    created_utc TEXT NOT NULL,
    updated_utc TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),

    UNIQUE(domain_category, endpoint_name)
);

CREATE INDEX IF NOT EXISTS idx_endpoint_domain ON api_endpoint_calibration(domain_category);
CREATE INDEX IF NOT EXISTS idx_endpoint_calibration_method ON api_endpoint_calibration(calibration_method);
CREATE INDEX IF NOT EXISTS idx_endpoint_complexity ON api_endpoint_calibration(complexity_priority, max_complexity_score);
CREATE INDEX IF NOT EXISTS idx_endpoint_routing ON api_endpoint_calibration(ip_routing_policy);

-------------------------------------------------------------------------------
-- Hex-Array Seed Distance Configuration
-- Pre-computed seed values and distance metrics for fast endpoint routing
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hex_seed_distance_config (
    config_id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Reference to endpoint
    endpoint_id INTEGER NOT NULL REFERENCES api_endpoint_calibration(endpoint_id) ON DELETE CASCADE,

    -- Seed hex values
    seed_hex_value TEXT NOT NULL, -- Primary hex seed (32-64 bytes)
    seed_family TEXT NOT NULL, -- e.g., 'GOVERNANCE', 'HEALTH', 'ENERGY'

    -- Distance calculation parameters
    distance_metric TEXT NOT NULL CHECK(distance_metric IN (
        'HAMMING',
        'EUCLIDEAN_HEX',
        'GRAPH_HOP',
        'LYAPUNOV_DELTA',
        'KER_DIVERGENCE'
    )),
    distance_threshold REAL NOT NULL, -- Max allowed distance for valid handoff

    -- Complexity weights
    computation_weight REAL NOT NULL DEFAULT 1.0,
    memory_weight REAL NOT NULL DEFAULT 1.0,
    network_weight REAL NOT NULL DEFAULT 1.0,

    -- IP table integration
    ip_table_segment TEXT, -- Which IP routing table segment to use
    preferred_node_list TEXT, -- Comma-separated node IDs

    -- Metadata
    created_utc TEXT NOT NULL,
    updated_utc TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1))
);

CREATE INDEX IF NOT EXISTS idx_hex_seed_endpoint ON hex_seed_distance_config(endpoint_id);
CREATE INDEX IF NOT EXISTS idx_hex_seed_family ON hex_seed_distance_config(seed_family);
CREATE INDEX IF NOT EXISTS idx_hex_seed_distance ON hex_seed_distance_config(distance_metric, distance_threshold);

-------------------------------------------------------------------------------
-- Secure Handoff Package Specification
-- Defines package structure for inter-node secure transfers
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS secure_handoff_package (
    package_id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Package identity
    package_type TEXT NOT NULL CHECK(package_type IN (
        'SHARD_TRANSFER',
        'KER_ATTESTATION',
        'LANE_PROMOTION',
        'HEALTH_CORRIDOR_UPDATE',
        'GOVERNANCE_DIRECTIVE',
        'TOPOLOGY_STATUS'
    )),
    package_name TEXT NOT NULL,

    -- Source and destination
    source_node_id TEXT NOT NULL,
    dest_node_id TEXT NOT NULL,
    blast_radius_id INTEGER REFERENCES blastradiusobject(broid) ON DELETE SET NULL,

    -- Hex-encoded payload descriptor
    payload_hex_descriptor TEXT NOT NULL, -- Compact hex encoding of package contents
    payload_schema_ref TEXT, -- ALN schema reference

    -- Calibration linkage
    endpoint_id INTEGER REFERENCES api_endpoint_calibration(endpoint_id) ON DELETE SET NULL,

    -- Seed distance verification
    seed_hex_source TEXT NOT NULL,
    seed_hex_dest TEXT NOT NULL,
    computed_distance REAL,

    -- Security
    signing_did TEXT NOT NULL,
    evidence_hex TEXT NOT NULL,
    roh_anchor_hex TEXT, -- Rule-of-History chain anchor

    -- Transfer status
    transfer_status TEXT NOT NULL CHECK(transfer_status IN (
        'PENDING',
        'IN_TRANSIT',
        'DELIVERED',
        'VERIFIED',
        'FAILED'
    )),

    -- Timestamps
    created_utc TEXT NOT NULL,
    delivered_utc TEXT,
    verified_utc TEXT,

    active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1))
);

CREATE INDEX IF NOT EXISTS idx_handoff_package_type ON secure_handoff_package(package_type);
CREATE INDEX IF NOT EXISTS idx_handoff_nodes ON secure_handoff_package(source_node_id, dest_node_id);
CREATE INDEX IF NOT EXISTS idx_handoff_status ON secure_handoff_package(transfer_status);
CREATE INDEX IF NOT EXISTS idx_handoff_endpoint ON secure_handoff_package(endpoint_id);

-------------------------------------------------------------------------------
-- IP Routing Table for Constellation Nodes
-- Maps logical node IDs to network addresses with governance constraints
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS constellation_ip_routing (
    route_id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Node identity
    node_id TEXT NOT NULL,
    node_type TEXT NOT NULL CHECK(node_type IN (
        'SPINE',
        'RESEARCH',
        'ENGINE',
        'MATERIAL',
        'GOV',
        'APP',
        'HEALTH_EDGE',
        'CITY_CONTROLLER'
    )),

    -- Network addressing
    ipv4_address TEXT,
    ipv6_address TEXT,
    port_range TEXT, -- e.g., '8000-8100'

    -- Routing policy
    routing_policy TEXT NOT NULL CHECK(routing_policy IN (
        'DIRECT',
        'BLAST_RADIUS_CONSTRAINED',
        'CORRIDOR_GATED',
        'GOVERNED_MULTI_HOP',
        'SOVEREIGN_LOCAL'
    )),

    -- Hex-based routing hints
    node_hex_identity TEXT NOT NULL, -- Stable hex identifier for node
    routing_hex_seed TEXT, -- Seed for distance-based routing decisions

    -- Geographic and blast radius context
    region TEXT NOT NULL, -- e.g., 'Phoenix-AZ', 'Central-AZ'
    blast_radius_id INTEGER REFERENCES blastradiusobject(broid) ON DELETE SET NULL,

    -- Governance and lane constraints
    max_lane_allowed TEXT NOT NULL DEFAULT 'RESEARCH' CHECK(max_lane_allowed IN ('RESEARCH','EXPPROD','PROD')),
    requires_did_verification INTEGER NOT NULL DEFAULT 1 CHECK(requires_did_verification IN (0,1)),

    -- Connectivity status
    online_status INTEGER NOT NULL DEFAULT 0 CHECK(online_status IN (0,1)),
    last_heartbeat_utc TEXT,

    -- Metadata
    created_utc TEXT NOT NULL,
    updated_utc TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),

    UNIQUE(node_id)
);

CREATE INDEX IF NOT EXISTS idx_ip_routing_node_type ON constellation_ip_routing(node_type);
CREATE INDEX IF NOT EXISTS idx_ip_routing_region ON constellation_ip_routing(region);
CREATE INDEX IF NOT EXISTS idx_ip_routing_policy ON constellation_ip_routing(routing_policy);
CREATE INDEX IF NOT EXISTS idx_ip_routing_lane ON constellation_ip_routing(max_lane_allowed);
CREATE INDEX IF NOT EXISTS idx_ip_routing_status ON constellation_ip_routing(online_status);

-------------------------------------------------------------------------------
-- View: Endpoint Calibration with Hex Seed Summary
-------------------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS v_endpoint_calibration_summary AS
SELECT 
    e.endpoint_id,
    e.domain_category,
    e.endpoint_name,
    e.endpoint_pattern,
    e.calibration_method,
    e.complexity_priority,
    e.ip_routing_policy,
    e.uses_session_tokens,
    COUNT(h.config_id) AS hex_seed_count,
    GROUP_CONCAT(h.seed_family, ',') AS seed_families
FROM api_endpoint_calibration e
LEFT JOIN hex_seed_distance_config h ON e.endpoint_id = h.endpoint_id
WHERE e.active = 1
GROUP BY e.endpoint_id;

-------------------------------------------------------------------------------
-- View: Active Secure Handoff Packages with Routing Info
-------------------------------------------------------------------------------

CREATE VIEW IF NOT EXISTS v_active_handoff_packages AS
SELECT 
    p.package_id,
    p.package_type,
    p.package_name,
    p.source_node_id,
    p.dest_node_id,
    p.transfer_status,
    p.computed_distance,
    s.ipv4_address AS source_ip,
    d.ipv4_address AS dest_ip,
    s.region AS source_region,
    d.region AS dest_region,
    p.created_utc,
    p.delivered_utc
FROM secure_handoff_package p
LEFT JOIN constellation_ip_routing s ON p.source_node_id = s.node_id
LEFT JOIN constellation_ip_routing d ON p.dest_node_id = d.node_id
WHERE p.active = 1 AND p.transfer_status != 'FAILED';
