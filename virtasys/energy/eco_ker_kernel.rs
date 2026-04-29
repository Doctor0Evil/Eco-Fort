// virtasys/energy/eco_ker_kernel.rs
//
// KER-scored energy kernel around RhythmOrchestrator.
// This crate stays Rust-only, no external invasive components, and
// is designed to be reusable across eco-restoration workloads.
//
// It wraps RhythmDecision batches with:
// - KnowledgeFactor: how corridor-backed and measured the decision is
// - EcoImpact: normalized energy saved vs. a corridor
// - RiskOfHarm: risk coordinates over power, temperature, and utilization
//
// All scores are 0.0..=1.0, with V_t residual used for Lyapunov-style checks.

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::energy::rhythm_orchestrator::{
    EnergyOptimizationEvent, NodeMetrics, RhythmDecision, RhythmPolicy, RhythmSignals,
    WorkloadClass, WorkloadDescriptor, WorkloadSlo,
};

/// Normalized risk coordinate for a single metric (0.0 = ideal, 1.0 = at or beyond hard limit).
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct RiskCoord {
    pub value_norm: f32,
    pub weight: f32,
}

/// Simple corridor bands for one metric.
/// All values are expected in physical units of that metric.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct CorridorBands {
    pub safe_max: f32,
    pub gold_max: f32,
    pub hard_max: f32,
    /// Weight in the residual.
    pub weight: f32,
}

/// Residual V_t = sum_j w_j * r_j^2, with r_j in [0, 1].
/// Used as a monotone risk quantity.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Residual {
    pub value: f32,
}

/// KER triad: knowledge, eco-impact, risk-of-harm.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct KerTriad {
    pub knowledge_factor: f32,
    pub eco_impact: f32,
    pub risk_of_harm: f32,
}

/// Configuration for mapping Rhythm events into KER.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EcoKerConfig {
    /// Corridor for node power draw in watts.
    pub power_corridor: CorridorBands,
    /// Corridor for node temperature in Celsius.
    pub temperature_corridor: CorridorBands,
    /// Corridor for node utilization in percent.
    pub utilization_corridor: CorridorBands,
    /// Maximum reference energy savings for normalization in joules.
    pub eco_savings_ref_joules: f32,
    /// Number of critical variables that *should* be corridor-backed.
    pub n_critical_vars: u32,
}

/// Score attached to one RhythmDecision batch.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EcoKerScore {
    pub decision: RhythmDecision,
    pub event: Option<EnergyOptimizationEvent>,
    pub residual_before: Residual,
    pub residual_after: Residual,
    pub ker: KerTriad,
}

/// Per-node eco state snapshot, used to compute residuals.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeEcoSnapshot {
    pub metrics: NodeMetrics,
    pub risk_coords: HashMap<String, RiskCoord>,
    pub residual: Residual,
}

impl EcoKerConfig {
    /// Compute a RiskCoord from a raw value and corridor bands.
    pub fn normalize(&self, raw: f32, corridor: CorridorBands) -> RiskCoord {
        let CorridorBands {
            safe_max,
            gold_max: _,
            hard_max,
            weight,
        } = corridor;

        let span = (hard_max - safe_max).max(1e-6);
        let mut r = (raw - safe_max) / span;
        if r < 0.0 {
            r = 0.0;
        }
        if r > 1.0 {
            r = 1.0;
        }

        RiskCoord {
            value_norm: r,
            weight,
        }
    }

    /// Compute residual V_t = sum_j w_j * r_j^2.
    pub fn residual(&self, risk_coords: &HashMap<String, RiskCoord>) -> Residual {
        let mut v = 0.0_f32;
        for rc in risk_coords.values() {
            v += rc.weight * rc.value_norm * rc.value_norm;
        }
        Residual { value: v }
    }

    /// Compute EcoImpact E in [0, 1] from estimated energy saved (J).
    /// E = min(1, max(0, est_saved / eco_savings_ref_joules)).
    pub fn eco_impact(&self, est_saved_joules: f32) -> f32 {
        if self.eco_savings_ref_joules <= 0.0 {
            return 0.0;
        }
        let raw = est_saved_joules / self.eco_savings_ref_joules;
        raw.clamp(0.0, 1.0)
    }

    /// Knowledge-factor K in [0, 1]:
    /// K = N_corridor_backed / N_critical_vars.
    ///
    /// For this kernel we treat power, temperature, utilization as critical.
    pub fn knowledge_factor(&self, n_corridor_backed: u32) -> f32 {
        if self.n_critical_vars == 0 {
            return 0.0;
        }
        let k = n_corridor_backed as f32 / self.n_critical_vars as f32;
        k.clamp(0.0, 1.0)
    }

    /// Risk-of-harm R in [0, 1] from residual V:
    /// Here we use a simple affine normalization with nominal max V.
    pub fn risk_of_harm(&self, residual: Residual) -> f32 {
        // Nominal maximum residual we expect under hard bands.
        // This is configuration-agnostic but can be overridden later.
        let v_max_nominal = 10.0_f32;
        let r = residual.value / v_max_nominal;
        r.clamp(0.0, 1.0)
    }
}

/// Build a snapshot of node eco state from raw metrics.
pub fn build_node_eco_snapshot(
    cfg: &EcoKerConfig,
    metrics: &NodeMetrics,
) -> NodeEcoSnapshot {
    let mut risk_coords = HashMap::new();

    let rc_power = cfg.normalize(metrics.power_draw_watts, cfg.power_corridor);
    risk_coords.insert("power_draw_watts".to_string(), rc_power);

    let rc_temp = cfg.normalize(metrics.temperature_c, cfg.temperature_corridor);
    risk_coords.insert("temperature_c".to_string(), rc_temp);

    let rc_util = cfg.normalize(metrics.utilization_pct, cfg.utilization_corridor);
    risk_coords.insert("utilization_pct".to_string(), rc_util);

    let residual = cfg.residual(&risk_coords);

    NodeEcoSnapshot {
        metrics: metrics.clone(),
        risk_coords,
        residual,
    }
}

/// Compute EcoKerScore list for a batch of decisions and events.
///
/// `node_metrics` should be a snapshot taken before applying the batch
/// (e.g., from RhythmState.node_metrics).
///
/// The residual_before and residual_after are computed per assigned node.
/// For simplicity, we assume the batch does not yet change node metrics
/// except by a small delta approximate; this keeps the kernel purely analytical.
pub fn score_batch(
    cfg: &EcoKerConfig,
    node_metrics: &HashMap<String, NodeMetrics>,
    decisions_with_events: Vec<(RhythmDecision, Option<EnergyOptimizationEvent>)>,
) -> Vec<EcoKerScore> {
    let mut scores = Vec::with_capacity(decisions_with_events.len());

    // Precompute node snapshots.
    let mut snapshots_before: HashMap<String, NodeEcoSnapshot> = HashMap::new();
    for (node_id, m) in node_metrics {
        let snap = build_node_eco_snapshot(cfg, m);
        snapshots_before.insert(node_id.clone(), snap);
    }

    for (decision, event_opt) in decisions_with_events {
        let node_id = decision.assigned_node_id.clone();
        let before = snapshots_before.get(&node_id);

        let residual_before = before
            .map(|s| s.residual)
            .unwrap_or(Residual { value: 0.0 });

        // For now, assume residual_after is equal to residual_before;
        // a future extension could update utilization or power based on workload.
        let residual_after = residual_before;

        // Determine how many critical variables are corridor-backed.
        // In this kernel, we treat all three as backed when metrics exist.
        let n_corridor_backed = if before.is_some() { 3 } else { 0 };
        let k = cfg.knowledge_factor(n_corridor_backed);

        let est_saved = event_opt
            .as_ref()
            .map(|e| e.est_energy_saved_joules)
            .unwrap_or(0.0);
        let e_val = cfg.eco_impact(est_saved);

        let r_val = cfg.risk_of_harm(residual_after);

        let ker = KerTriad {
            knowledge_factor: k,
            eco_impact: e_val,
            risk_of_harm: r_val,
        };

        scores.push(EcoKerScore {
            decision,
            event: event_opt,
            residual_before,
            residual_after,
            ker,
        });
    }

    scores
}

/// Example helper for constructing a default EcoKerConfig that matches
/// a moderate data-center–style corridor.
///
/// These values are intentionally conservative and should be refined
/// by real measurements in eco-restoration deployments.
impl Default for EcoKerConfig {
    fn default() -> Self {
        EcoKerConfig {
            power_corridor: CorridorBands {
                safe_max: 80.0,   // watts
                gold_max: 150.0,  // watts
                hard_max: 250.0,  // watts
                weight: 1.5,
            },
            temperature_corridor: CorridorBands {
                safe_max: 40.0,   // °C
                gold_max: 60.0,   // °C
                hard_max: 80.0,   // °C
                weight: 2.0,
            },
            utilization_corridor: CorridorBands {
                safe_max: 40.0,   // percent
                gold_max: 75.0,   // percent
                hard_max: 95.0,   // percent
                weight: 1.0,
            },
            eco_savings_ref_joules: 5000.0,
            n_critical_vars: 3,
        }
    }
}
