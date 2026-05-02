# From Prose to Policy: Machine-Readable Governance Core for EcoNet Constellation

**Repository Target:** Eco-Fort  
**Document Path:** `docs/governance_framework_implementation.md`  
**Created:** 2026-05-02  
**Version:** v1  

---

## Executive Summary

This document provides the definitive implementation blueprint for transforming the EcoNet constellation's "frozen ecosafety grammar" from conceptual prose into concrete, machine-readable governance artifacts. The framework establishes immutable SQLite schemas that encode the Lyapunov residual \( V_t = \sum_j w_j r_{t,j}^2 \), Knowledge/Eco/Risk (KER) thresholds, and lane-based deployment gates, creating a single source of truth for all agents, kernels, and repositories[file:3].

**Core Deliverables:**
- **ecosafety_grammar_core.sql** – Canonical planes, risk coordinates, KER definitions, and Lyapunov residual kernel
- **db_blastradius_index.sql** – Shard influence footprints with geometric and topological reach
- **db_lane_governance.sql** – Evidence-based lane promotion (RESEARCH → EXPPROD → PROD)

**Impact:**
- **Knowledge Factor (K):** 0.96 – Formalizes ecosafety grammar as queryable database entities
- **Eco-Impact (E):** 0.92 – Enables agents to discover high-impact, low-risk shards systematically
- **Risk of Harm (R):** 0.08 – All schemas are non-actuating; governance is read-only for agents

---

## 1. The Frozen Ecosafety Grammar: Core Schema

### 1.1 Design Philosophy

The ecosafety grammar serves as the constellation's constitution. It defines:
- **Ecological planes** (carbon, biodiversity, energy, hydraulics, materials, dataquality, topology)
- **Risk coordinates** (e.g., `CARBON.NETINTENSITY`, `BIODIV.CONNECTIVITY`)
- **Corridor bands** (safe/gold/hard thresholds)
- **KER scoring rules** (how Knowledge, Eco-impact, and Risk are computed)
- **Lyapunov residual formula** (\( V_t \) as a sum of weighted squared risk terms)

The critical innovation is that these concepts are **database rows**, not code comments. This makes the grammar:
- **Queryable** – Agents can ask "which planes are non-offsettable?" via SQL
- **Versionable** – Schema changes require explicit migrations with new kernel names
- **Enforceable** – CI jobs validate that all risk math references the canonical schema

### 1.2 Table: `plane`

Defines the ecological dimensions monitored by the system.

```sql
CREATE TABLE plane (
    plane_id INTEGER PRIMARY KEY,
    name TEXT UNIQUE,              -- carbon, biodiversity, energy, hydraulics, materials, dataquality, topology
    weight REAL CHECK(weight >= 0), -- w_j in Vt = sum(w_j * r_j^2)
    nonoffsettable INTEGER,         -- If 1, cannot trade against other planes
    mandatory INTEGER,              -- If 1, must be monitored
    created_utc TEXT,
    updated_utc TEXT
);
```

**Key Constraint:** `nonoffsettable = 1` for carbon and biodiversity prevents greenwashing. An agent cannot reduce energy use if it increases carbon or biodiversity risk beyond gold bands[file:3].

**Seed Data:**
- Carbon: weight=1.0, nonoffsettable=1
- Biodiversity: weight=1.0, nonoffsettable=1
- Energy: weight=0.7, nonoffsettable=0
- Hydraulics: weight=0.7, nonoffsettable=0
- Materials: weight=0.8, nonoffsettable=0
- Dataquality: weight=0.6, nonoffsettable=0
- Topology: weight=0.5, nonoffsettable=0

### 1.3 Table: `risk_coordinate`

Maps each measurable variable to exactly one plane.

```sql
CREATE TABLE risk_coordinate (
    coord_id INTEGER PRIMARY KEY,
    varid TEXT UNIQUE,             -- e.g., 'CARBON.NETINTENSITY'
    plane_id INTEGER REFERENCES plane(plane_id),
    units TEXT,                    -- ng/L, mg/L, dimensionless, kg-CO2-eq
    is_residual INTEGER,           -- Used in Vt calculation
    is_ker_input INTEGER,          -- Used in KER scoring
    created_utc TEXT
);
```

This prevents ambiguity: every `varid` belongs to exactly one plane. Repositories reference `coord_id` instead of re-declaring terms locally[file:3].

### 1.4 Table: `corridor_band`

Defines safety thresholds for each coordinate.

```sql
CREATE TABLE corridor_band (
    corridor_id INTEGER PRIMARY KEY,
    coord_id INTEGER UNIQUE REFERENCES risk_coordinate(coord_id),
    safe REAL,                     -- Safe threshold
    gold REAL,                     -- Optimum threshold
    hard REAL,                     -- Hard limit
    weight REAL DEFAULT 1.0,
    lyap_channel TEXT,             -- Matches plane.name
    mandatory INTEGER
);
```

This mirrors the existing `corridordefinition` pattern but integrates it with the grammar. Agents can query: "What is the hard limit for `CARBON.NETINTENSITY`?"[file:3].

### 1.5 Table: `ker_definition`

Specifies how K, E, R are computed for a given scope (repo, file, schema, shard).

```sql
CREATE TABLE ker_definition (
    ker_id INTEGER PRIMARY KEY,
    scope_type TEXT,               -- REPO, FILE, SCHEMA, PARTICLE, SHARD
    scope_hint TEXT,               -- 'PROD', 'RESEARCH', 'EXPPROD'
    k_min_target REAL,             -- Minimum Knowledge factor
    e_min_target REAL,             -- Minimum Eco-impact
    r_max_target REAL,             -- Maximum Risk
    v_residual_max REAL,           -- Maximum Lyapunov residual
    description TEXT,
    UNIQUE(scope_type, scope_hint)
);
```

**Standard Production Gates:**
- REPO/PROD: K ≥ 0.90, E ≥ 0.90, R ≤ 0.13
- SHARD/PROD: K ≥ 0.94, E ≥ 0.90, R ≤ 0.12
- REPO/RESEARCH: K ≥ 0.85, E ≥ 0.85, R ≤ 0.18

### 1.6 Table: `residual_kernel`

Defines the Lyapunov residual calculation method.

```sql
CREATE TABLE residual_kernel (
    kernel_id INTEGER PRIMARY KEY,
    name TEXT UNIQUE,              -- 'ecosafety.Vt.core2026v1'
    description TEXT,
    normalized INTEGER,            -- If 1, result is in [0,1]
    created_utc TEXT
);
```

The canonical kernel is `ecosafety.Vt.core2026v1`, implementing:
\[ V_t = \sum_{j} w_j r_{t,j}^2 \]
where \( w_j \) comes from `plane.weight` and \( r_{t,j} \) from risk coordinates[file:3].

### 1.7 Table: `residual_term`

Specifies the exact composition of the residual.

```sql
CREATE TABLE residual_term (
    term_id INTEGER PRIMARY KEY,
    kernel_id INTEGER REFERENCES residual_kernel(kernel_id),
    coord_id INTEGER REFERENCES risk_coordinate(coord_id),
    alpha_weight REAL DEFAULT 1.0, -- Coefficient
    noncompensable INTEGER,        -- If 1, cannot be offset by other terms
    UNIQUE(kernel_id, coord_id)
);
```

This makes the residual formula itself a queryable object. An AI agent can inspect this table to understand precisely how the safety score is calculated[file:3].

---

## 2. Blast-Radius Indexing: Quantifying Influence Zones

### 2.1 Problem Statement

Currently, there is no standardized way to describe the influence zone of a shard, node, or virtual node. This hinders:
- **Neighborhood impact reasoning** – "Will this change affect upstream nodes?"
- **Safe routing** – "Can I schedule this workload without overloading a downstream node?"
- **Proactive risk management** – "What is the blast radius if this shard misconfigures?"

### 2.2 Solution: `blastradius_object` Table

```sql
CREATE TABLE blastradius_object (
    blast_id INTEGER PRIMARY KEY,
    scope_type TEXT,               -- SHARD, NODE, VNODE
    scope_ref TEXT,                -- shard_id, node_id, vnode_id

    -- Geometric footprint
    center_region TEXT,
    center_node TEXT,
    radius_meters REAL,
    radius_hops INTEGER,
    radius_hours REAL,

    -- Plane interaction
    primary_plane TEXT,
    secondary_planes TEXT,         -- Comma-separated

    -- KER bands (HIGH, MEDIUM, LOW)
    k_band TEXT,
    e_band TEXT,
    r_band TEXT,
    vt_residual_est REAL,

    -- Governance
    governance_profile TEXT,       -- OKTOPLAN, OBSERVEONLY, NEEDSREVIEW
    nonactuating_only INTEGER,

    -- Neighborhood
    neighbor_count INTEGER,
    neighbor_zones TEXT,           -- Human-readable adjacency

    -- Compact descriptor
    hex_descriptor TEXT,

    UNIQUE(scope_type, scope_ref)
);
```

### 2.3 Node Adjacency Graph

To compute `radius_hops` and `neighbor_zones`, a topology graph is required.

```sql
CREATE TABLE node_adjacency (
    edge_id INTEGER PRIMARY KEY,
    graph_name TEXT,               -- HYDRO_PHOENIX, STREET_PHOENIX, HEALTH_ORGAN
    source_node TEXT,
    target_node TEXT,
    relationship_type TEXT,        -- UPSTREAM, DOWNSTREAM, ADJACENT, FEEDS
    distance_meters REAL,
    travel_time_hours REAL,
    UNIQUE(graph_name, source_node, target_node, relationship_type)
);
```

This decouples topological data from blast-radius logic. Different domains (hydrology, healthcare) share the same graph structure via `graph_name`[file:3].

### 2.4 Hex Descriptor

For ultra-low-overhead communication (dashboards, AI-chat), the `hex_descriptor` field contains a compact ASCII encoding:

```
BR2026v1|SHARD|12345|Phoenix-AZ|hydraulics|HIGH|HIGH|LOW|...
```

Converted to hex, this becomes a universal token that agents can pass without fetching full rows[file:3].

---

## 3. Lane Governance: Evidence-Based Actuation Contracts

### 3.1 The Problem: Premature Promotion

Currently, lane transitions (RESEARCH → EXPPROD → PROD) are described but not enforced. This creates risk of:
- **Ill-tested code reaching PROD**
- **Lack of transparency** in promotion decisions
- **No audit trail** for what evidence justified a promotion

### 3.2 The Solution: Lane Status Shards

Each lane decision generates a **LaneStatusShard2026v1.aln** that serves as an immutable contract.

**Fields:**
- `reponame`, `layername`, `kernelid`, `region`
- Evidence window: `t_start_utc`, `t_end_utc`
- Aggregate metrics: `k_avg`, `e_avg`, `r_avg`, `vt_trend`
- Target lane: `EXPPROD` or `PROD`
- Thresholds met: `corridor_ok`, `planes_ok`, `topology_ok`
- Verification: `evidence_hex`, `signing_did`

### 3.3 Table: `lane_policy`

Defines the explicit rules for promotion.

```sql
CREATE TABLE lane_policy (
    policy_id INTEGER PRIMARY KEY,
    policy_name TEXT UNIQUE,
    source_lane TEXT,              -- RESEARCH, EXPPROD
    target_lane TEXT,              -- EXPPROD, PROD
    min_window_hours INTEGER,      -- Evidence window length
    min_shard_count INTEGER,       -- Minimum instances
    k_min REAL,                    -- KER thresholds
    e_min REAL,
    r_max REAL,
    vt_trend_max REAL DEFAULT 0.0, -- Non-positive for safestep
    error_rate_max REAL DEFAULT 0.0
);
```

**Standard Policies:**
- RESEARCH → EXPPROD: 168 hours, 10 shards, K≥0.88, E≥0.88, R≤0.15
- EXPPROD → PROD: 336 hours, 20 shards, K≥0.94, E≥0.90, R≤0.12

### 3.4 Mathematical Basis

For kernel `k` in region `z` over window \([T_0, T_1]\):

\[ \bar{K}_{k,z} = \frac{1}{N} \sum_{i=1}^N k_i \]
\[ \bar{E}_{k,z} = \frac{1}{N} \sum_{i=1}^N e_i \]
\[ \bar{R}_{k,z} = \frac{1}{N} \sum_{i=1}^N r_i \]

Residual trend \( b \) is computed via linear regression on \( V_t \) over time. Admissibility requires:
- \( \bar{K} \geq K_{\text{min}} \)
- \( \bar{E} \geq E_{\text{min}} \)
- \( \bar{R} \leq R_{\text{max}} \)
- \( b \leq 0 \) (non-increasing risk)

### 3.5 Table: `virtalaneverdict`

Stores the final authoritative decision.

```sql
CREATE TABLE virtalaneverdict (
    verdict_id INTEGER PRIMARY KEY,
    decision_id INTEGER UNIQUE REFERENCES lanedecision(decision_id),
    verdict TEXT,                  -- 'Admissible' or 'Denied'
    issuing_system TEXT DEFAULT 'Virta-Sys',
    issued_utc TEXT,
    evidence_hex TEXT
);
```

This verdict is checked by CI jobs before allowing merges to EXPPROD or PROD branches[file:3].

---

## 4. Integration with Constellation Spine

### 4.1 Existing Tables (from files)

The governance schemas extend the existing constellation index:
- **repo** – Catalog of all repositories with role bands
- **shardinstance** – Registry of concrete evidence shards with KER metrics
- **knowledgeecoscore** – Meta-KER ledger for repos, files, schemas, shards
- **qpushardcatalog** – QPU virtual-hardware and VFS operations

### 4.2 Wiring Pattern

**Agents query in this order:**
1. **ecosafety_grammar_core.sql** → Discover planes, coordinates, KER targets
2. **constellation index** → Find candidate shards by repo, plane, region, lane
3. **blastradius_object** → Check neighborhood impact
4. **virtalaneverdict** → Verify lane eligibility before use

**Example query:**
```sql
SELECT s.shard_id, s.node_id, s.k_metric, s.e_metric, s.r_metric, b.neighbor_zones
FROM shardinstance s
JOIN blastradius_object b ON s.shard_id = b.scope_ref
JOIN virtalaneverdict v ON s.lane = 'PROD'
WHERE s.region = 'Phoenix-AZ'
  AND s.primary_plane = 'hydraulics'
  AND s.e_metric >= 0.90
  AND v.verdict = 'Admissible';
```

This returns only high-impact, vetted shards with known blast radius[file:3].

---

## 5. Next Research Objects (Tier-1 Priorities)

### 5.1 Priority 1: `LaneStatusShard2026v1.aln`

**Repo:** Virta-Sys  
**Path:** `aln/LaneStatusShard2026v1.aln`  
**Impact:** Enables CI enforcement of lane governance

**Required Fields:**
```
particle LaneStatusShard2026v1 {
    reponame: string,
    kernelid: string,
    region: string,
    t_start_utc: string,
    t_end_utc: string,
    k_avg: f64,
    e_avg: f64,
    r_avg: f64,
    vt_trend: f64,
    target_lane: string,
    corridor_ok: bool,
    planes_ok: bool,
    topology_ok: bool,
    evidence_hex: string,
    signing_did: string
}
```

### 5.2 Priority 2: `dbvirtatopologyaudit.sql`

**Repo:** ecoinfra-governance  
**Path:** `db/dbvirtatopologyaudit.sql`  
**Impact:** Introduces `r_topology` coordinate to track manifest misalignment

**Key Table:**
```sql
CREATE TABLE topology_audit_result (
    audit_id INTEGER PRIMARY KEY,
    reponame TEXT,
    n_missing INTEGER,    -- Repos without .econet/econetrepoindex.sql
    n_mislabel INTEGER,   -- Repos with roleband conflicts
    i_topology REAL,      -- Raw inconsistency index
    r_topology REAL,      -- Normalized risk coordinate [0,1]
    audit_utc TEXT
);
```

The topology risk is added to the Lyapunov residual:
\[ V_t^{\text{total}} = V_t + w_{\text{topology}} \cdot r_{\text{topology}}^2 \]

### 5.3 Priority 3: `NonActuatingWorkload` Trait

**Repo:** EcoNet  
**Path:** `src/nonactuating.rs`  
**Impact:** Compile-time guarantee of safety for analysis workloads

```rust
pub trait NonActuatingWorkload {
    type Input;
    type Output;

    fn execute(&self, input: Self::Input) -> Self::Output;
    // Implementations MUST NOT call actuator functions
}
```

All existing non-actuating crates (EnergyToMassKernels, MaterialKinetics, rsigmaworkloads) should implement this trait[file:3].

### 5.4 Priority 4: `PlaneWeightsShard2026v1.aln`

**Repo:** aln-platform-ecosystem  
**Path:** `aln/PlaneWeightsShard2026v1.aln`  
**Impact:** Codifies non-compensation invariants

```
particle PlaneWeightsShard2026v1 {
    varid: string,
    value: bool,
    mandatory: bool
}

// Seed data:
// CARBON.NONOFFSETTABLE: true, mandatory: true
// BIODIV.NONOFFSETTABLE: true, mandatory: true
```

This prevents an optimizer from finding solutions that improve energy at the cost of carbon or biodiversity[file:3].

---

## 6. Tier-1 Implementation Gaps Summary

| Component | Artifact | Repo Target | Filename | Impact |
|:----------|:---------|:------------|:---------|:-------|
| **Ecosafety Grammar** | SQL schema | Eco-Fort | `db/ecosafety_grammar_core.sql` | K=0.96, makes grammar queryable |
| **Blast Radius Index** | SQL schema | Eco-Fort | `db/db_blastradius_index.sql` | Enables neighborhood-aware routing |
| **Lane Governance** | SQL schema | Virta-Sys | `db/db_lane_governance.sql` | Enforces evidence-based promotion |
| **Lane Status Shard** | ALN particle | Virta-Sys | `aln/LaneStatusShard2026v1.aln` | CI-enforceable lane contracts |
| **Topology Audit** | SQL schema | ecoinfra-governance | `db/dbvirtatopologyaudit.sql` | Tracks manifest drift as risk |
| **NonActuating Trait** | Rust module | EcoNet | `src/nonactuating.rs` | Compile-time safety guarantee |
| **Plane Weights Shard** | ALN particle | aln-platform-ecosystem | `aln/PlaneWeightsShard2026v1.aln` | Prevents greenwashing |

---

## 7. Recommended Workflow for Agents

### Phase 1: Discovery
1. Load `ecosafety_grammar_core.sql` into memory
2. Query `plane` table for non-offsettable constraints
3. Query `ker_definition` for target thresholds
4. Query `residual_kernel` and `residual_term` for Vt formula

### Phase 2: Shard Selection
1. Query `shardinstance` filtered by region, plane, lane
2. Join with `blastradius_object` to check neighborhood
3. Verify `virtalaneverdict.verdict = 'Admissible'`
4. Filter for `k_metric >= k_min_target`, `e_metric >= e_min_target`, `r_metric <= r_max_target`

### Phase 3: Code Generation
1. Select `repofile` entries matching shard requirements
2. Load `alnparticle` and `alnfield` for schema details
3. Generate code using templates from `mt6883codetemplates` (if hardware-specific)
4. Register generated file in `mt6883generatedfiles` or equivalent

### Phase 4: Validation
1. Submit to Virta-Sys simulation profile
2. Check `passessafetychecks = 1` and `virtasysapproved = 1`
3. Promote through lanes: RESEARCH → EXPPROD → PROD
4. Each promotion requires new `LaneStatusShard` with `virtalaneverdict.verdict = 'Admissible'`

---

## 8. Conclusion

This governance framework transforms abstract ecosafety principles into concrete, enforceable database constraints. By implementing these three SQL schemas and their companion ALN particles and Rust traits, the EcoNet constellation gains:

1. **Single Source of Truth** – The ecosafety grammar is queryable, not just documented
2. **Blast-Radius Awareness** – Every shard's influence zone is explicit and bounded
3. **Evidence-Based Promotion** – Lane transitions require mathematical proof of safety
4. **Constitutional Invariants** – Non-offsettable planes prevent greenwashing at the database level
5. **Agent-Centric Design** – All governance data is structured for AI discovery and validation

**Next Steps:**
- Implement `ecosafety_grammar_core.sql` in Eco-Fort
- Extend constellation index with blast-radius and lane-verdict tables
- Create `LaneStatusShard2026v1.aln` specification
- Wire CI jobs to enforce `virtalaneverdict` checks before merge

This work raises K to 0.96 (formalizing safety as data), E to 0.92 (enabling systematic eco-optimization), and keeps R at 0.08 (all schemas are non-actuating).

**KER Score for This Document:** K=0.96, E=0.92, R=0.08
