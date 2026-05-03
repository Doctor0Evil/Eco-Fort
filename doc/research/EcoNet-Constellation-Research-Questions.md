# Review-Output: 50 High-Impact Research Questions, Definition Requests, Detail Queries, and Objection Identifiers

**Filename:** `EcoNet-Constellation-Research-Questions.md`  
**Destination:** `Eco-Fort/doc/research/EcoNet-Constellation-Research-Questions.md`  
(Also mirrorable in `EcoNet/docs/research/` for developer visibility)

---

This document provides **50 targeted inquiries** across four categories to advance the EcoNet constellation toward **production readiness, code quality, AI-chat compatibility, and governance integrity**. Each item is designed to sharpen the current design, close gaps, and pre‑empt objections before they become blockers.

---

## 1. Research Questions (Future Direction & Scientific Rigor)

1. **RQ‑1** – How can the Lyapunov residual `V_t = Σ w_j r_{t,j}^2` be made **computable entirely within SQLite** without losing floating‑point precision or requiring external math libraries, so that lane verdicts can be evaluated directly in the database by any agent?  
2. **RQ‑2** – What additional topology penalty functions (beyond `rtopology`) are needed to capture **network‑level energy waste** when multiple non‑actuating workloads run in parallel on shared infrastructure?  
3. **RQ‑3** – How can the concept of **“canal velocity”** (propagation speed of an eco‑impact) be formalized as a first‑class coordinate in the Lyapunov vector, and how would it interact with the existing plane weights?  
4. **RQ‑4** – What is the optimal chunk size and hash strategy for `largeparticlefile` to **balance energy cost, token cost, and integrity checking** across heterogeneous AI agents and CI pipelines?  
5. **RQ‑5** – How can MT6883 continuity grades (A, B, C) be **derived automatically** from node adjacency graphs and blast‑radius overlaps, removing the need for manual classification?  
6. **RQ‑6** – What cryptographic commitment scheme (e.g., Merkle trees over provenance chains) would allow a **lightweight agent to verify** that an artifact has never been rolled back without downloading the entire `artifactprovenance` table?  
7. **RQ‑7** – Under what conditions could a **temporary lane downgrade** (e.g., PROD → EXPPROD) be mathematically safe if accompanied by a simultaneous reduction in `V_t` and improvement in continuity grade, thus challenging the strict monotonicity rule?  
8. **RQ‑8** – How can the ecosafety grammar absorb **emergent planes** (e.g., microbiome, noise pollution) without breaking the “frozen” nature of the core grammar tables while allowing extensions?  
9. **RQ‑9** – What is the minimum set of `knowledgeecoscore` time‑window aggregations needed to produce a **non‑gameable reward signal** for ecological‑orchestrator, and how do they relate to lane‑specific KER thresholds?  
10. **RQ‑10** – In a smart‑city setting, how can **real‑time telemetry from IoT sensors** be federated into `shardinstance` rows without flooding the spine and violating Lyapunov monotonicity constraints over short timescales?

---

## 2. Definition Requests (Precise Semantics for Code & Agents)

11. **DR‑1** – Provide a **formal definition** of “sovereign wiring” within the constellation: what exact constraints on row ownership, DID signatures, and cross‑repo references must hold for a wiring to be considered sovereign?  
12. **DR‑2** – Define **“energy lane”** with a mathematical specification: is it an ordinal ranking of power budgets, a set of QoS tags like `LOWPOWER`/`BALANCED`, or a continuous cost function?  
13. **DR‑3** – Clarify the exact **hex‑encoding format** for `hexdescriptor` in `blastradiusobject` – specify its byte‑layout, field ordering, and endianness so that all agents produce and parse it identically.  
14. **DR‑4** – Define the **contractual meaning of “non‑actuating workload”** (the `NonActuatingWorkload` trait) – what counts as a side‑effect? Must implementations be purely functional, or is logging and telemetry emission permissible?  
15. **DR‑5** – What constitutes a **“smart‑city routine”** as a distinct artifact kind? Provide an exhaustive list of planes, lane restrictions, and VFS opcodes that apply to such routines.  
16. **DR‑6** – Define the **transition graph of artifact lifecycle states** (BUILD → RESEARCH → EXPPROD → PROD → SUPERSEDED) with explicit guard conditions and allowed provenance events.  
17. **DR‑7** – Precisely define the **difference between `kerdeployable` in `shardinstance` and `kerband` in `artifactregistry`** – when can they disagree, and which one takes precedence?  
18. **DR‑8** – Provide a **specification of the “Rule‑of‑History” contract** (`rohanchorhex`) – what fields must be included, how are they hashed, and what constitutes a valid RoH chain of custody for MT6883 healthcare shards?  
19. **DR‑9** – Define the **semantic relationship between `primaryplane` and the set of `corridordefinition` entries** – must every corridor variable belong to exactly one primary plane, or can it influence multiple planes?  
20. **DR‑10** – What is the **exact algorithmic contract for `checksafestep`**? Detail the inequality checks, the handling of missing data, and the tie‑breaking logic when `V_{t+1} == V_t`.

---

## 3. Detail Queries (Implementation Gaps & Verification)

21. **DQ‑1** – Where in the Rust codebase is the **`LyapunovResidual` struct** actually computed from `RiskVector` and plane weights? Provide the file path and ensure it is the single source of truth imported by Virta‑Sys and Eco‑Fort.  
22. **DQ‑2** – The `shard-indexer-ci.yml` workflow is described as “sovereign, offline‑lean” – **what prevents it from accidentally opening a network socket** during a run? Provide the exact `cargo` arguments and container isolation guarantees.  
23. **DQ‑3** – The `mt6883_lane_continuity.rs` module writes to a `lanestatusverdict` table – **does that table already exist** in the Eco‑Fort schema, or must it be created as part of the same migration? Show the full DDL.  
24. **DQ‑4** – How is the **`contenthash` in `artifactregistry` computed** for different artifact kinds (binary, ALN, SQL, CSV)? Provide the hashing algorithm, canonical byte serialization, and inclusion of metadata (like file headers).  
25. **DQ‑5** – The `artifactprovenance` table includes `rtopology` and `wtopology` – **which component writes these values** and how are they derived from the `topologyauditrun` and `repofile` presence checks?  
26. **DQ‑6** – When a large particle file’s hash strategy is `SAMPLEBLOCKS`, **which specific blocks are hashed** and how are they indexed in `largeparticleblock`? Provide a query that selects exactly those blocks for a given file.  
27. **DQ‑7** – In the QPU shard catalog, the `nonactuatingrequired` flag is present – **what enforces it at the VFS layer**? Show the Rust trait bounds or CI checks that prevent a non‑actuating‑required shard from executing an actuating opcode.  
28. **DQ‑8** – The ALN invariant `lane.governance.v1.aln` is sketched – **what is its exact ALN expression**? Write it in ALN syntax such that an ALN‑capable parser can verify lane monotonicity over `lanestatusverdict`.  
29. **DQ‑9** – The `artifact_registry_core.rs` module returns `Option<ProvenanceRecord>` for latest provenance – **how does a consumer (e.g., ecological‑orchestrator) determine that a provenance chain is complete** (i.e., no missing CI runs) without an explicit chain validation function?  
30. **DQ‑10** – The current README states that `PlaneWeightsShard2026v1.aln` should make weights data‑driven – **give the exact ALN record schema for this shard** so that it can be implemented without ambiguity.  
31. **DQ‑11** – The large particle file registry includes `chunksizebytes` and `chunkrowtarget` – **which one takes precedence** if both are present but inconsistent, and how does the streaming IO handle the mismatch?  
32. **DQ‑12** – In the `mt6883registry` schema, `roh_risk` is a float – **what is the unit and range normalization**? Is it directly comparable to the KER `R` metric, and if not, how is it mapped to `rmetric`?  
33. **DQ‑13** – The blast‑radius `hexdescriptor` is said to be a fixed‑order ASCII string turned into hex – **provide the exact order of fields** and their fixed widths so that any agent can reproduce it.  
34. **DQ‑14** – The `ecorewardfamily` and `hostrewardprofile` tables are mentioned but not detailed – **give their SQL schema** and the rules for mapping `knowledgeecoscore` rows to `ecorewardevent` distributions.  
35. **DQ‑15** – For the GitHub Actions workflow, the caching of `cargo` registry and `target/` is aimed at energy saving – **measure the expected energy reduction** (in watts or CO2‑equivalent) versus a non‑cached run, and provide the methodology.

---

## 4. Objection Identifiers (Pre‑mortem Risks & Counters)

36. **OI‑1** – **Risk of Byzantine DID spoofing** – If a signing DID is compromised, an attacker could inject false provenance. How does the constellation detect and recover from a compromised DID without allowing unauthorized lane promotions?  
37. **OI‑2** – **Immutable evidence vs. right‑to‑be‑forgotten** – For MT6883 healthcare data, immutable public evidence may conflict with GDPR/neurorights. How can the system provide privacy‑preserving proofs of correct handling without exposing raw data?  
38. **OI‑3** – **Lane monotonicity as a rigidity** – Could the absolute ban on lane downgrades prevent emergency rollback of a PROD kernel that suddenly becomes unsafe? Propose a governance‑approved circuit breaker that does not violate the sovereignty model.  
39. **OI‑4** – **Scaling of the artifact registry** – A single SQLite database per Eco‑Fort may not scale to millions of artifacts. How would the spine support sharding or federation without losing non‑rollback guarantees?  
40. **OI‑5** – **Dependency on a single constellation DB** – If Eco‑Fort’s `constellation.db` becomes unavailable, all lane decisions halt. What is the failover strategy and how can Virta‑Sys continue to serve safe‑stationary policies in offline mode?  
41. **OI‑6** – **Plane weight calibration** – The current Lyapunov model assumes fixed weights; if weights are later changed via `planeweightscontract`, previously approved PROD shards could retroactively become unsafe. How is backward safety ensured when weights evolve?  
42. **OI‑7** – **Large particle streaming cost** – Agents instructed to use summaries may still inadvertently stream raw files, consuming tokens. How does the system enforce that agents respect `summarylevel` and `chunkrowtarget`?  
43. **OI‑8** – **Non‑actuating workloads acting as timers** – Even purely computational workloads can influence real‑world timing (e.g., delaying sensor reads). Does this count as actuation, and if so, how is it prevented?  
44. **OI‑9** – **Evidence hex redundancy** – The same evidence may be stored in `shardinstance`, `artifactregistry`, and `artifactprovenance`; how is consistency maintained across these tables, and what prevents a mismatch from causing false downstream decisions?  
45. **OI‑10** – **Complexity of the frozen grammar** – With dozens of tables and ALN shards, a new developer may find it impossible to navigate. What is the “on‑boarding path” and minimal working example (MWE) that demonstrates the full lifecycle of one artifact?  
46. **OI‑11** – **Hardware‑specific assumptions** – The MT6883 registry assumes Cortex‑A77‑MT6883 chips; how extensible is it to other healthcare‑grade SoCs, and what would break if a new chip family does not support the same continuity contracts?  
47. **OI‑12** – **Token‑cost reduction vs. accuracy** – Relying on precomputed summaries may hide slow degradation of eco‑state if the summaries are stale. How is the freshness of summaries enforced, and what is the maximum tolerated lag before a lane promotion becomes invalid?  
48. **OI‑13** – **CI workflow as single point of provenance** – If the `shard-indexer-ci.yml` fails, the artifact registry may become stale. How can multiple, redundant indexer authorities coexist without conflicting over the same artifact rows?  
49. **OI‑14** – **ALN version fragmentation** – Multiple ALN schema versions (e.g., `2026v1`) may evolve in parallel; what versioning and deprecation policy ensures that a newer schema can still validate evidence produced under an older one?  
50. **OI‑15** – **Missing coordinate for “trust”** – The current KER model treats K (knowledge) as a function of evidence quality, but does not model the trustworthiness of the DID signing the evidence. Should trust be a separate plane, and if so, how is it folded into `V_t`?

---

*This set of inquiries is intended to function as a **living roadmap**: answering them will produce concrete schema extensions, Rust crates, ALN invariants, and documentation shards that directly improve code quality, AI‑chat compatibility, and sovereign governance readiness.*
