//! Schema ingestion for qpudatashards.
//!
//! Reads an EcoNetSchemaShard2026v1 schema CSV and a corresponding data CSV,
//! validates types and mandatory fields, computes rcalib (data‑quality risk),
//! and extracts RiskCoord columns for ecosafety processing.

use csv::{Reader, Writer};
use ecosafety_core::{Corridor, KerScores, DeployDecision, lyapunov_residual, compute_ker_window};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SchemaColumn {
    pub colindex: usize,
    pub colname: String,
    pub coltype: String,      // "String", "Float", "Int", "DateTime", "RiskCoord", "Residual", "Hex64", "Boolean"
    pub units: Option<String>,
    pub mandator: bool,
    pub isriskcoord: bool,
    pub safeband: Option<String>, // "min,max"
    pub goldband: Option<String>,
    pub hardband: Option<String>,
    pub lyapweight: Option<f64>,
    pub lyapchannel: Option<String>,
}

#[derive(Debug, Clone)]
pub struct Schema {
    pub shard_family: String,
    pub version: String,
    pub columns: Vec<SchemaColumn>,
    // Map colname -> index in columns vec
    name_to_idx: HashMap<String, usize>,
}

impl Schema {
    pub fn from_csv<P: AsRef<Path>>(path: P) -> Result<Self, Error> {
        let mut rdr = Reader::from_path(path)?;
        let mut columns = Vec::new();
        let mut name_to_idx = HashMap::new();

        // Schema CSV header:
        // schemashardid,targetshardfamily,targetversion,colindex,colname,coltype,...
        for (i, result) in rdr.deserialize().enumerate() {
            let record: SchemaRow = result?;
            let col = SchemaColumn {
                colindex: record.colindex,
                colname: record.colname.clone(),
                coltype: record.coltype,
                units: if record.units.is_empty() { None } else { Some(record.units) },
                mandator: record.mandatory,
                isriskcoord: record.isriskcoord,
                safeband: if record.safeband.is_empty() { None } else { Some(record.safeband) },
                goldband: if record.goldband.is_empty() { None } else { Some(record.goldband) },
                hardband: if record.hardband.is_empty() { None } else { Some(record.hardband) },
                lyapweight: record.lyapweight,
                lyapchannel: if record.lyapchannel.is_empty() { None } else { Some(record.lyapchannel) },
            };
            name_to_idx.insert(col.colname.clone(), i);
            columns.push(col);
        }

        // Extract shard family and version from first row (all rows share same targetshardfamily/targetversion)
        let first_row: SchemaRow = {
            let mut rdr = Reader::from_path(path)?;
            rdr.deserialize().next().unwrap()?
        };
        Ok(Schema {
            shard_family: first_row.targetshardfamily,
            version: first_row.targetversion,
            columns,
            name_to_idx,
        })
    }

    pub fn expected_header(&self) -> Vec<String> {
        self.columns.iter().map(|c| c.colname.clone()).collect()
    }
}

#[derive(Debug, Deserialize)]
struct SchemaRow {
    // We only need a subset for Schema construction, but deserialize all.
    schemashardid: String,
    targetshardfamily: String,
    targetversion: String,
    colindex: usize,
    colname: String,
    coltype: String,
    units: String,
    #[serde(deserialize_with = "deserialize_bool")]
    mandator: bool,
    #[serde(deserialize_with = "deserialize_bool")]
    isriskcoord: bool,
    safeband: String,
    goldband: String,
    hardband: String,
    lyapweight: Option<f64>,
    lyapchannel: String,
    // ignore rustsymbol, csymbol, description, citations
    #[serde(skip)]
    _rest: (),
}

fn deserialize_bool<'de, D>(deserializer: D) -> Result<bool, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let s: &str = serde::Deserialize::deserialize(deserializer)?;
    match s {
        "true" => Ok(true),
        "false" => Ok(false),
        _ => Err(serde::de::Error::custom("expected 'true' or 'false'")),
    }
}

/// A parsed data shard, containing both raw records and validated risk coordinates.
#[derive(Debug)]
pub struct DataShard {
    pub shard_family: String,
    pub version: String,
    pub headers: Vec<String>,
    pub records: Vec<Vec<String>>,
    /// Risk coordinates for each row, in the order they appear in the schema.
    pub risk_coords_per_row: Vec<Vec<f64>>,
    /// rcalib score per row (0.0 = perfect, 1.0 = total failure).
    pub rcalib_per_row: Vec<f64>,
}

#[derive(Debug, Error)]
pub enum Error {
    #[error("CSV error: {0}")]
    Csv(#[from] csv::Error),
    #[error("Schema error: {0}")]
    Schema(String),
    #[error("Missing mandatory column '{0}' in data row {1}")]
    MissingMandatory(String, usize),
    #[error("Type mismatch in column '{0}' at row {1}: expected {2}")]
    TypeMismatch(String, usize, String),
}

/// Ingest a data CSV using the given schema.
pub fn ingest_data_shard<P: AsRef<Path>>(
    schema: &Schema,
    data_path: P,
) -> Result<DataShard, Error> {
    let mut rdr = Reader::from_path(data_path)?;
    let headers = rdr.headers()?.clone();
    let expected = schema.expected_header();
    if headers != expected {
        return Err(Error::Schema(format!(
            "Header mismatch: expected {:?}, got {:?}",
            expected,
            headers.iter().collect::<Vec<_>>()
        )));
    }

    let mut records = Vec::new();
    let mut risk_coords_per_row = Vec::new();
    let mut rcalib_per_row = Vec::new();

    // Identify risk coordinate columns
    let risk_cols: Vec<_> = schema.columns.iter()
        .filter(|c| c.isriskcoord)
        .collect();

    for (row_idx, result) in rdr.records().enumerate() {
        let record = result?;
        let fields: Vec<String> = record.iter().map(|s| s.to_string()).collect();
        records.push(fields.clone());

        let mut fault_count = 0;
        let total_fields = schema.columns.len();

        // Validate mandatory and types
        for (col_idx, col) in schema.columns.iter().enumerate() {
            let val = &fields[col_idx];
            if col.mandator && val.is_empty() {
                fault_count += 1;
                // Could return error, but we count faults for rcalib.
                // For strict validation, you might return Err.
            }
            // Basic type check (could be more sophisticated)
            match col.coltype.as_str() {
                "Float" => {
                    if !val.is_empty() && val.parse::<f64>().is_err() {
                        fault_count += 1;
                    }
                }
                "Int" => {
                    if !val.is_empty() && val.parse::<i64>().is_err() {
                        fault_count += 1;
                    }
                }
                "RiskCoord" => {
                    if !val.is_empty() {
                        let r: f64 = val.parse().map_err(|_| {
                            Error::TypeMismatch(col.colname.clone(), row_idx, "RiskCoord".into())
                        })?;
                        if !(0.0..=1.0).contains(&r) {
                            fault_count += 1;
                        }
                    } else if col.mandator {
                        fault_count += 1;
                    }
                }
                _ => {}
            }
        }

        // rcalib = fault_count / total_fields (simple linear normalization)
        let rcalib = fault_count as f64 / total_fields as f64;
        rcalib_per_row.push(rcalib);

        // Extract risk coordinates for this row
        let mut row_risks = Vec::with_capacity(risk_cols.len());
        for col in &risk_cols {
            let val = &fields[col.colindex];
            if val.is_empty() {
                // If missing, treat as 1.0 (max risk)
                row_risks.push(1.0);
            } else {
                let r: f64 = val.parse().unwrap_or(1.0);
                row_risks.push(r.clamp(0.0, 1.0));
            }
        }
        risk_coords_per_row.push(row_risks);
    }

    Ok(DataShard {
        shard_family: schema.shard_family.clone(),
        version: schema.version.clone(),
        headers: headers.iter().map(|s| s.to_string()).collect(),
        records,
        risk_coords_per_row,
        rcalib_per_row,
    })
}
