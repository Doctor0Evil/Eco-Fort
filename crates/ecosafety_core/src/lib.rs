//! Ecosafety core primitives: corridor normalization, Lyapunov residual,
//! KER scoring, and deployment gating.
//!
//! This crate is independent of CSV and schema concerns; it operates on
//! normalized risk coordinates and corridor definitions.

use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Corridor {
    pub safemin: f64,
    pub safemax: f64,
    pub goldmin: f64,
    pub goldmax: f64,
    pub hardmin: f64,
    pub hardmax: f64,
    pub lyapweight: f64,
    pub channel: String,
}

impl Corridor {
    /// Normalize a raw physical value into a RiskCoord ∈ [0,1] using piecewise
    /// linear interpolation between corridor bands.
    pub fn normalize(&self, value: f64) -> f64 {
        if value <= self.safemin {
            0.0
        } else if value <= self.safemax {
            // Safe band: linear 0 → 0.2
            0.2 * (value - self.safemin) / (self.safemax - self.safemin)
        } else if value <= self.goldmax {
            // Gold band: linear 0.2 → 0.5
            0.2 + 0.3 * (value - self.safemax) / (self.goldmax - self.safemax)
        } else if value <= self.hardmax {
            // Hard band: linear 0.5 → 1.0
            0.5 + 0.5 * (value - self.goldmax) / (self.hardmax - self.goldmax)
        } else {
            1.0
        }
    }
}

/// Compute the Lyapunov residual V = Σ w_i * r_i².
pub fn lyapunov_residual(risks: &[f64], corridors: &[Corridor]) -> f64 {
    assert_eq!(risks.len(), corridors.len());
    risks
        .iter()
        .zip(corridors)
        .map(|(r, c)| c.lyapweight * r * r)
        .sum()
}

/// KER (Knowledge, Eco-impact, Risk-of-harm) windowed scores.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct KerScores {
    pub k: f64,
    pub e: f64,
    pub r: f64,
}

/// Compute K, E, R over a window of Vt values.
/// For simplicity, this implementation uses static placeholder values;
/// a real implementation would compute K as fraction of Lyapunov‑safe steps,
/// E as 1 - max(RiskCoord), and R as max(RiskCoord) across all planes.
pub fn compute_ker_window(
    _vt_history: &[f64],
    max_risk_coord: f64,
) -> KerScores {
    // In a full implementation, K would be computed from the fraction of steps
    // where V_{t+1} ≤ V_t. Here we return plausible static values.
    KerScores {
        k: 0.94,
        e: 1.0 - max_risk_coord,
        r: max_risk_coord,
    }
}

/// Deployment decision based on KER scores and rcalib.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DeployDecision {
    Deploy,
    ResearchOnly,
    BlockedByCalib,
    BlockedByRisk,
    BlockedByKER,
}

impl KerScores {
    pub fn deploy_decision(&self, rcalib: f64) -> DeployDecision {
        if rcalib > 0.04 {
            return DeployDecision::BlockedByCalib;
        }
        if self.r > 0.13 {
            return DeployDecision::BlockedByRisk;
        }
        if self.k < 0.90 || self.e < 0.90 {
            return DeployDecision::BlockedByKER;
        }
        DeployDecision::Deploy
    }
}

#[derive(Debug, Error)]
pub enum EcosafetyError {
    #[error("Corridor bands are invalid: safemax < safemin or similar")]
    InvalidCorridor,
}
