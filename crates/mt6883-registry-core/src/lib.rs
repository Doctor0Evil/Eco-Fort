// filename: crates/mt6883-registry-core/src/lib.rs

#[derive(Debug, Clone)]
pub struct Mt6883Entry {
    pub shardid: i64,
    pub particle_name: String,
    pub category: String,
    pub roh_valid_from: String,
    pub roh_valid_until: Option<String>,
    pub roh_chain_hex: String,
    pub roh_risk: f32,
    pub saferoute_tag: Option<String>,
    pub ker_band: Option<String>,
    pub maintainer_did: String,
}

pub trait Mt6883Query {
    fn safe_active_entries(&self) -> Vec<Mt6883Entry>;
}

impl Mt6883Query for rusqlite::Connection {
    fn safe_active_entries(&self) -> Vec<Mt6883Entry> {
        // Example: only current entries with roh_risk <= 0.13 and PROD/EXPPROD lanes.
        let mut stmt = self
            .prepare(
                r#"
                SELECT m.shardid, m.particle_name, m.category,
                       m.roh_valid_from, m.roh_valid_until,
                       m.roh_chain_hex, m.roh_risk,
                       m.saferoute_tag, m.ker_band, m.maintainer_did
                FROM mt6883_registry m
                JOIN shardinstance s ON s.shardid = m.shardid
                WHERE (m.roh_valid_until IS NULL OR m.roh_valid_until >= datetime('now'))
                  AND m.roh_risk <= 0.13
                  AND s.lane IN ('EXPPROD','PROD')
                "#,
            )
            .expect("prepare query failed");

        let rows = stmt
            .query_map([], |row| {
                Ok(Mt6883Entry {
                    shardid: row.get(0)?,
                    particle_name: row.get(1)?,
                    category: row.get(2)?,
                    roh_valid_from: row.get(3)?,
                    roh_valid_until: row.get(4)?,
                    roh_chain_hex: row.get(5)?,
                    roh_risk: row.get(6)?,
                    saferoute_tag: row.get(7)?,
                    ker_band: row.get(8)?,
                    maintainer_did: row.get(9)?,
                })
            })
            .expect("query_map failed");

        rows.filter_map(Result::ok).collect()
    }
}
