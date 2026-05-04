// filename: src/lib.rs
// destination: Eco-Fort/crates/econet-governance-api/src/lib.rs
//! Unified governance API for the EcoNet constellation.
//!
//! Exposes typed, queryable access to lane decisions, placement verdicts,
//! topology status, contract verification, and sovereign-upgrade ledgers.
//! Designed for AI agents, CI pipelines, and orchestration clients.

pub mod client;
pub mod models;

pub use client::GovernanceClient;
pub use models::{
    LaneDecision, PlacementVerdict, TopologyStatus, ContractStatus, UpgradeRecord, ShardQuery,
    GovernanceError, Result,
};
