# API Endpoint Calibration & Secure Handoff Specification

**Filename:** `doc_api_endpoint_calibration.md`  
**Destination:** `Eco-Fort/doc/doc_api_endpoint_calibration.md`

## Overview

This document specifies stable, fail-safe calibration methods for API endpoints, secure package handoff protocols, and IP routing tables within the EcoNet constellation. The design prioritizes **complexity-handling over session tokens**, using hex-array seed distance calculations and DID-anchored verification chains to eliminate stateful session management while maintaining security and routing efficiency.

---

## Domain Categories for API Endpoints

The constellation organizes API endpoints into **ten stable domain categories**, each with specific calibration requirements and governance contracts:

### 1. GOVERNANCE_QUERY
**Purpose:** Query governance verdicts, lane decisions, and topology status.  
**Example Endpoints:**
- `/api/v1/governance/lane/{kernel_id}/status`
- `/api/v1/governance/topology/audit/{repo_name}`

**Calibration Method:** `DID_ANCHOR_CHAIN`  
**Session-Free Mechanism:** Each request carries a DID signature and timestamp nonce; no server-side session state required.  
**Complexity Priority:** 3 (moderate — database lookups with signature verification)

---

### 2. SHARD_DISCOVERY
**Purpose:** Discover and index shards by region, plane, lane, and KER thresholds.  
**Example Endpoints:**
- `/api/v1/shard/discover?region={region}&plane={plane}&lane={lane}`
- `/api/v1/shard/{shard_id}/metadata`

**Calibration Method:** `HEX_SEED_DISTANCE`  
**Hex-Array Configuration:**
- **Seed Base:** SHA3-256 hash of `(region || plane || lane)`
- **Distance Metric:** Hamming distance on 32-byte hex values
- **Threshold:** ≤ 8 bit differences for same-region matches

**Complexity Priority:** 2 (low — indexed SQLite queries with hex comparisons)

---

### 3. LANE_VERIFICATION
**Purpose:** Verify lane eligibility and KER thresholds for artifact promotion.  
**Example Endpoints:**
- `/api/v1/lane/verify/{artifact_id}?target_lane={lane}`
- `/api/v1/lane/promotion/request`

**Calibration Method:** `KER_THRESHOLD_GATE`  
**Complexity Priority:** 5 (high — requires Lyapunov residual computation and plane weight lookups)  
**Max Complexity Score:** 0.25 (normalized compute time in seconds)

---

### 4. KER_ASSESSMENT
**Purpose:** Compute and report Knowledge-Eco-Risk metrics for artifacts and shards.  
**Example Endpoints:**
- `/api/v1/ker/compute/{shard_id}`
- `/api/v1/ker/window/{start_utc}/{end_utc}`

**Calibration Method:** `LYAPUNOV_BOUNDED`  
**Complexity Priority:** 6 (high — multi-plane residual calculations)  
**Session-Free Mechanism:** `TIME_BOUNDED_NONCE` with 60-second validity window

---

### 5. PLACEMENT_ADVISORY
**Purpose:** Recommend node placement for workloads considering blast radius and energy cost.  
**Example Endpoints:**
- `/api/v1/placement/advise?shard_id={id}&region={region}`
- `/api/v1/placement/cost_estimate`

**Calibration Method:** `GEOMETRIC_PROXIMITY` + `BLAST_RADIUS_CALC`  
**IP Routing Policy:** `BLAST_RADIUS_AWARE`  
**Complexity Priority:** 7 (very high — graph traversal + energy modeling)

---

### 6. TOPOLOGY_AUDIT
**Purpose:** Report topology inconsistencies and rtopology risk coordinates.  
**Example Endpoints:**
- `/api/v1/topology/audit/run`
- `/api/v1/topology/issues/{repo_name}`

**Calibration Method:** `COMPLEXITY_WEIGHTED`  
**Complexity Priority:** 4 (moderate-high — repository scanning with rule checks)

---

### 7. HEALTH_CORRIDOR
**Purpose:** Manage MT6883 healthcare corridors, detox schedules, and RoH attestations.  
**Example Endpoints:**
- `/api/v1/health/corridor/{citizen_id}/detox`
- `/api/v1/health/roh/attestation`

**Calibration Method:** `CORRIDOR_POLYTOPE`  
**Hex Seed Family:** `HEALTH`  
**Complexity Priority:** 8 (critical — real-time RoH guard kernel evaluation)  
**IP Routing Policy:** `SOVEREIGN_LOCAL_ONLY` (healthcare data never leaves local node)

---

### 8. ENERGY_ROUTING
**Purpose:** Optimize energy distribution and IoT telemetry aggregation for smart-city workloads.  
**Example Endpoints:**
- `/api/v1/energy/route/{node_id}`
- `/api/v1/energy/telemetry/aggregate`

**Calibration Method:** `HEX_SEED_DISTANCE` + `GEOMETRIC_PROXIMITY`  
**Seed Distance Formula:** `hamming(H1, H2) + euclidean_dist(lat1, lon1, lat2, lon2)`  
**Complexity Priority:** 5

---

### 9. SECURE_HANDOFF
**Purpose:** Transfer packages (shards, governance directives, attestations) between nodes with verification.  
**Example Endpoints:**
- `/api/v1/handoff/initiate`
- `/api/v1/handoff/{package_id}/verify`

**Calibration Method:** `SESSION_FREE_HASH`  
**Hex-Array Configuration:**
- **Seed Hex Source:** Node's stable DID-derived hex identity
- **Seed Hex Dest:** Destination node's hex identity
- **Distance Metric:** `HAMMING` + `GRAPH_HOP`
- **Threshold:** ≤ 16 hops in adjacency graph

**IP Routing Policy:** `CORRIDOR_CONSTRAINED` or `GOVERNED_MULTI_HOP`  
**Complexity Priority:** 6

---

### 10. BLAST_RADIUS_CALC
**Purpose:** Compute and query blast radius objects for spatial impact analysis.  
**Example Endpoints:**
- `/api/v1/blast_radius/compute/{shard_id}`
- `/api/v1/blast_radius/neighbors/{node_id}`

**Calibration Method:** `GEOMETRIC_PROXIMITY`  
**Hex Seed Family:** `SPATIAL`  
**Complexity Priority:** 4

---

## Calibration Methods Specification

### HEX_SEED_DISTANCE
**Description:** Uses pre-computed hex seed values and distance metrics (Hamming, Euclidean-on-hex) to route requests without session state.

**Parameters:**
- `hex_seed_base`: 32-64 byte hex string
- `distance_metric`: `HAMMING`, `EUCLIDEAN_HEX`, `GRAPH_HOP`
- `distance_threshold`: Maximum allowed distance for valid routing

**Use Cases:** Shard discovery, energy routing, spatial queries

---

### COMPLEXITY_WEIGHTED
**Description:** Assigns complexity scores to operations and routes to nodes with sufficient capacity.

**Parameters:**
- `computation_weight`: CPU cost multiplier
- `memory_weight`: RAM cost multiplier
- `network_weight`: I/O cost multiplier
- `max_complexity_score`: Upper bound for accepting requests

**Use Cases:** Topology audits, large-particle summarization

---

### SESSION_FREE_HASH
**Description:** Each request includes a cryptographic proof (DID signature + nonce hash) instead of server-side session.

**Mechanism:**
1. Client computes `request_hash = SHA3-256(endpoint || params || timestamp || DID)`
2. Client signs hash with DID private key
3. Server verifies signature and timestamp freshness (< 60s old)
4. No session storage required

**Use Cases:** Secure handoff, governance queries

---

### DID_ANCHOR_CHAIN
**Description:** Links requests to a DID-based chain-of-custody for auditability.

**Mechanism:**
- Every request includes `prev_anchor_hex` from last interaction
- Server computes `new_anchor = SHA3-256(request_hash || prev_anchor_hex)`
- Forms append-only audit log per DID

**Use Cases:** Governance queries, lane verification, provenance tracking

---

### LYAPUNOV_BOUNDED
**Description:** Routes only if operation preserves Lyapunov descent (V(t+1) ≤ V(t)).

**Parameters:**
- Plane weights from `planeweightscontract`
- Current risk vector from `shardinstance`
- Proposed operation's delta-V estimate

**Use Cases:** KER assessment, lane promotion

---

### KER_THRESHOLD_GATE
**Description:** Accepts requests only if artifact meets minimum K, E thresholds and maximum R.

**Thresholds (by lane):**
- RESEARCH: K ≥ 0.70, E ≥ 0.70, R ≤ 0.25
- EXPPROD: K ≥ 0.85, E ≥ 0.85, R ≤ 0.18
- PROD: K ≥ 0.90, E ≥ 0.90, R ≤ 0.13

**Use Cases:** Lane verification, artifact promotion

---

### CORRIDOR_POLYTOPE
**Description:** Verifies request parameters lie within safe corridor polytope (A·x ≤ b).

**Use Cases:** Healthcare RoH checks, detox scheduling, nanoswarm deployment

---

### GEOMETRIC_PROXIMITY
**Description:** Routes to nearest node using spatial distance (lat/lon or graph hops).

**Distance Calculation:**
- 2D: Haversine distance for geographic coordinates
- Graph: Shortest path in `nodeadjacency` table

**Use Cases:** Placement advisory, energy routing, blast radius

---

## IP Routing Policies

### DIRECT_NODE
Single-hop routing to explicitly named node. No intermediate relays.

### BLAST_RADIUS_AWARE
Routes avoid nodes whose blast radius overlaps with forbidden zones or exceeds continuity thresholds.

### CORRIDOR_CONSTRAINED
Routes must satisfy corridor polytope constraints at every hop.

### MULTI_HOP_GOVERNED
Multi-hop routing with governance checks at each relay node (lane, KER, topology).

### SOVEREIGN_LOCAL_ONLY
No network routing — data never leaves originating node. Used for sensitive healthcare or personal data.

---

## Hex-Array Seed Distance Examples

### Example 1: Shard Discovery in Phoenix Hydraulics

**Scenario:** Find all shards in `Phoenix-AZ` region, `hydraulics` plane, `EXPPROD` lane.

**Seed Construction:**
```
region = "Phoenix-AZ"
plane = "hydraulics"
lane = "EXPPROD"
seed_input = region + "|" + plane + "|" + lane
seed_hex = SHA3-256(seed_input)
       = 0xa7f3c21e8d4b9a1f...
```

**Distance Calculation:**
```
For each shard S:
  shard_hex = SHA3-256(S.region + "|" + S.plane + "|" + S.lane)
  distance = hamming(seed_hex, shard_hex)

Accept if distance ≤ 8 bits
```

**Result:** All exact matches have distance = 0; near-matches (e.g., different lane) have distance > 8.

---

### Example 2: Secure Handoff Between Nodes

**Scenario:** Transfer a governance directive from node `PHX-GOV-01` to `PHX-HYDRO-02`.

**Seed Hex Values:**
```
source_hex = node_hex_identity("PHX-GOV-01")
           = 0x3f7a8c4e...
dest_hex   = node_hex_identity("PHX-HYDRO-02")
           = 0x3f7b9d5f...
```

**Distance Metrics:**
```
hamming_distance = 6 bits
graph_hops = 2 (via nodeadjacency table)
combined_distance = hamming_distance + 10 * graph_hops = 26
```

**Threshold:** 32  
**Decision:** ACCEPT (distance 26 < 32)

**IP Routing:**
- Lookup `constellation_ip_routing` for both nodes
- Verify `dest_node` is ONLINE and in allowed lane
- Initiate transfer with `secure_handoff_package` entry

---

## Additional Field Specifications

Endpoints can declare additional fields in JSON format for extended parameters:

```json
{
  "additional_fields": {
    "window_start_utc": {
      "type": "ISO8601",
      "required": true,
      "description": "Start of KER assessment window"
    },
    "window_end_utc": {
      "type": "ISO8601",
      "required": true
    },
    "include_secondary_planes": {
      "type": "boolean",
      "default": false
    },
    "max_results": {
      "type": "integer",
      "min": 1,
      "max": 1000,
      "default": 100
    }
  }
}
```

These are stored in `api_endpoint_calibration.additional_fields` and parsed by endpoint handlers.

---

## Integration with EcoNet Constellation

### Discovery Workflow

1. **Agent or service** queries `v_endpoint_calibration_summary` view to find available endpoints by domain category
2. Reads `calibration_method`, `complexity_priority`, and `ip_routing_policy`
3. For `HEX_SEED_DISTANCE` methods, fetches `hex_seed_distance_config` to get seed values and thresholds
4. Constructs request with appropriate DID signature and nonce
5. Submits to endpoint; server validates using calibration rules
6. Response includes updated anchor hex for chain continuity

### Secure Handoff Workflow

1. **Source node** creates entry in `secure_handoff_package`
2. Computes `seed_hex_source` and `seed_hex_dest` from node DID identities
3. Calculates `computed_distance` using specified metric
4. If distance ≤ threshold, initiates transfer
5. Updates `transfer_status` through lifecycle: PENDING → IN_TRANSIT → DELIVERED → VERIFIED
6. **Dest node** verifies `evidence_hex` and `roh_anchor_hex`, updates status to VERIFIED or FAILED

### IP Routing Table Usage

- Every node registers in `constellation_ip_routing` with stable `node_hex_identity`
- Routing policies consult `blast_radius_id` and `max_lane_allowed` to enforce governance
- Heartbeat mechanism updates `last_heartbeat_utc` and `online_status`
- Agents use `v_active_handoff_packages` to monitor active transfers

---

## SQL Query Examples

### Find all GOVERNANCE_QUERY endpoints with session-free mechanisms
```sql
SELECT 
    endpoint_name, 
    endpoint_pattern, 
    calibration_method, 
    session_free_mechanism
FROM api_endpoint_calibration
WHERE domain_category = 'GOVERNANCE_QUERY'
  AND uses_session_tokens = 0
  AND active = 1;
```

### Get hex seed configuration for HEALTH_CORRIDOR endpoints
```sql
SELECT 
    e.endpoint_name,
    h.seed_family,
    h.seed_hex_value,
    h.distance_metric,
    h.distance_threshold
FROM api_endpoint_calibration e
JOIN hex_seed_distance_config h ON e.endpoint_id = h.endpoint_id
WHERE e.domain_category = 'HEALTH_CORRIDOR'
  AND h.active = 1;
```

### List online nodes in Phoenix-AZ with PROD lane capability
```sql
SELECT 
    node_id,
    ipv4_address,
    routing_policy,
    blast_radius_id,
    last_heartbeat_utc
FROM constellation_ip_routing
WHERE region = 'Phoenix-AZ'
  AND max_lane_allowed = 'PROD'
  AND online_status = 1
  AND active = 1;
```

### Track in-transit secure handoff packages
```sql
SELECT 
    package_id,
    package_type,
    source_node_id,
    dest_node_id,
    computed_distance,
    created_utc,
    JULIANDAY('now') - JULIANDAY(created_utc) AS age_days
FROM secure_handoff_package
WHERE transfer_status = 'IN_TRANSIT'
  AND active = 1
ORDER BY created_utc DESC;
```

---

## Governance and Safety Invariants

### Non-Rollback Guarantee
- All tables use `active` flags instead of DELETE operations
- Provenance chains (`roh_anchor_hex`) are append-only
- No UPDATE allowed on `seed_hex_value`, `node_hex_identity`, or `evidence_hex`

### Lane Monotonicity
- Handoff packages for lane promotions must satisfy KER thresholds at both source and dest
- `max_lane_allowed` in IP routing table enforces hard limits

### Complexity Budgets
- Endpoints declare `max_complexity_score`
- Requests exceeding budget are rejected with `429 Too Complex` response
- Prevents resource exhaustion attacks

### DID Sovereignty
- Every package requires `signing_did`
- Signature verified against DID document before processing
- Failed verification → immediate reject, no partial processing

---

## Future Extensions

1. **Multi-metric seed distance:** Combine Hamming + Euclidean + graph-hop with learned weights
2. **Adaptive complexity throttling:** Adjust `max_complexity_score` based on node load
3. **Quantum-safe hex seeds:** Migrate to post-quantum hash functions for long-term security
4. **Cross-jurisdiction routing:** Explicit governance for packages crossing legal boundaries
5. **Automated endpoint discovery ALN:** Generate `api_endpoint_calibration` rows from ALN governance shards

---

## References

- `db_api_endpoint_calibration.sql` — SQL schema for this specification
- `Eco-Fort/db/ecosafetygrammarcore.sql` — Plane weights and KER definitions
- `Eco-Fort/db/dbblastradiusindex.sql` — Blast radius objects
- `Virta-Sys/db/dbvirtagovernedshardindex.sql` — Shard governance overlay

---

**Knowledge Factor:** 0.94 (directly extends existing EcoNet spine with minimal new concepts)  
**Eco-Impact:** 0.91 (enables session-free, low-energy API routing)  
**Risk-of-Harm:** 0.12 (complexity budget and DID verification reduce attack surface)
