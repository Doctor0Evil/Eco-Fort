<!-- filename: docmt6883continuity.md -->
<!-- destination: Eco-Fort/doc/docmt6883continuity.md -->

# MT6883 Continuity and Detox Governance

This document explains how MT6883 continuity checks in Virta-Sys interact with DetoxGuardKernel and the MT6883 healthcare QPU shards indexed in `qpushardcatalog`. It is written for AI-chat agents, coding agents, and maintainers who need to understand how to safely route, promote, and simulate MT6883 healthcare workloads without violating RoH, lane, or continuity invariants.

---

## 1. Surfaces involved

For MT6883 healthcare workloads there are four main surfaces to keep in mind:

1. **Spine tables (Eco-Fort)**  
   - `shardinstance`: canonical record of each shard, its lane, and KER metrics.  
   - `mt6883registry`: MT6883-aware registry over `shardinstance`, with RoH window, KER band, continuity grade, and optional `broid` for blastradius.  
   - `blastradiusobject`: spatial/temporal footprint for shards and nodes.

2. **QPU shard catalog (EcoNet / EcoNet-CEIM-PhoenixWater)**  
   - `qpushardcatalog`: index of QPU and healthcare shards, including MT6883 detox corridor and plan shards under `primaryplane = 'healthcare'` and `hardwarefamily = 'MT6883'`.

3. **Guard kernels (host / shared crates)**  
   - `DetoxGuardKernel`: evaluates detox episodes and courses using RoH, dose budgets, and interval constraints.  
   - Other guards such as `OrganicThermalInflammationGuard`, `LifeforceEnvelopeGuard`, and organ corridor guards.

4. **Virta-Sys governance (Virta-Sys)**  
   - Lane governor and topology auditor modules.  
   - `mt6883_lane_continuity.rs`: continuity module enforcing non-rollback and Lyapunov continuity before lane promotions for MT6883 workloads.  
   - `lanestatusverdict` and ALN LaneStatus shards as the durable lane verdict surface.

These pieces work together so that MT6883 detox workloads can be planned, simulated, and promoted without ever relaxing RoH 0.3, lane, or continuity invariants.

---

## 2. What `mt6883registry` encodes

The `mt6883registry` table in Eco-Fort is the spine-visible view of MT6883 healthcare and large-particle shards.

For each MT6883-related shard, it records:

- `shard_id`: foreign key into `shardinstance`.  
- `particle_name` and `schema_name`: the ALN identity of the shard (for example `nanoswarm.detox.corridor.v1`).  
- `category`: `HEALTHCARE` or `LARGEPARTICLE`.  
- `hardware_family` and `hardware_profile`: which MT6883 profile this shard expects.  
- `roh_valid_from` / `roh_valid_until` and `roh_chain_hex`: a Rule-of-History window and provenance chain.  
- `roh_risk`: normalized risk-of-harm in `[0,1]` for this shard’s current RoH assessment.  
- `ker_band`: `SAFE`, `GUARDED`, or `BLOCKED`, derived from K/E/R thresholds.  
- `safe_route_tag`: a coarse routing tag such as `NONTOXIC`, `RESTRICTED`, or `CRITICAL`.  
- `lane` and `continuity_grade`: the last known lane (e.g. `RESEARCH`, `EXPPROD`, `PROD`) and continuity classification (`A`, `B`, `C`) for the node or v-node hosting this workload.  
- `vt_residual_est`: a representative Lyapunov residual estimate in `[0,1]`.  
- Optional `broid`: link to `blastradiusobject` so continuity and lane governance can see spatial and temporal reach.

Ingest pipelines should keep `mt6883registry` up to date whenever a new MT6883 healthcare shard is ingested, when RoH or KER bands change, or when lane and blastradius verdicts are updated.

---

## 3. How DetoxGuardKernel fits in

DetoxGuardKernel is the guard that evaluates detox-related healthcare workloads, typically using:

- Per-episode snapshots (for example `DetoxCorridorSnapshot` built on top of `OrganicThermalInflammationSnapshot`), including detox dose, deployment type, and target corridor.  
- Course-level telemetry (for example `TreatmentCourseTelemetry`), including cumulative RoH, cumulative pain debt, cumulative eco-stress, detox dose accumulation, and daily budgets.  
- Rollback-latency and corridor polytopes that encode safe dose envelopes and enforced holidays.

Its responsibilities are:

- Reject or brake any detox episode that would breach RoH 0.3 or corridor constraints.  
- Enforce minimum spacing between detox episodes and daily dose budgets.  
- Mark courses as requiring holidays when cumulative RoH, pain debt, or eco-stress cross configured fractions of their safe budgets.  
- Provide guard verdicts that can be logged in shard-level telemetry and donutloop-style evolution logs.

DetoxGuardKernel operates at the host or QPU-guard level. It does not itself promote or demote lanes in the constellation; instead, it produces safe/unsafe decisions and guard metadata that other surfaces, including Virta-Sys, can read.

---

## 4. MT6883 continuity checks in Virta-Sys

The MT6883 continuity module in Virta-Sys (`mt6883_lane_continuity.rs`) enforces non-rollback and Lyapunov continuity using the shared spine.

For each MT6883 shard, Virta-Sys loads a continuity snapshot by joining:

- `mt6883registry`: current lane, KER band, continuity grade, RoH risk, and Lyapunov estimate.  
- `shardinstance`: historical `V_t` and lane history.  
- Optionally `blastradiusobject` via `broid` for spatial/temporal continuity decisions.

From this it constructs an `Mt6883ContinuitySnapshot` containing:

- `current_lane` and a requested `target_lane` (for example EXPPROD→PROD).  
- `ker_band` and `continuity_grade`.  
- `vt_prev` and `vt_new` estimates.  
- `roh_risk` (for additional policy checks if desired).

The continuity verdict function then enforces four invariants:

1. **Lane monotonicity**  
   A shard may move from RESEARCH→EXPPROD→PROD, but never back to a “lower” lane. EXPPROD→RESEARCH, PROD→EXPPROD, and PROD→RESEARCH are rejected.

2. **KER gating**  
   - For target lane `PROD` the KER band must be `SAFE`.  
   - For target lane `EXPPROD` the KER band must be `SAFE` or `GUARDED`.  
   - `RESEARCH` is permissive on KER band, but still governed by guard kernels and corridor constraints.

3. **Continuity grade**  
   For target lanes `EXPPROD` and `PROD`, the `continuity_grade` in `mt6883registry` must be `A` or `B`. Grade `C` indicates insufficient continuity for MT6883 healthcare workloads and causes the continuity check to fail.

4. **Lyapunov non-increase**  
   When both `vt_prev` and `vt_new` are available, the continuity module requires `V_t+1 ≤ V_t`. Any lane change that would increase the residual is rejected.

The verdict, along with the context, is written into `lanestatusverdict` (and mirrored as LaneStatus qpudatashards) so CI, ecological-orchestrator, and Paycomp can see a durable decision and rationale.

Virta-Sys does not actuate hardware or financial flows; it writes governance decisions that other components must respect.

---

## 5. How they interact on real workloads

For an MT6883 detox plan, the typical flow looks like this:

1. **Catalog and registry**  
   - EcoNet indexes the plan and its corridor shards in `qpushardcatalog` under `primaryplane = 'healthcare'`, `hardwarefamily = 'MT6883'`, and detox-specific VFS opcodes such as `VOPDETOXSCHEDULE` or `VOPEXECUTEDETOXPLAN`.  
   - Eco-Fort updates `shardinstance` and `mt6883registry` rows for these shards, including KER bands, continuity grades, RoH windows, and `broid` where applicable.

2. **Guard evaluation (DetoxGuardKernel)**  
   - When a detox episode or plan is proposed, host or QPU guard code calls DetoxGuardKernel (and the other guard kernels) with the appropriate telemetry snapshots.  
   - DetoxGuardKernel enforces RoH, dose budgets, and holiday rules and returns a safe/unsafe verdict plus telemetry updates.

3. **Lane promotion request**  
   - If a detox workload is considered mature enough (for example for a particular cohort and region) an agent or orchestrator may propose promoting its lane from RESEARCH to EXPPROD, or from EXPPROD to PROD.  
   - This proposal is represented as a target lane for the corresponding shard(s).

4. **MT6883 continuity check in Virta-Sys**  
   - Virta-Sys constructs an `Mt6883ContinuitySnapshot` from `mt6883registry` and `shardinstance` and runs the continuity evaluation.  
   - If any of the invariants are violated (non-monotone lane change, insufficient KER band, continuity grade C, or Lyapunov increase), the request is rejected and a `lanestatusverdict` row is written with the reason.  
   - If all invariants hold, the continuity check returns `Approved` and Virta-Sys records this in `lanestatusverdict`.

5. **Final lane change and scheduling**  
   - CI and ecological-orchestrator check `lanestatusverdict` before applying any lane change or scheduling PROD workloads.  
   - They also ensure that DetoxGuardKernel and the other guard kernels remain in the loop for live execution, so that even PROD workloads still obey RoH and corridor constraints at runtime.

The key point is that DetoxGuardKernel and MT6883 continuity checks address different layers:

- DetoxGuardKernel operates at the episode and course level, ensuring that each detox action and course stays inside RoH, dose, and holiday envelopes.  
- MT6883 continuity checks operate at the lane governance level, ensuring that the constellation only grants higher trust lanes to MT6883 workloads whose KER bands, continuity grades, and Lyapunov trajectories are compatible with EXPPROD and PROD.

Together they prevent both unsafe episodes and unsafe lane evolution.

---

## 6. Guidance for agents and coding tools

When generating code or new files that touch MT6883 detox workloads, agents should:

1. **Use `qpushardcatalog` to find shards**  
   - Filter by `primaryplane = 'healthcare'`, `hardwarefamily = 'MT6883'`, and the appropriate detox VFS opcodes.  
   - Use these catalog entries to determine filenames, paths, and versions for new shards.

2. **Respect `mt6883registry` before proposing lane changes**  
   - Read `ker_band`, `continuity_grade`, `roh_risk`, and `vt_residual_est` for the relevant shards.  
   - Do not propose promoting a shard to EXPPROD or PROD if its KER band is `BLOCKED` or its continuity grade is `C`.

3. **Call MT6883 continuity logic via Virta-Sys**  
   - For any MT6883 lane promotion, instruct Virta-Sys to run its continuity check and wait for an `Approved` verdict in `lanestatusverdict` before treating the lane change as real.  
   - Never bypass Virta-Sys continuity logic when routing MT6883 workloads.

4. **Keep DetoxGuardKernel in the execution loop**  
   - Ensure any runtime execution path for detox workloads continues to call DetoxGuardKernel (and the other guard kernels) before applying detox actions, regardless of lane.  
   - Treat guard verdicts as hard gates for scheduling and parameter selection.

By following these rules, agents and tools can generate new code and shards that participate in MT6883 healthcare detox workloads while preserving the non-rollback and continuity guarantees encoded in the constellation spine.

---
