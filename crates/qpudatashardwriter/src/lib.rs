//! Generation of empty CSV templates from a schema, and emission of fully
//! validated shards with rcalib, vt, and KER columns appended.

use csv::Writer;
use ecosafety_core::{Corridor, KerScores, lyapunov_residual, compute_ker_window, DeployDecision};
use qpudataschemashard::{Schema, DataShard, Error as SchemaError};
use std::fs::File;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum WriterError {
    #[error("Schema error: {0}")]
    Schema(#[from] SchemaError),
    #[error("CSV error: {0}")]
    Csv(#[from] csv::Error),
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
}

/// Generate an empty CSV template for a given schema.
/// The template includes the four metarows (ALNSHARDID, KERCONTEXT, ALNSPECHASH, EVIDENCEHEX)
/// and the header row, followed by zero data rows.
pub fn generate_template(schema: &Schema) -> Result<String, WriterError> {
    let mut wtr = Writer::from_writer(vec![]);
    let headers = schema.expected_header();

    // Write metarows (placeholders)
    wtr.write_record(["ALNSHARDID", &schema.shard_family])?;
    wtr.write_record(["KERCONTEXT", "PhoenixSpine2026v1"])?;
    wtr.write_record(["ALNSPECHASH", "0000000000000000000000000000000000000000000000000000000000000000"])?;
    wtr.write_record(["EVIDENCEHEX", "0000000000000000000000000000000000000000000000000000000000000000"])?;

    // Header row
    wtr.write_record(&headers)?;

    // No data rows; template ends here.
    wtr.flush()?;
    Ok(String::from_utf8(wtr.into_inner()?).unwrap())
}

/// Write a fully validated shard to a CSV file.
/// This function takes a `DataShard` (which already contains raw records and rcalib),
/// computes vt, KER, trust adjustments, and deploydecision for each row,
/// and writes a new CSV with all columns including the computed governance fields.
pub fn write_validated_shard<P: AsRef<Path>>(
    schema: &Schema,
    data_shard: &DataShard,
    output_path: P,
) -> Result<(), WriterError> {
    let file = File::create(output_path)?;
    let mut wtr = Writer::from_writer(file);

    // Write metarows (placeholders)
    wtr.write_record(["ALNSHARDID", &data_shard.shard_family])?;
    wtr.write_record(["KERCONTEXT", "PhoenixSpine2026v1"])?;
    wtr.write_record(["ALNSPECHASH", "0000000000000000000000000000000000000000000000000000000000000000"])?;
    wtr.write_record(["EVIDENCEHEX", "0000000000000000000000000000000000000000000000000000000000000000"])?;

    // Write header (original plus computed columns)
    let mut full_headers = data_shard.headers.clone();
    full_headers.extend(vec![
        "vt".to_string(),
        "kscore".to_string(),
        "escore".to_string(),
        "rscore".to_string(),
        "dtsensor".to_string(),
        "dtdata".to_string(),
        "kadj".to_string(),
        "eadj".to_string(),
        "deploydecision".to_string(),
    ]);
    wtr.write_record(&full_headers)?;

    // Build corridors from schema for risk coordinates
    let risk_cols: Vec<_> = schema.columns.iter()
        .filter(|c| c.isriskcoord)
        .collect();
    let corridors: Vec<Corridor> = risk_cols.iter().map(|col| {
        // Parse band strings "min,max"
        let parse_band = |b: &Option<String>| -> (f64, f64) {
            if let Some(s) = b {
                let parts: Vec<&str> = s.split(',').collect();
                (parts[0].parse().unwrap(), parts[1].parse().unwrap())
            } else {
                (0.0, 1.0)
            }
        };
        let (safemin, safemax) = parse_band(&col.safeband);
        let (goldmin, goldmax) = parse_band(&col.goldband);
        let (hardmin, hardmax) = parse_band(&col.hardband);
        Corridor {
            safemin, safemax, goldmin, goldmax, hardmin, hardmax,
            lyapweight: col.lyapweight.unwrap_or(1.0),
            channel: col.lyapchannel.clone().unwrap_or_default(),
        }
    }).collect();

    // For each row, compute ecosafety metrics and write full row.
    for (row_idx, record) in data_shard.records.iter().enumerate() {
        let risk_coords = &data_shard.risk_coords_per_row[row_idx];
        let rcalib = data_shard.rcalib_per_row[row_idx];

        // Append rcalib to risk coordinates for Vt calculation
        let mut all_risks = risk_coords.clone();
        all_risks.push(rcalib);
        // Corridors for risk coords + one for rcalib (with weight from schema)
        let rcalib_weight = schema.columns.iter()
            .find(|c| c.colname == "rcalib")
            .and_then(|c| c.lyapweight)
            .unwrap_or(0.8);
        let mut all_corridors = corridors.clone();
        all_corridors.push(Corridor {
            safemin: 0.0, safemax: 0.0,
            goldmin: 0.0, goldmax: 0.04,
            hardmin: 0.13, hardmax: 1.0,
            lyapweight: rcalib_weight,
            channel: "dataquality".to_string(),
        });

        let vt = lyapunov_residual(&all_risks, &all_corridors);
        let max_risk = all_risks.iter().cloned().fold(0.0, f64::max);
        let ker = compute_ker_window(&[vt], max_risk);

        let dtsensor = 0.95; // Placeholder: derived from rsigma_energy
        let dtdata = 1.0 - rcalib;
        let kadj = ker.k * dtsensor * dtdata;
        let eadj = ker.e * dtsensor * dtdata;
        let deploy = ker.deploy_decision(rcalib);

        // Build output row
        let mut out_row = record.clone();
        out_row.push(vt.to_string());
        out_row.push(ker.k.to_string());
        out_row.push(ker.e.to_string());
        out_row.push(ker.r.to_string());
        out_row.push(dtsensor.to_string());
        out_row.push(dtdata.to_string());
        out_row.push(kadj.to_string());
        out_row.push(eadj.to_string());
        out_row.push(format!("{:?}", deploy));
        // evidencehex and signinghex are expected to be in the original record (last two columns)
        // So no need to add them again.

        wtr.write_record(&out_row)?;
    }

    wtr.flush()?;
    Ok(())
}
