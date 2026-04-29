// Filename: crates/cyboquatic-materials-core/src/lib.rs

#![forbid(unsafe_code)]
#![cfg_attr(not(feature = "std"), no_std)]

use cyboquatic_ecosafety_core::{CorridorBands, RiskCoord, RiskVector};

/// Measured or simulated kinetics for a biodegradable substrate.[file:14]
#[derive(Clone, Copy, Debug)]
pub struct MaterialKinetics {
    /// Time to 90% mass loss (days), e.g., from ISO 14851 / OECD 301 tests.[file:14]
    pub t90_days: f32,
    /// Dimensionless ecotoxicity index (0 = benign, 1 = severe).[file:14]
    pub tox_index: f32,
    /// Fraction of mass persisting as micro-residue (<5 mm).[file:14]
    pub micro_residue_frac: f32,
    /// Leachate index, e.g., scaled CEC / PFAS burden.[file:21][file:14]
    pub leachate_index: f32,
    /// Caloric / embodied energy fraction relative to baseline plastic.[file:14]
    pub caloric_frac: f32,
}

/// Normalized material-risk coordinates derived from kinetics.[file:21][file:14]
#[derive(Clone, Copy, Debug)]
pub struct MaterialRisks {
    pub r_t90: RiskCoord,
    pub r_tox: RiskCoord,
    pub r_micro: RiskCoord,
    pub r_leachate: RiskCoord,
    pub r_caloric: RiskCoord,
}

impl MaterialRisks {
    pub fn max_coord(&self) -> RiskCoord {
        let vals = [
            self.r_t90.value(),
            self.r_tox.value(),
            self.r_micro.value(),
            self.r_leachate.value(),
            self.r_caloric.value(),
        ];
        let mut m = 0.0;
        for v in vals {
            if v > m {
                m = v;
            }
        }
        RiskCoord::new_clamped(m)
    }
}

/// Corridor configuration for materials; tuned from tray/MAR bio-pack data.[file:14]
#[derive(Clone, Copy, Debug)]
pub struct MaterialCorridors {
    pub t90_days_corridor: CorridorBands,
    pub tox_corridor: CorridorBands,
    pub micro_corridor: CorridorBands,
    pub leachate_corridor: CorridorBands,
    pub caloric_corridor: CorridorBands,
}

impl MaterialCorridors {
    pub fn phoenix_biopack_defaults() -> Self {
        // Example: safe ≤ 90 d, gold ≤ 180 d, hard ≤ 365 d.[file:14]
        let t90 = CorridorBands {
            safe_max: 90.0,
            gold_max: 180.0,
            hard_max: 365.0,
        };
        // Ecotoxicity index: safe ≤0.05, gold ≤0.10, hard ≤0.20.[file:14]
        let tox = CorridorBands {
            safe_max: 0.05,
            gold_max: 0.10,
            hard_max: 0.20,
        };
        // Micro-residue: safe ≤0.02, gold ≤0.05, hard ≤0.10.[file:14]
        let micro = CorridorBands {
            safe_max: 0.02,
            gold_max: 0.05,
            hard_max: 0.10,
        };
        // Leachate index: safe ≤0.1, gold ≤0.2, hard ≤0.4.[file:21][file:14]
        let leach = CorridorBands {
            safe_max: 0.10,
            gold_max: 0.20,
            hard_max: 0.40,
        };
        // Caloric / embodied energy: safe ≤0.3, gold ≤0.5, hard ≤0.7.[file:14]
        let caloric = CorridorBands {
            safe_max: 0.30,
            gold_max: 0.50,
            hard_max: 0.70,
        };

        MaterialCorridors {
            t90_days_corridor: t90,
            tox_corridor: tox,
            micro_corridor: micro,
            leachate_corridor: leach,
            caloric_corridor: caloric,
        }
    }

    pub fn normalize(&self, kin: &MaterialKinetics) -> MaterialRisks {
        let r_t90 = self.t90_days_corridor.normalize(kin.t90_days);
        let r_tox = self.tox_corridor.normalize(kin.tox_index);
        let r_micro = self.micro_corridor.normalize(kin.micro_residue_frac);
        let r_leachate = self.leachate_corridor.normalize(kin.leachate_index);
        let r_caloric = self.caloric_corridor.normalize(kin.caloric_frac);

        MaterialRisks {
            r_t90,
            r_tox,
            r_micro,
            r_leachate,
            r_caloric,
        }
    }
}

/// Trait for substrates that must be checked against material corridors at compile/load time.[file:21][file:14]
pub trait AntSafeSubstrate {
    fn kinetics(&self) -> &MaterialKinetics;

    /// Hard gate: only substrates with all risks ≤ corridor hard bands are allowed.[file:21]
    fn corridor_ok(&self, corridors: &MaterialCorridors) -> bool {
        let risks = corridors.normalize(self.kinetics());
        let max_r = risks.max_coord().value();
        max_r < 1.0
    }

    /// Fold material risks into the global RiskVector.r_materials.[file:21][file:14]
    fn embed_into_risk_vector(
        &self,
        corridors: &MaterialCorridors,
        mut rv: RiskVector,
        weight_t90: f32,
        weight_tox: f32,
        weight_micro: f32,
        weight_leach: f32,
        weight_caloric: f32,
    ) -> RiskVector {
        let risks = corridors.normalize(self.kinetics());
        let num = weight_t90 * risks.r_t90.value()
            + weight_tox * risks.r_tox.value()
            + weight_micro * risks.r_micro.value()
            + weight_leach * risks.r_leachate.value()
            + weight_caloric * risks.r_caloric.value();
        let den = weight_t90 + weight_tox + weight_micro + weight_leach + weight_caloric;
        let r_mat = if den > 0.0 { num / den } else { 0.0 };
        rv.r_materials = RiskCoord::new_clamped(r_mat);
        rv
    }
}

/// Example substrate used in a Cyboquatic tray or FlowVac media.[file:14]
#[derive(Clone, Copy, Debug)]
pub struct BioPackSubstrate {
    pub name_hexstamp: [u8; 16],
    pub kinetics: MaterialKinetics,
}

impl AntSafeSubstrate for BioPackSubstrate {
    fn kinetics(&self) -> &MaterialKinetics {
        &self.kinetics
    }
}
