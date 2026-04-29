use std::fs::File;
use std::io::Read;
use std::path::PathBuf;
use std::sync::Arc;

use anyhow::Result;
use chrono::{DateTime, Utc};
use clap::{Parser, Subcommand};
use virta_git::{
    core,
    services::compliance_service::ComplianceService,
    core::policy_engine::PolicyEngine,
    core::repo_registry::RepoRegistry,
    core::authorship_registry::AuthorshipRegistry,
    VirtaGitConfig,
};

/// Virta-Git CLI entrypoint.
/// - Loads `virta-git.config.json`
/// - Initializes registries and policy engine
/// - Provides experimental energy-aware cross-repo / cross-machine optimization helpers.
#[derive(Parser, Debug)]
#[command(name = "virta-git")]
#[command(version = "0.1.0")]
#[command(about = "Virta-Git: non-fiction, policy-enforced Git source-of-truth for Virta-Sys and VSC-ARTEMIS.")]
struct Cli {
    /// Path to virta-git.config.json
    #[arg(long, default_value = "virta-git.config.json")]
    config: PathBuf,

    /// Root directory where tracked repositories are materialized
    #[arg(long, default_value = "./virta-git-repos")]
    repo_root: PathBuf,

    /// Root directory for Virta-Git storage (authorship, logs, etc.)
    #[arg(long, default_value = "./virta-git-storage")]
    storage_root: PathBuf,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Validate latest commits of all tracked repositories.
    ValidateLatest,

    /// Experimental: compute cross-repo energy optimization plan.
    ///
    /// This is aligned with Virta-Sys VirtualClusterOrchestrator concepts and is
    /// intended to reduce physical machine energy output while preserving full capability
    /// when an AI-chat triggers a run.[file:1]
    EnergyPlan {
        /// Total physical machines participating in the pool
        #[arg(long)]
        total_machines: u32,

        /// Baseline energy output per machine in milli-watt-z (mwz) in mode X
        #[arg(long)]
        baseline_x_mwz: f64,

        /// Baseline energy output per machine in milli-watt-z (mwz) in mode Y
        #[arg(long)]
        baseline_y_mwz: f64,

        /// Target utilization percentage per machine (0.0 - 1.0)
        #[arg(long, default_value = "0.7")]
        target_utilization: f64,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    let config = load_config(&cli.config)?;
    config.validate_strict_policies().map_err(|e| anyhow::anyhow!(e))?;
    let config = Arc::new(config);

    match &cli.command {
        Commands::ValidateLatest => {
            let rt = tokio::runtime::Runtime::new()?;
            rt.block_on(run_validate_latest(config, &cli.repo_root, &cli.storage_root))?;
        }
        Commands::EnergyPlan {
            total_machines,
            baseline_x_mwz,
            baseline_y_mwz,
            target_utilization,
        } => {
            run_energy_plan(
                *total_machines,
                *baseline_x_mwz,
                *baseline_y_mwz,
                *target_utilization,
            )?;
        }
    }

    Ok(())
}

fn load_config(path: &PathBuf) -> Result<VirtaGitConfig> {
    let mut file = File::open(path)?;
    let mut buf = String::new();
    file.read_to_string(&mut buf)?;
    let cfg: VirtaGitConfig = serde_json::from_str(&buf)?;
    Ok(cfg)
}

async fn run_validate_latest(
    config: Arc<VirtaGitConfig>,
    repo_root: &PathBuf,
    storage_root: &PathBuf,
) -> Result<()> {
    let repo_registry = Arc::new(RepoRegistry::new(Arc::clone(&config), repo_root)?);
    repo_registry.materialize_all().await?;

    let authorship_registry = Arc::new(AuthorshipRegistry::new(Arc::clone(&config), storage_root)?);
    authorship_registry.load().await?;

    let policy_engine = Arc::new(PolicyEngine::new(Arc::clone(&config))?);

    let compliance = ComplianceService::new(
        Arc::clone(&config),
        Arc::clone(&repo_registry),
        Arc::clone(&authorship_registry),
        Arc::clone(&policy_engine),
    );

    let reports = compliance.validate_all_latest().await?;
    for r in reports {
        println!(
            "Repo={} Commit={} non_fiction_ok={} progress_ok={} authorship_record_id={}",
            r.repository_id,
            r.commit_id,
            r.non_fiction_ok,
            r.progress_ok,
            r.authorship_record_id
                .as_deref()
                .unwrap_or("NONE")
        );
    }

    Ok(())
}

/// Experimental energy model parameters for cross-repo / cross-machine optimization.[file:1]
#[derive(Debug, Clone)]
struct EnergyOptimizationParams {
    total_machines: u32,
    baseline_x_mwz: f64,
    baseline_y_mwz: f64,
    target_utilization: f64,
}

/// Experimental energy optimization result.
#[derive(Debug, Clone)]
struct EnergyOptimizationResult {
    machine_energy_x_mwz: f64,
    machine_energy_y_mwz: f64,
    global_energy_reduction_mwz: f64,
    per_machine_savings_mwz: f64,
    effective_start_time: DateTime<Utc>,
}

/// Compute a simple, deterministic offset model:
/// - Start from baseline X and Y per machine (mwz).
/// - Apply utilization factor and cross-repo scheduling to reduce per-machine output.
/// - Keep full capability when AI-chat triggers runs by assuming staggered, non-overlapping
///   workloads with precise timing (no gaps in connectors).[file:1]
fn run_energy_plan(
    total_machines: u32,
    baseline_x_mwz: f64,
    baseline_y_mwz: f64,
    target_utilization: f64,
) -> Result<()> {
    let params = EnergyOptimizationParams {
        total_machines,
        baseline_x_mwz,
        baseline_y_mwz,
        target_utilization,
    };

    let result = compute_energy_offsets(&params);

    println!("=== Virta-Git Experimental Energy Plan ===");
    println!("total_machines              = {}", total_machines);
    println!("baseline_x_mwz_per_machine  = {:.4}", baseline_x_mwz);
    println!("baseline_y_mwz_per_machine  = {:.4}", baseline_y_mwz);
    println!("target_utilization          = {:.2}", target_utilization);
    println!("--- calculated offsets ---");
    println!(
        "optimized_x_mwz_per_machine = {:.4}",
        result.machine_energy_x_mwz
    );
    println!(
        "optimized_y_mwz_per_machine = {:.4}",
        result.machine_energy_y_mwz
    );
    println!(
        "per_machine_savings_mwz     = {:.4}",
        result.per_machine_savings_mwz
    );
    println!(
        "global_energy_reduction_mwz = {:.4}",
        result.global_energy_reduction_mwz
    );
    println!(
        "effective_start_time_utc    = {}",
        result.effective_start_time.to_rfc3339()
    );

    Ok(())
}

/// Deterministic energy offset computation:
/// - x_out = baseline_x * target_utilization
/// - y_out = baseline_y * target_utilization
/// - savings per machine = (baseline_x + baseline_y) - (x_out + y_out)
/// - global reduction = savings_per_machine * total_machines
///
/// This reflects a cross-repo / cross-machine connector where workloads are staggered
/// to keep machines at target utilization instead of peak all the time, while still
/// allowing full capacity when needed.[file:1]
fn compute_energy_offsets(params: &EnergyOptimizationParams) -> EnergyOptimizationResult {
    let x_out = params.baseline_x_mwz * params.target_utilization;
    let y_out = params.baseline_y_mwz * params.target_utilization;

    let baseline_sum = params.baseline_x_mwz + params.baseline_y_mwz;
    let optimized_sum = x_out + y_out;

    let per_machine_savings = baseline_sum - optimized_sum;
    let global_reduction = per_machine_savings * params.total_machines as f64;

    EnergyOptimizationResult {
        machine_energy_x_mwz: x_out,
        machine_energy_y_mwz: y_out,
        global_energy_reduction_mwz: global_reduction,
        per_machine_savings_mwz: per_machine_savings,
        effective_start_time: Utc::now(),
    }
}
