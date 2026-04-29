// Filename: crates/cyboquatic-eco-planes/src/lib.rs

#![forbid(unsafe_code)]
#![cfg_attr(not(feature = "std"), no_std)]

use cyboquatic_ecosafety_core::{CorridorBands, RiskCoord, RiskVector, Residual, LyapunovWeights};
use core::ops::RangeInclusive;

/// Per-cycle carbon bookkeeping for a machine or node.[file:21][file:14]
#[derive(Clone, Copy, Debug)]
pub struct CarbonCycle {
    /// Gross emissions (kg CO2e / cycle).
    pub emissions_kg: f32,
    /// Direct sequestration (kg CO2e / cycle).
    pub sequestration_kg: f32,
    /// Indirect avoided emissions (kg CO2e / cycle).
    pub avoided_kg: f32,
}

impl CarbonCycle {
    pub fn net_kg(&self) -> f32 {
        self.emissions_kg - self.sequestration_kg - self.avoided_kg
    }
}

/// Corridors for carbon risk; negative net flows rewarded.[file:21][file:14]
#[derive(Clone, Copy, Debug)]
pub struct CarbonCorridors {
    /// Net kg CO2e per cycle at which r_carbon ≈ 0 ("strongly negative").
    pub safe_net_kg: f32,
    /// Net kg CO2e per cycle at which r_carbon ≈ 0.5 ("neutral band").
    pub gold_net_kg: f32,
    /// Net kg CO2e per cycle at which r_carbon → 1 ("unacceptable").
    pub hard_net_kg: f32,
}

impl CarbonCorridors {
    pub fn phoenix_defaults() -> Self {
        // Example: ≤ -2 kg CO2e/cycle safe, -2..0 neutral, >0 positive.[file:14]
        CarbonCorridors {
            safe_net_kg: -2.0,
            gold_net_kg: 0.0,
            hard_net_kg: 5.0,
        }
    }

    pub fn normalize(&self, net_kg: f32) -> RiskCoord {
        if net_kg <= self.safe_net_kg {
            // Strongly negative: r_carbon near 0.[file:21]
            RiskCoord::new_clamped(0.0)
        } else if net_kg <= self.gold_net_kg {
            // Transition from negative to neutral.[file:21]
            let num = net_kg - self.safe_net_kg;
            let den = (self.gold_net_kg - self.safe_net_kg).max(1e-6);
            RiskCoord::new_clamped(num / den * 0.4)
        } else if net_kg <= self.hard_net_kg {
            // Neutral → harmful.[file:21]
            let num = net_kg - self.gold_net_kg;
            let den = (self.hard_net_kg - self.gold_net_kg).max(1e-6);
            RiskCoord::new_clamped(0.4 + num / den * 0.6)
        } else {
            RiskCoord::new_clamped(1.0)
        }
    }
}

/// Biodiversity indicators around a node (simplified).[file:14]
#[derive(Clone, Copy, Debug)]
pub struct BiodiversityState {
    /// Habitat connectivity index [0,1].
    pub connectivity: f32,
    /// Structural complexity index [0,1].
    pub complexity: f32,
    /// Colonization / occupancy by key species [0,1].
    pub colonization: f32,
}

#[derive(Clone, Copy, Debug)]
pub struct BiodiversityCorridors {
    /// Connectivity range considered "good".
    pub connectivity_range: RangeInclusive<f32>,
    /// Complexity range considered "good".
    pub complexity_range: RangeInclusive<f32>,
    /// Colonization range considered "good".
    pub colonization_range: RangeInclusive<f32>,
}

impl BiodiversityCorridors {
    pub fn default() -> Self {
        BiodiversityCorridors {
            // Example corridors – refine from field data and habitat indices.[file:14]
            connectivity_range: 0.6..=1.0,
            complexity_range: 0.5..=1.0,
            colonization_range: 0.5..=1.0,
        }
    }

    pub fn normalize(&self, bio: &BiodiversityState) -> RiskCoord {
        let c_conn = self.normalize_one(bio.connectivity, &self.connectivity_range);
        let c_comp = self.normalize_one(bio.complexity, &self.complexity_range);
        let c_col = self.normalize_one(bio.colonization, &self.colonization_range);
        // Take max risk across sub-indicators.[file:14]
        let m = c_conn.max(c_comp).max(c_col);
        RiskCoord::new_clamped(m)
    }

    fn normalize_one(&self, v: f32, r: &RangeInclusive<f32>) -> f32 {
        let low = *r.start();
        let high = *r.end();
        if v >= high {
            0.0
        } else if v >= low {
            let num = high - v;
            let den = (high - low).max(1e-6);
            num / den * 0.5
        } else {
            // Below acceptable range: push risk toward 1.[file:14]
            let deficit = low - v;
            let den = low.max(1e-6);
            0.5 + (deficit / den).min(1.0) * 0.5
        }
    }
}

/// Embed carbon and biodiversity into a global RiskVector.[file:21][file:14]
pub fn embed_carbon_biodiversity(
    rv: &mut RiskVector,
    cycle: &CarbonCycle,
    carbon_corr: &CarbonCorridors,
    bio_state: &BiodiversityState,
    bio_corr: &BiodiversityCorridors,
) {
    let net_kg = cycle.net_kg();
    rv.r_carbon = carbon_corr.normalize(net_kg);
    rv.r_biodiversity = bio_corr.normalize(bio_state);
}

/// Check if a long-horizon scenario is carbon-negative and habitat-enhancing.[file:14]
pub fn long_horizon_eco_ok(
    residuals: &[Residual],
    risks: &[RiskVector],
    weights: &LyapunovWeights,
    rcarbon_threshold: f32,
    rbio_threshold: f32,
) -> bool {
    if residuals.is_empty() || residuals.len() != risks.len() {
        return false;
    }
    // Require non-increasing V_t over the window.
    for w in residuals.windows(2) {
        if w[1].0 > w[0].0 {
            return false;
        }
    }
    // Require low worst-case r_carbon and r_biodiversity.
    let mut worst_c = 0.0;
    let mut worst_b = 0.0;
    for rv in risks {
        if rv.r_carbon.value() > worst_c {
            worst_c = rv.r_carbon.value();
        }
        if rv.r_biodiversity.value() > worst_b {
            worst_b = rv.r_biodiversity.value();
        }
    }
    worst_c <= rcarbon_threshold && worst_b <= rbio_threshold
}

/// Example: evaluate a decomposition / long-horizon simulation trajectory.[file:14]
pub fn evaluate_decomposition_scenario(
    risk_series: &[RiskVector],
    weights: &LyapunovWeights,
) -> (Vec<Residual>, bool) {
    let mut residuals = Vec::with_capacity(risk_series.len());
    for rv in risk_series {
        residuals.push(Residual::compute(rv, weights));
    }
    let ok = long_horizon_eco_ok(&residuals, risk_series, weights, 0.3, 0.3);
    (residuals, ok)
}
