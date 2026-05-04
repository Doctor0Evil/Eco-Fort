// filename: src/client.rs
// destination: Eco-Fort/crates/econet-governance-api/src/client.rs
use chrono::Utc;
use rusqlite::{params, Connection};
use std::sync::Mutex;

use crate::models::*;

pub struct GovernanceClient {
    conn: Mutex<Connection>,
}

impl GovernanceClient {
    pub fn new(db_path: &str) -> Result<Self> {
        let conn = Connection::open(db_path)?;
        conn.execute_batch("PRAGMA foreign_keys = ON;")?;
        Ok(Self { conn: Mutex::new(conn) })
    }

    pub fn check_lane(&self, workload_id: &str, target_lane: &str) -> Result<LaneDecision> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT workload_id, target_lane, is_admissible, k_avg, e_avg, r_avg, vt_trend, created_utc
             FROM vlane_admissibility
             WHERE workload_id = ?1 AND target_lane = ?2
             ORDER BY created_utc DESC LIMIT 1"
        )?;
        stmt.query_row(params![workload_id, target_lane], |row| {
            Ok(LaneDecision {
                workload_id: row.get(0)?,
                target_lane: row.get(1)?,
                is_admissible: row.get::<_, i64>(2)? != 0,
                k_avg: row.get(3)?,
                e_avg: row.get(4)?,
                e_avg: row.get(4)?,
                r_avg: row.get(5)?,
                vt_trend: row.get(6)?,
                issued_utc: row.get(7)?,
            })
        }).map_err(|_| GovernanceError::NotFound(format!("Lane decision for {} -> {}", workload_id, target_lane)))
    }

    pub fn get_placement_advice(&self, workload_id: &str, node_id: &str) -> Result<PlacementVerdict> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT workload_id, node_id, admissible, j_cost, non_offsettable_ok, created_utc
             FROM virta_placement_verdict
             WHERE workload_id = ?1 AND node_id = ?2
             ORDER BY created_utc DESC LIMIT 1"
        )?;
        stmt.query_row(params![workload_id, node_id], |row| {
            Ok(PlacementVerdict {
                workload_id: row.get(0)?,
                node_id: row.get(1)?,
                admissible: row.get::<_, i64>(2)? != 0,
                j_cost: row.get(3)?,
                non_offsettable_ok: row.get::<_, i64>(4)? != 0,
                issued_utc: row.get(5)?,
            })
        }).map_err(|_| GovernanceError::NotFound(format!("Placement verdict for {} on {}", workload_id, node_id)))
    }

    pub fn get_topology_status(&self, scope_kind: &str, scope_ref: &str) -> Result<TopologyStatus> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT scope_kind, scope_ref, r_topology, n_missing_manifest, n_mislabel_role, run_utc
             FROM topology_audit_run
             WHERE scope_kind = ?1 AND scope_ref = ?2
             ORDER BY run_utc DESC LIMIT 1"
        )?;
        stmt.query_row(params![scope_kind, scope_ref], |row| {
            Ok(TopologyStatus {
                scope_kind: row.get(0)?,
                scope_ref: row.get(1)?,
                r_topology: row.get(2)?,
                n_missing_manifest: row.get(3)?,
                n_mislabel_role: row.get(4)?,
                last_audit_utc: row.get(5)?,
            })
        }).map_err(|_| GovernanceError::NotFound(format!("Topology audit for {} {}", scope_kind, scope_ref)))
    }

    pub fn verify_contract(&self, workload_id: &str) -> Result<ContractStatus> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT workload_id, repo_name, trait_name, verified_status, compliance_state
             FROM v_contract_verification_summary
             WHERE workload_id = ?1 LIMIT 1"
        )?;
        stmt.query_row(params![workload_id], |row| {
            Ok(ContractStatus {
                workload_id: row.get(0)?,
                repo_name: row.get(1)?,
                trait_name: row.get(2)?,
                verified_status: row.get(3)?,
                compliance_state: row.get(4)?,
            })
        }).map_err(|_| GovernanceError::NotFound(format!("Contract status for {}", workload_id)))
    }

    pub fn record_upgrade(&self, record: &UpgradeRecord) -> Result<i64> {
        let conn = self.conn.lock().unwrap();
        let monotone_ok = (record.k_after >= record.k_before - 1e-6)
            && (record.e_after >= record.e_before - 1e-6)
            && (record.r_after <= record.r_before + 1e-6);
        let lyapunov_ok = record.vt_after <= record.vt_before + 1e-6;
        let status = if monotone_ok && lyapunov_ok { "APPROVED" } else { "REJECTED" };
        let now = Utc::now().to_rfc3339();

        conn.execute(
            "INSERT INTO virta_upgrade_ledger (
                target_scope, target_ref, version_to, initiated_utc,
                k_before, e_before, r_before, vt_before,
                k_after, e_after, r_after, vt_after,
                monotone_ok, lyapunov_ok, authorized_did,
                evidence_before_hex, evidence_after_hex, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            params![
                record.target_scope, record.target_ref, record.version_to, now,
                record.k_before, record.e_before, record.r_before, record.vt_before,
                record.k_after, record.e_after, record.r_after, record.vt_after,
                monotone_ok as i64, lyapunov_ok as i64, record.authorized_did,
                record.evidence_before_hex, record.evidence_after_hex, status
            ],
        )?;
        Ok(conn.last_insert_rowid())
    }
}
