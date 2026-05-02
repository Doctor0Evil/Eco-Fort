// filename: crates/ecosafety-core/src/lane.rs

pub enum Lane {
    Research,
    ExpProd,
    Prod,
}

pub enum LaneDecision {
    Approve,
    Reject,
    Hold,
}

pub trait LaneGovernance {
    fn lane_decision(
        current: Lane,
        proposed: Lane,
        k: f32,
        e: f32,
        r: f32,
        rcalib: f32,
        rsigma: f32,
        cfg: &KerDeployableConfig,
    ) -> LaneDecision;
}

pub struct DefaultLaneGovernance;

impl LaneGovernance for DefaultLaneGovernance {
    fn lane_decision(
        current: Lane,
        proposed: Lane,
        k: f32,
        e: f32,
        r: f32,
        rcalib: f32,
        rsigma: f32,
        cfg: &KerDeployableConfig,
    ) -> LaneDecision {
        use Lane::*;
        use LaneDecision::*;

        // Respect KER deploy gates first.
        if r > cfg.rmax {
            return Reject;
        }
        if rcalib > cfg.rcalib_hard || rsigma > cfg.rsigma_hard {
            return Reject;
        }
        if k < cfg.kmin || e < cfg.emin {
            return Reject;
        }

        match (current, proposed) {
            (Research, ExpProd) => Approve,
            (ExpProd, Prod)     => Approve,
            (_, _)              => Reject,
        }
    }
}
