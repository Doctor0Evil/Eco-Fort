use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Minimal bridge descriptor towards Virta-Sys virtual cluster orchestrator.[file:1]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VirtaSysBridgeConfig {
    pub orchestrator_config_path: PathBuf,
}

/// Stub struct reserved for future orchestration-aware integrations.
#[derive(Debug, Clone)]
pub struct VirtaSysBridge {
    pub config: VirtaSysBridgeConfig,
}

impl VirtaSysBridge {
    pub fn new(orchestrator_config_path: PathBuf) -> Self {
        Self {
            config: VirtaSysBridgeConfig {
                orchestrator_config_path,
            },
        }
    }
}
