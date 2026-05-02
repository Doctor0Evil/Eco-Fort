// filename: crates/ecosafety-core/src/residual.rs (conceptual)

pub struct RiskVectorFull {
    pub renergy: f32,
    pub rhydraulic: f32,
    pub rbiology: f32,
    pub rcarbon: f32,
    pub rmaterials: f32,
    pub rbiodiversity: f32,
    pub rcalib: f32,
    pub rsigma: f32,
    pub rtopology: f32, // NEW
}

pub struct LyapunovWeightsFull {
    pub wenergy: f32,
    pub whydraulic: f32,
    pub wbiology: f32,
    pub wcarbon: f32,
    pub wmaterials: f32,
    pub wbiodiversity: f32,
    pub wcalib: f32,
    pub wsigma: f32,
    pub wtopology: f32, // NEW
}

impl LyapunovWeightsFull {
    pub fn compute_residual(&self, r: &RiskVectorFull) -> f32 {
        self.wenergy      * r.renergy      * r.renergy
      + self.whydraulic   * r.rhydraulic   * r.rhydraulic
      + self.wbiology     * r.rbiology     * r.rbiology
      + self.wcarbon      * r.rcarbon      * r.rcarbon
      + self.wmaterials   * r.rmaterials   * r.rmaterials
      + self.wbiodiversity* r.rbiodiversity* r.rbiodiversity
      + self.wcalib       * r.rcalib       * r.rcalib
      + self.wsigma       * r.rsigma       * r.rsigma
      + self.wtopology    * r.rtopology    * r.rtopology
    }
}
