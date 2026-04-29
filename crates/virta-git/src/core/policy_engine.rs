use crate::{IoPolicies, PolicySection, VirtaGitConfig};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use thiserror::Error;

/// High-level policy engine for Virta-Git, enforcing non-fiction and progress requirements.
///
/// This engine is intentionally minimal and deterministic: it does not invent content, it only
/// evaluates payloads and classifications against configured rules.
#[derive(Debug, Clone)]
pub struct PolicyEngine {
    config: Arc<VirtaGitConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContentClassification {
    pub has_fictional_indicators: bool,
    pub has_hypothetical_indicators: bool,
    pub has_theoretical_only_indicators: bool,
    pub has_real_world_anchors: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ProgressType {
    NewCodeAsset,
    ExtendedCodeAsset,
    NewPolicyDocument,
    ConfigRefinement,
    ValidationRuleAddition,
}

#[derive(Debug, Error)]
pub enum PolicyError {
    #[error("non-fiction policy violation: {0}")]
    NonFictionViolation(String),

    #[error("progress requirement violation: {0}")]
    ProgressViolation(String),

    #[error("configuration error: {0}")]
    Config(String),
}

impl PolicyEngine {
    pub fn new(config: Arc<VirtaGitConfig>) -> Result<Self, PolicyError> {
        if !config.policies.non_fiction.enforced {
            return Err(PolicyError::Config(
                "non_fiction policy must be enforced".into(),
            ));
        }
        if !config.interaction_policy.progress_requirement.enforced {
            return Err(PolicyError::Config(
                "progress_requirement policy must be enforced".into(),
            ));
        }
        Ok(Self { config })
    }

    fn non_fiction_rules(&self) -> (&IoPolicies, &PolicySection) {
        (&self.config.io_policies, &self.config.policies)
    }

    /// Enforce non-fiction constraints over a precomputed classification.
    pub fn enforce_non_fiction(
        &self,
        classification: &ContentClassification,
    ) -> Result<(), PolicyError> {
        let (io_policies, policies) = self.non_fiction_rules();
        let nf = &policies.non_fiction;
        let pipeline = &io_policies.sanitization.pipeline;

        // These checks mirror the global Virta-Sys / VSC-ARTEMIS non-fiction rules.[file:1]
        let rules = nf
            .rules
            .as_ref()
            .cloned()
            .unwrap_or_else(|| serde_json::json!({}));

        let allow_fiction = rules
            .get("allow_fiction")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        let allow_hypothetical = rules
            .get("allow_hypothetical")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        let allow_theoretical_only = rules
            .get("allow_theoretical_only")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        let require_real_world_anchor = rules
            .get("require_real_world_anchor")
            .and_then(|v| v.as_bool())
            .unwrap_or(true);

        if !allow_fiction && classification.has_fictional_indicators {
            return Err(PolicyError::NonFictionViolation(
                "fictional indicators detected in content".into(),
            ));
        }
        if !allow_hypothetical && classification.has_hypothetical_indicators {
            return Err(PolicyError::NonFictionViolation(
                "hypothetical indicators detected in content".into(),
            ));
        }
        if !allow_theoretical_only && classification.has_theoretical_only_indicators {
            return Err(PolicyError::NonFictionViolation(
                "theoretical-only indicators detected in content".into(),
            ));
        }
        if require_real_world_anchor && !classification.has_real_world_anchors {
            return Err(PolicyError::NonFictionViolation(
                "content lacks required real-world anchors".into(),
            ));
        }

        // The pipeline is declarative; here we only assert that it is non-empty
        // to ensure sanitization is configured.
        if pipeline.is_empty() {
            return Err(PolicyError::Config(
                "sanitization pipeline must not be empty".into(),
            ));
        }

        Ok(())
    }

    /// Enforce that each interaction is tagged with an acceptable progress type.
    pub fn enforce_progress(&self, progress: &ProgressType) -> Result<(), PolicyError> {
        let progress_policy = &self.config.policies.progress_requirement;
        let allowed = progress_policy
            .acceptable_progress_types
            .as_ref()
            .cloned()
            .unwrap_or_else(|| {
                vec![
                    "new_code_asset".to_string(),
                    "extended_code_asset".to_string(),
                    "new_policy_document".to_string(),
                    "config_refinement".to_string(),
                    "validation_rule_addition".to_string(),
                ]
            });

        let key = match progress {
            ProgressType::NewCodeAsset => "new_code_asset",
            ProgressType::ExtendedCodeAsset => "extended_code_asset",
            ProgressType::NewPolicyDocument => "new_policy_document",
            ProgressType::ConfigRefinement => "config_refinement",
            ProgressType::ValidationRuleAddition => "validation_rule_addition",
        };

        if !allowed.iter().any(|v| v == key) {
            return Err(PolicyError::ProgressViolation(format!(
                "progress type `{}` is not permitted for Virta-Git",
                key
            )));
        }

        Ok(())
    }
}
