//! cyboquatic_ecosafety_core
//! Tier-1 ecosafety spine for Cyboquatic industrial machinery:
//! - normalized risk coordinates r_x ∈ [0,1]
//! - multi-plane Lyapunov residual V_t = Σ w_j r_j^2
//! - strict corridor enforcement (no corridor, no build; violated corridor => derate/stop)
//! - KER scoring window (Knowledge-factor, Eco-impact, Risk-of-harm)
//! - carbon and materials planes as first-class ecological coordinates
//!
//! This crate is non-actuating by design. It never touches hardware. It
//! defines the grammar that all controllers and gateways must obey. [file:20][file:22]

pub mod types {
    /// Normalized risk coordinate in [0,1], corridor-normalized. [file:20]
    #[derive(Clone, Copy, Debug)]
    pub struct RiskCoord(f32);

    impl RiskCoord {
        pub fn new(clamped_01: f32) -> Option<Self> {
            if (0.0..=1.0).contains(&clamped_01) {
                Some(Self(clamped_01))
            } else {
                None
            }
        }
        pub fn zero() -> Self {
            Self(0.0)
        }
        pub fn one() -> Self {
            Self(1.0)
        }
        pub fn value(self) -> f32 {
            self.0
        }
    }

    /// Corridor bands for a single coordinate: safe, gold, hard. [file:20][file:22]
    #[derive(Clone, Copy, Debug)]
    pub struct CorridorBands {
        pub safe_max: f32,
        pub gold_max: f32,
        pub hard_max: f32,
    }

    impl CorridorBands {
        pub fn validate(&self) -> bool {
            0.0 <= self.safe_max
                && self.safe_max <= self.gold_max
                && self.gold_max <= self.hard_max
                && self.hard_max <= 1.0
        }
    }

    /// One dimension of the risk vector with its corridor and Lyapunov weight. [file:20][file:22]
    #[derive(Clone, Copy, Debug)]
    pub struct RiskPlane {
        pub coord: RiskCoord,
        pub bands: CorridorBands,
        pub weight: f32,
    }

    /// Multi-plane risk vector: energy, hydraulics, biology, carbon, materials, etc. [file:20]
    #[derive(Clone, Debug)]
    pub struct RiskVector {
        pub energy: RiskPlane,
        pub hydraulics: RiskPlane,
        pub biology: RiskPlane,
        pub carbon: RiskPlane,
        pub materials: RiskPlane,
    }

    /// Scalar Lyapunov residual V_t = Σ w_j r_j^2. [file:20]
    #[derive(Clone, Copy, Debug)]
    pub struct LyapunovResidual {
        pub value: f32,
    }

    impl LyapunovResidual {
        pub fn new(value: f32) -> Self {
            Self { value }
        }
    }

    /// KER triad over a rolling window. [file:20]
    #[derive(Clone, Copy, Debug)]
    pub struct KerTriad {
        pub k_knowledge: f32,
        pub e_eco_impact: f32,
        pub r_risk_of_harm: f32,
    }

    impl KerTriad {
        pub fn is_deployable(&self) -> bool {
            self.k_knowledge >= 0.90 && self.e_eco_impact >= 0.90 && self.r_risk_of_harm <= 0.13
        }
    }

    /// Per-step ecosafety decision: accept, derate, or stop. [file:20][file:21]
    #[derive(Clone, Copy, Debug, PartialEq, Eq)]
    pub enum SafeStepDecision {
        Accept,
        Derate,
        Stop,
    }

    /// Result of evaluating a proposed step. [file:20][file:21]
    #[derive(Clone, Debug)]
    pub struct StepEvaluation {
        pub decision: SafeStepDecision,
        pub vt_prev: LyapunovResidual,
        pub vt_next: LyapunovResidual,
        pub risk_vector: RiskVector,
    }
}

pub mod kernels {
    use super::types::*;

    /// Compute quadratic Lyapunov residual from a RiskVector. [file:20]
    pub fn compute_residual(rv: &RiskVector) -> LyapunovResidual {
        let planes = [
            &rv.energy,
            &rv.hydraulics,
            &rv.biology,
            &rv.carbon,
            &rv.materials,
        ];
        let mut acc = 0.0_f32;
        for p in planes {
            let r = p.coord.value();
            acc += p.weight * r * r;
        }
        LyapunovResidual::new(acc)
    }

    /// Max risk coordinate across all planes (R metric raw). [file:20]
    pub fn max_risk(rv: &RiskVector) -> f32 {
        let coords = [
            rv.energy.coord.value(),
            rv.hydraulics.coord.value(),
            rv.biology.coord.value(),
            rv.carbon.coord.value(),
            rv.materials.coord.value(),
        ];
        coords
            .into_iter()
            .fold(0.0_f32, |mx, v| if v > mx { v } else { mx })
    }

    /// Eco-impact E = 1 - max_r (complement of worst coordinate). [file:20]
    pub fn eco_impact(rv: &RiskVector) -> f32 {
        1.0 - max_risk(rv)
    }

    /// Ensure every plane has a valid corridor (no corridor, no build). [file:20][file:22]
    pub fn corridors_present(rv: &RiskVector) -> bool {
        [
            rv.energy.bands,
            rv.hydraulics.bands,
            rv.biology.bands,
            rv.carbon.bands,
            rv.materials.bands,
        ]
        .iter()
        .all(|b| b.validate())
    }

    /// Check if any coordinate has reached or exceeded its hard band. [file:20][file:22]
    pub fn hard_violation(rv: &RiskVector) -> bool {
        let planes = [
            &rv.energy,
            &rv.hydraulics,
            &rv.biology,
            &rv.carbon,
            &rv.materials,
        ];
        planes.iter().any(|p| p.coord.value() >= p.bands.hard_max)
    }

    /// Ecosafety gate: enforce V_{t+1} ≤ V_t + ε and no hard-band violation. [file:20]
    pub fn safestep_gate(
        vt_prev: LyapunovResidual,
        vt_next: LyapunovResidual,
        rv_next: &RiskVector,
        epsilon: f32,
    ) -> SafeStepDecision {
        if !corridors_present(rv_next) {
            return SafeStepDecision::Stop;
        }
        if hard_violation(rv_next) {
            return SafeStepDecision::Stop;
        }

        if vt_next.value <= vt_prev.value + epsilon {
            SafeStepDecision::Accept
        } else {
            // Derate envelope but allow safe operation under Lyapunov drift cap. [file:20][file:21]
            SafeStepDecision::Derate
        }
    }
}

pub mod eco_planes {
    use super::types::{CorridorBands, RiskCoord, RiskPlane};

    /// Normalize net CO₂-e per cycle into r_carbon ∈ [0,1] with
    /// sequestration ≈ 0, carbon-neutral in gold band, net-positive → 1. [file:20][file:9]
    pub fn carbon_plane_from_emissions(
        net_kg_co2e_per_cycle: f32,
        corridor_negative: f32,
        corridor_neutral: f32,
        corridor_positive: f32,
        weight: f32,
    ) -> Option<RiskPlane> {
        if !(corridor_negative < corridor_neutral && corridor_neutral < corridor_positive) {
            return None;
        }

        let r = if net_kg_co2e_per_cycle <= corridor_negative {
            0.0
        } else if net_kg_co2e_per_cycle <= corridor_neutral {
            // map [neg, neutral] into [0, safe_max]
            let span = corridor_neutral - corridor_negative;
            let frac = (net_kg_co2e_per_cycle - corridor_negative) / span.max(1e-6);
            0.1 * frac
        } else if net_kg_co2e_per_cycle <= corridor_positive {
            // map [neutral, positive] into [safe_max, hard_max]
            let span = corridor_positive - corridor_neutral;
            let frac = (net_kg_co2e_per_cycle - corridor_neutral) / span.max(1e-6);
            0.1 + 0.9 * frac
        } else {
            1.0
        };

        let coord = RiskCoord::new(r)?;
        let bands = CorridorBands {
            safe_max: 0.3,
            gold_max: 0.6,
            hard_max: 1.0,
        };
        Some(RiskPlane {
            coord,
            bands,
            weight,
        })
    }

    /// Collapse material kinetics and toxicity into a single r_materials coordinate. [file:20][file:22]
    pub fn materials_plane_from_kinetics(
        r_degrade: f32,
        r_tox: f32,
        r_micro: f32,
        r_leach: f32,
        r_pfas_resid: f32,
        weight: f32,
    ) -> Option<RiskPlane> {
        // All sub-risks are already normalized ∈ [0,1] by upstream lab kernels. [file:22]
        if ![r_degrade, r_tox, r_micro, r_leach, r_pfas_resid]
            .iter()
            .all(|v| (0.0..=1.0).contains(v))
        {
            return None;
        }

        // Penalize slow degradation and high toxicity/leachate. [file:22]
        let composite = 0.25 * r_degrade
            + 0.25 * r_tox
            + 0.20 * r_micro
            + 0.15 * r_leach
            + 0.15 * r_pfas_resid;

        let coord = RiskCoord::new(composite)?;
        let bands = CorridorBands {
            safe_max: 0.25,
            gold_max: 0.5,
            hard_max: 1.0,
        };

        Some(RiskPlane {
            coord,
            bands,
            weight,
        })
    }
}

pub mod traits {
    use super::kernels::{compute_residual, eco_impact, max_risk, safestep_gate};
    use super::types::*;

    /// Domain-specific machine state (opaque to ecosafety core). [file:20]
    pub trait MachineState: Clone {}

    /// Domain-specific actuation proposal (opaque to ecosafety core). [file:20][file:21]
    pub trait ActuationCommand: Clone {}

    /// Each controller must propose a step + risk vector; no action without risk estimate. [file:20]
    pub trait SafeController<S: MachineState, C: ActuationCommand> {
        fn propose_step(&self, state: &S) -> (C, RiskVector);
    }

    /// Ecosafety kernel: non-actuating, pure decision logic. [file:20][file:21]
    pub struct EcoSafetyKernel {
        pub epsilon_vt: f32,
    }

    impl EcoSafetyKernel {
        pub fn new(epsilon_vt: f32) -> Self {
            Self { epsilon_vt }
        }

        /// Evaluate one proposed step. [file:20][file:21]
        pub fn evaluate_step<S, C, Ctrl>(
            &self,
            controller: &Ctrl,
            state: &S,
            vt_prev: LyapunovResidual,
        ) -> StepEvaluation
        where
            S: MachineState,
            C: ActuationCommand,
            Ctrl: SafeController<S, C>,
        {
            let (_cmd, rv_next) = controller.propose_step(state);
            let vt_next = compute_residual(&rv_next);
            let decision = safestep_gate(vt_prev, vt_next, &rv_next, self.epsilon_vt);
            StepEvaluation {
                decision,
                vt_prev,
                vt_next,
                risk_vector: rv_next,
            }
        }

        /// Compute KER for a sliding window of past residual-safe evaluations. [file:20]
        pub fn ker_from_window(window: &[StepEvaluation]) -> KerTriad {
            if window.is_empty() {
                return KerTriad {
                    k_knowledge: 0.0,
                    e_eco_impact: 0.0,
                    r_risk_of_harm: 1.0,
                };
            }

            let mut safe_steps = 0_u32;
            let mut max_r = 0.0_f32;

            for ev in window {
                if ev.decision == SafeStepDecision::Accept {
                    // Accept counts as Lyapunov-safe by construction. [file:20]
                    safe_steps += 1;
                }
                let r = max_risk(&ev.risk_vector);
                if r > max_r {
                    max_r = r;
                }
            }

            let k = safe_steps as f32 / (window.len() as f32);
            let e = 1.0 - max_r;
            let r = max_r;

            KerTriad {
                k_knowledge: k,
                e_eco_impact: e,
                r_risk_of_harm: r,
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::eco_planes::*;
    use super::kernels::*;
    use super::traits::*;
    use super::types::*;

    #[derive(Clone)]
    struct DummyState;
    impl MachineState for DummyState {}

    #[derive(Clone)]
    struct DummyCmd;
    impl ActuationCommand for DummyCmd {}

    struct DummyController;
    impl SafeController<DummyState, DummyCmd> for DummyController {
        fn propose_step(&self, _state: &DummyState) -> (DummyCmd, RiskVector) {
            let zero = RiskCoord::zero();
            let cb = CorridorBands {
                safe_max: 0.3,
                gold_max: 0.6,
                hard_max: 1.0,
            };

            let energy = RiskPlane {
                coord: zero,
                bands: cb,
                weight: 1.0,
            };
            let hydraulics = energy;
            let biology = energy;

            let carbon =
                carbon_plane_from_emissions(-2.0, -5.0, 0.0, 5.0, 1.0).expect("carbon plane");
            let materials =
                materials_plane_from_kinetics(0.1, 0.05, 0.03, 0.04, 0.02, 1.0).expect("mat");

            let rv = RiskVector {
                energy,
                hydraulics,
                biology,
                carbon,
                materials,
            };
            (DummyCmd, rv)
        }
    }

    #[test]
    fn test_safestep_accepts_safe_state() {
        let ctrl = DummyController;
        let kernel = EcoSafetyKernel::new(1e-3);
        let state = DummyState;
        let vt_prev = LyapunovResidual::new(0.2);

        let ev = kernel.evaluate_step::<DummyState, DummyCmd, _>(&ctrl, &state, vt_prev);
        assert_ne!(ev.decision, SafeStepDecision::Stop);
        assert!(ev.vt_next.value <= vt_prev.value + kernel.epsilon_vt + 1e-4);
    }

    #[test]
    fn test_ker_scoring() {
        let ctrl = DummyController;
        let kernel = EcoSafetyKernel::new(1e-3);
        let state = DummyState;
        let vt_prev = LyapunovResidual::new(0.2);

        let mut window = Vec::new();
        for _ in 0..100 {
            let ev = kernel.evaluate_step::<DummyState, DummyCmd, _>(&ctrl, &state, vt_prev);
            window.push(ev);
        }

        let ker = EcoSafetyKernel::ker_from_window(&window);
        assert!(ker.k_knowledge >= 0.90);
        assert!(ker.e_eco_impact >= 0.90 - 1e-3);
        assert!(ker.r_risk_of_harm <= 0.13 + 1e-3);
    }
}
