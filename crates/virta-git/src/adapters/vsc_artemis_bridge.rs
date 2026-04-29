use serde::{Deserialize, Serialize};

/// Minimal bridge descriptor towards VSC-ARTEMIS system-brain.[file:1]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VscArtemisBridgeConfig {
    pub data_lake_id: String,
    pub typewriter_id: String,
    pub dream_catcher_id: String,
}

#[derive(Debug, Clone)]
pub struct VscArtemisBridge {
    pub config: VscArtemisBridgeConfig,
}

impl VscArtemisBridge {
    pub fn new() -> Self {
        Self {
            config: VscArtemisBridgeConfig {
                data_lake_id: "DATA-LAKE".to_string(),
                typewriter_id: "TYPEWRITER".to_string(),
                dream_catcher_id: "DREAM-CATCHER".to_string(),
            },
        }
    }
}
