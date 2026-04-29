// Filename: crates/cyboquatic-ecosafety-core/src/lib.rs

#![forbid(unsafe_code)]
#![cfg_attr(not(feature = "std"), no_std)]

/// Normalized risk coordinate r_x ∈ [0,1] for a single plane (energy, hydraulics, carbon, etc.).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RiskCoord(f32);

impl RiskCoord {
    pub fn new_clamped(raw: f32) -> Self {
        let v = if raw < 0.0 { 0.0 } else if raw > 1.0 { 1.0 } else { raw };
        RiskCoord(v)
    }

    pub fn value(self) -> f32 {
        self.0
    }
}

/// Corridor bands for mapping raw physical units into [0,1] risk coordinates.[file:21]
#[derive(Clone, Copy, Debug)]
pub struct CorridorBands {
    pub safe_max: f32,
    pub gold_max: f32,
    pub hard_max: f32,
}

impl CorridorBands {
    pub fn normalize(&self, raw: f32) -> RiskCoord {
        if raw <= self.safe_max {
            RiskCoord::new_clamped(0.0)
        } else if raw <= self.gold_max {
            let num = raw - self.safe_max;
            let den = (self.gold_max - self.safe_max).max(1e-6);
            RiskCoord::new_clamped(num / den * 0.5)
        } else if raw <= self.hard_max {
            let num = raw - self.gold_max;
            let den = (self.hard_max - self.gold_max).max(1e-6);
            RiskCoord::new_clamped(0.5 + num / den * 0.5)
        } else {
            RiskCoord::new_clamped(1.0)
        }
    }
}

/// Canonical planes used across Cyboquatic machinery.[file:21][file:14]
#[derive(Clone, Copy, Debug)]
pub struct RiskVector {
    pub r_energy: RiskCoord,
    pub r_hydraulics: RiskCoord,
    pub r_biology: RiskCoord,
    pub r_carbon: RiskCoord,
    pub r_materials: RiskCoord,
    pub r_biodiversity: RiskCoord,
    /// Optional explicit data/uncertainty coordinate r_sigma.[file:14]
    pub r_sigma: RiskCoord,
}

impl RiskVector {
    pub fn max_coord(&self) -> RiskCoord {
        let vals = [
            self.r_energy.value(),
            self.r_hydraulics.value(),
            self.r_biology.value(),
            self.r_carbon.value(),
            self.r_materials.value(),
            self.r_biodiversity.value(),
            self.r_sigma.value(),
        ];
        let mut m = 0.0;
        for v in vals.iter().copied() {
            if v > m {
                m = v;
            }
        }
        RiskCoord::new_clamped(m)
    }
}

/// Weights for the quadratic Lyapunov residual V_t = Σ w_j r_j^2.[file:21][file:14]
#[derive(Clone, Copy, Debug)]
pub struct LyapunovWeights {
    pub w_energy: f32,
    pub w_hydraulics: f32,
    pub w_biology: f32,
    pub w_carbon: f32,
    pub w_materials: f32,
    pub w_biodiversity: f32,
    pub w_sigma: f32,
}

impl LyapunovWeights {
    pub fn default_ecosafety() -> Self {
        // Upweight long-horizon ecological harm vs local mechanics.[file:14]
        LyapunovWeights {
            w_energy: 1.0,
            w_hydraulics: 1.2,
            w_biology: 1.4,
            w_carbon: 1.5,
            w_materials: 1.3,
            w_biodiversity: 1.5,
            w_sigma: 1.1,
        }
    }
}

/// Scalar Lyapunov residual V_t over the risk planes.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Residual(pub f32);

impl Residual {
    pub fn compute(rv: &RiskVector, w: &LyapunovWeights) -> Self {
        let e = rv.r_energy.value();
        let h = rv.r_hydraulics.value();
        let b = rv.r_biology.value();
        let c = rv.r_carbon.value();
        let m = rv.r_materials.value();
        let bio = rv.r_biodiversity.value();
        let s = rv.r_sigma.value();
        let v = w.w_energy * e * e
            + w.w_hydraulics * h * h
            + w.w_biology * b * b
            + w.w_carbon * c * c
            + w.w_materials * m * m
            + w.w_biodiversity * bio * bio
            + w.w_sigma * s * s;
        Residual(v)
    }
}

/// Decision returned by safestep gating.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SafeStepDecision {
    Ok,
    Derate,
    Stop,
}

/// Configuration for safestep invariant: V_{t+1} ≤ V_t + ε, with ε small.[file:21]
#[derive(Clone, Copy, Debug)]
pub struct SafeStepConfig {
    pub epsilon: f32,
    /// Hard cap on any individual coordinate r_x.[file:21]
    pub r_max: f32,
}

impl SafeStepConfig {
    pub fn strict() -> Self {
        SafeStepConfig {
            epsilon: 0.0,
            r_max: 1.0,
        }
    }

    pub fn relaxed(epsilon: f32, r_max: f32) -> Self {
        SafeStepConfig { epsilon, r_max }
    }
}

/// Core ecosafety invariant: no action without a RiskVector, and V_t non-increase.[file:21][file:11]
pub fn safestep(
    prev_residual: Residual,
    next_residual: Residual,
    next_risks: &RiskVector,
    cfg: &SafeStepConfig,
) -> SafeStepDecision {
    let max_r = next_risks.max_coord().value();
    if max_r > cfg.r_max {
        return SafeStepDecision::Stop;
    }

    if next_residual.0 <= prev_residual.0 + cfg.epsilon {
        SafeStepDecision::Ok
    } else {
        // Residual increased but no hard corridor breach: derate-only lane.[file:11]
        SafeStepDecision::Derate
    }
}

/// Rolling KER window summarizing ecosafety performance.[file:21][file:14]
#[derive(Clone, Copy, Debug, Default)]
pub struct KerWindow {
    pub window_len: u32,
    pub steps_seen: u32,
    pub steps_safe: u32,
    pub worst_r: f32,
}

#[derive(Clone, Copy, Debug)]
pub struct KerTriad {
    pub k_knowledge: f32,
    pub e_ecoimpact: f32,
    pub r_risk_of_harm: f32,
}

impl KerWindow {
    pub fn new(window_len: u32) -> Self {
        KerWindow {
            window_len,
            steps_seen: 0,
            steps_safe: 0,
            worst_r: 0.0,
        }
    }

    /// Update KER given decision outcome and risk vector for this step.[file:21]
    pub fn update(&mut self, decision: SafeStepDecision, rv: &RiskVector) {
        self.steps_seen = self.steps_seen.saturating_add(1);
        if matches!(decision, SafeStepDecision::Ok | SafeStepDecision::Derate) {
            self.steps_safe = self.steps_safe.saturating_add(1);
        }
        let r = rv.max_coord().value();
        if r > self.worst_r {
            self.worst_r = r;
        }
        if self.steps_seen > self.window_len {
            // In a full implementation, maintain a ring buffer; here we clamp.[file:14]
            self.steps_seen = self.window_len;
        }
    }

    pub fn triad(&self) -> KerTriad {
        if self.steps_seen == 0 {
            return KerTriad {
                k_knowledge: 0.0,
                e_ecoimpact: 0.0,
                r_risk_of_harm: 0.0,
            };
        }
        let k = self.steps_safe as f32 / self.steps_seen as f32;
        let r = self.worst_r;
        let e = 1.0 - r;
        KerTriad {
            k_knowledge: k,
            e_ecoimpact: e,
            r_risk_of_harm: r,
        }
    }

    /// Governance check for production deployability: K≥0.90, E≥0.90, R≤0.13.[file:21][file:11]
    pub fn is_ker_deployable(&self) -> bool {
        let triad = self.triad();
        triad.k_knowledge >= 0.90 && triad.e_ecoimpact >= 0.90 && triad.r_risk_of_harm <= 0.13
    }
}

/// Controller trait: no actuation without a complete RiskVector and next Residual.[file:21][file:11]
pub trait SafeController {
    type State;
    type Command;

    fn propose_step(&self, state: &Self::State) -> (Self::Command, RiskVector, Residual);
}
