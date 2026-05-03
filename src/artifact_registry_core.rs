// filename artifact_registry_core.rs
// destination Eco-Fort/src/artifact_registry_core.rs

use std::time::SystemTime;

use rusqlite::{params, Connection, Error as SqlError, Row, ToSql};

#[derive(Debug, Clone)]
pub enum Lane {
    Research,
    ExpProd,
    Prod,
}

impl Lane {
    fn as_str(&self) -> &'static str {
        match self {
            Lane::Research => "RESEARCH",
            Lane::ExpProd => "EXPPROD",
            Lane::Prod => "PROD",
        }
    }

    fn from_str(s: &str) -> Option<Self> {
        match s {
            "RESEARCH" => Some(Lane::Research),
            "EXPPROD" => Some(Lane::ExpProd),
            "PROD" => Some(Lane::Prod),
            _ => None,
        }
    }
}

#[derive(Debug, Clone)]
pub enum ArtifactKind {
    Binary,
    Kernel,
    Routine,
    QpuDataShard,
    GovLog,
    HealthcarePlan,
    IndexDb,
    Other(String),
}

impl ArtifactKind {
    fn as_str(&self) -> &str {
        match self {
            ArtifactKind::Binary => "BINARY",
            ArtifactKind::Kernel => "KERNEL",
            ArtifactKind::Routine => "ROUTINE",
            ArtifactKind::QpuDataShard => "QPUDATASHARD",
            ArtifactKind::GovLog => "GOVLOG",
            ArtifactKind::HealthcarePlan => "HEALTHCARE_PLAN",
            ArtifactKind::IndexDb => "INDEX_DB",
            ArtifactKind::Other(s) => s.as_str(),
        }
    }

    fn from_str(s: &str) -> Self {
        match s {
            "BINARY" => ArtifactKind::Binary,
            "KERNEL" => ArtifactKind::Kernel,
            "ROUTINE" => ArtifactKind::Routine,
            "QPUDATASHARD" => ArtifactKind::QpuDataShard,
            "GOVLOG" => ArtifactKind::GovLog,
            "HEALTHCARE_PLAN" => ArtifactKind::HealthcarePlan,
            "INDEX_DB" => ArtifactKind::IndexDb,
            other => ArtifactKind::Other(other.to_string()),
        }
    }
}

#[derive(Debug, Clone)]
pub enum KerBand {
    Safe,
    Guarded,
    Blocked,
    Other(String),
}

impl KerBand {
    fn as_str(&self) -> &str {
        match self {
            KerBand::Safe => "SAFE",
            KerBand::Guarded => "GUARDED",
            KerBand::Blocked => "BLOCKED",
            KerBand::Other(s) => s.as_str(),
        }
    }

    fn from_str(s: &str) -> Self {
        match s {
            "SAFE" => KerBand::Safe,
            "GUARDED" => KerBand::Guarded,
            "BLOCKED" => KerBand::Blocked,
            other => KerBand::Other(other.to_string()),
        }
    }
}

#[derive(Debug, Clone)]
pub struct ArtifactRecord {
    pub artifactid: i64,
    pub repoid: i64,
    pub repofileid: i64,
    pub shardid: Option<i64>,
    pub catalogid: Option<i64>,
    pub mt6883registryid: Option<i64>,

    pub repotarget: String,
    pub destinationpath: String,
    pub filename: String,
    pub fileext: String,
    pub artifactkind: ArtifactKind,
    pub contenthash: String,
    pub sizebytes: Option<i64>,

    pub primaryplane: String,
    pub secondaryplanes: Option<String>,
    pub lane: Lane,
    pub kerband: KerBand,
    pub planecontractid: Option<i64>,
    pub blastradiusid: Option<i64>,

    pub kmetric: Option<f64>,
    pub emetric: Option<f64>,
    pub rmetric: Option<f64>,
    pub vtmax: Option<f64>,
    pub kerdeployable: Option<bool>,

    pub evidencehex: String,
    pub rohanchorhex: Option<String>,
    pub signingdid: String,
    pub provenancehex: Option<String>,

    pub createdutc: String,
    pub updatedutc: String,
    pub active: bool,
}

impl ArtifactRecord {
    fn from_row(row: &Row<'_>) -> Result<Self, SqlError> {
        Ok(ArtifactRecord {
            artifactid: row.get("artifactid")?,
            repoid: row.get("repoid")?,
            repofileid: row.get("repofileid")?,
            shardid: row.get("shardid")?,
            catalogid: row.get("catalogid")?,
            mt6883registryid: row.get("mt6883registryid")?,

            repotarget: row.get("repotarget")?,
            destinationpath: row.get("destinationpath")?,
            filename: row.get("filename")?,
            fileext: row.get("fileext")?,
            artifactkind: ArtifactKind::from_str(&row.get::<_, String>("artifactkind")?),
            contenthash: row.get("contenthash")?,
            sizebytes: row.get("sizebytes")?,

            primaryplane: row.get("primaryplane")?,
            secondaryplanes: row.get("secondaryplanes")?,
            lane: Lane::from_str(&row.get::<_, String>("lane")?)
                .ok_or_else(|| SqlError::FromSqlConversionFailure(0, rusqlite::types::Type::Text, Box::new(std::fmt::Error)))?,
            kerband: KerBand::from_str(&row.get::<_, String>("kerband")?),
            planecontractid: row.get("planecontractid")?,
            blastradiusid: row.get("blastradiusid")?,

            kmetric: row.get("kmetric")?,
            emetric: row.get("emetric")?,
            rmetric: row.get("rmetric")?,
            vtmax: row.get("vtmax")?,
            kerdeployable: row.get::<_, Option<i64>>("kerdeployable")?
                .map(|v| v != 0),

            evidencehex: row.get("evidencehex")?,
            rohanchorhex: row.get("rohanchorhex")?,
            signingdid: row.get("signingdid")?,
            provenancehex: row.get("provenancehex")?,

            createdutc: row.get("createdutc")?,
            updatedutc: row.get("updatedutc")?,
            active: row.get::<_, i64>("active")? != 0,
        })
    }
}

#[derive(Debug, Clone)]
pub struct ProvenanceRecord {
    pub provenanceid: i64,
    pub artifactid: i64,

    pub cirunid: String,
    pub workflowfile: String,
    pub repo: String,
    pub energymode: String,
    pub status: String,
    pub sharddbpath: Option<String>,
    pub shardcount: Option<i64>,

    pub lane: Lane,
    pub kmetric: Option<f64>,
    pub emetric: Option<f64>,
    pub rmetric: Option<f64>,
    pub vtmax: Option<f64>,
    pub kerdeployable: Option<bool>,
    pub rtopology: Option<f64>,
    pub wtopology: Option<f64>,
    pub planecontractid: Option<i64>,

    pub evidencehex: String,
    pub rohanchorhex: Option<String>,
    pub signingdid: String,
    pub timestamputc: String,
}

impl ProvenanceRecord {
    fn from_row(row: &Row<'_>) -> Result<Self, SqlError> {
        Ok(ProvenanceRecord {
            provenanceid: row.get("provenanceid")?,
            artifactid: row.get("artifactid")?,
            cirunid: row.get("cirunid")?,
            workflowfile: row.get("workflowfile")?,
            repo: row.get("repo")?,
            energymode: row.get("energymode")?,
            status: row.get("status")?,
            sharddbpath: row.get("sharddbpath")?,
            shardcount: row.get("shardcount")?,

            lane: Lane::from_str(&row.get::<_, String>("lane")?)
                .ok_or_else(|| SqlError::FromSqlConversionFailure(0, rusqlite::types::Type::Text, Box::new(std::fmt::Error)))?,
            kmetric: row.get("kmetric")?,
            emetric: row.get("emetric")?,
            rmetric: row.get("rmetric")?,
            vtmax: row.get("vtmax")?,
            kerdeployable: row.get::<_, Option<i64>>("kerdeployable")?
                .map(|v| v != 0),
            rtopology: row.get("rtopology")?,
            wtopology: row.get("wtopology")?,
            planecontractid: row.get("planecontractid")?,

            evidencehex: row.get("evidencehex")?,
            rohanchorhex: row.get("rohanchorhex")?,
            signingdid: row.get("signingdid")?,
            timestamputc: row.get("timestamputc")?,
        })
    }
}

#[derive(Debug)]
pub struct ArtifactRegistryCore<'c> {
    conn: &'c Connection,
}

impl<'c> ArtifactRegistryCore<'c> {
    pub fn new(conn: &'c Connection) -> Self {
        ArtifactRegistryCore { conn }
    }

    pub fn get_artifact_by_id(&self, artifactid: i64) -> Result<Option<ArtifactRecord>, SqlError> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM artifactregistry WHERE artifactid = ?1",
        )?;
        let mut rows = stmt.query(params![artifactid])?;
        if let Some(row) = rows.next()? {
            Ok(Some(ArtifactRecord::from_row(&row)?))
        } else {
            Ok(None)
        }
    }

    pub fn find_active_artifacts_by_repo_kind(
        &self,
        repoid: i64,
        kind: ArtifactKind,
    ) -> Result<Vec<ArtifactRecord>, SqlError> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM artifactregistry
             WHERE repoid = ?1 AND artifactkind = ?2 AND active = 1",
        )?;
        let iter = stmt.query_map(params![repoid, kind.as_str()], |row| {
            ArtifactRecord::from_row(row)
        })?;
        let mut out = Vec::new();
        for rec in iter {
            out.push(rec?);
        }
        Ok(out)
    }

    pub fn find_latest_provenance_for_artifact(
        &self,
        artifactid: i64,
    ) -> Result<Option<ProvenanceRecord>, SqlError> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM artifactprovenance
             WHERE artifactid = ?1
             ORDER BY timestamputc DESC
             LIMIT 1",
        )?;
        let mut rows = stmt.query(params![artifactid])?;
        if let Some(row) = rows.next()? {
            Ok(Some(ProvenanceRecord::from_row(&row)?))
        } else {
            Ok(None)
        }
    }

    pub fn list_artifacts_for_lane_plane(
        &self,
        lane: Lane,
        primaryplane: &str,
    ) -> Result<Vec<ArtifactRecord>, SqlError> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM artifactregistry
             WHERE lane = ?1 AND primaryplane = ?2 AND active = 1",
        )?;
        let iter = stmt.query_map(params![lane.as_str(), primaryplane], |row| {
            ArtifactRecord::from_row(row)
        })?;
        let mut out = Vec::new();
        for rec in iter {
            out.push(rec?);
        }
        Ok(out)
    }

    pub fn insert_artifact(
        &self,
        rec: &ArtifactRecord,
    ) -> Result<i64, SqlError> {
        let now = current_utc_iso8601();
        self.conn.execute(
            "INSERT INTO artifactregistry (
               repoid, repofileid, shardid, catalogid, mt6883registryid,
               repotarget, destinationpath, filename, fileext, artifactkind,
               contenthash, sizebytes,
               primaryplane, secondaryplanes, lane, kerband,
               planecontractid, blastradiusid,
               kmetric, emetric, rmetric, vtmax, kerdeployable,
               evidencehex, rohanchorhex, signingdid, provenancehex,
               createdutc, updatedutc, active
             ) VALUES (
               ?1, ?2, ?3, ?4, ?5,
               ?6, ?7, ?8, ?9, ?10,
               ?11, ?12,
               ?13, ?14, ?15, ?16,
               ?17, ?18,
               ?19, ?20, ?21, ?22, ?23,
               ?24, ?25, ?26, ?27,
               ?28, ?29, ?30
             )",
            params![
                rec.repoid,
                rec.repofileid,
                rec.shardid,
                rec.catalogid,
                rec.mt6883registryid,
                rec.repotarget,
                rec.destinationpath,
                rec.filename,
                rec.fileext,
                rec.artifactkind.as_str(),
                rec.contenthash,
                rec.sizebytes,
                rec.primaryplane,
                rec.secondaryplanes,
                rec.lane.as_str(),
                rec.kerband.as_str(),
                rec.planecontractid,
                rec.blastradiusid,
                rec.kmetric,
                rec.emetric,
                rec.rmetric,
                rec.vtmax,
                rec.kerdeployable.map(bool_to_i64),
                rec.evidencehex,
                rec.rohanchorhex,
                rec.signingdid,
                rec.provenancehex,
                now.as_str(),
                now.as_str(),
                bool_to_i64(rec.active),
            ],
        )?;
        Ok(self.conn.last_insert_rowid())
    }

    pub fn record_provenance(
        &self,
        artifactid: i64,
        prov: &ProvenanceRecord,
    ) -> Result<i64, SqlError> {
        self.conn.execute(
            "INSERT INTO artifactprovenance (
               artifactid,
               cirunid, workflowfile, repo, energymode, status,
               sharddbpath, shardcount,
               lane, kmetric, emetric, rmetric, vtmax, kerdeployable,
               rtopology, wtopology, planecontractid,
               evidencehex, rohanchorhex, signingdid, timestamputc
             ) VALUES (
               ?1,
               ?2, ?3, ?4, ?5, ?6,
               ?7, ?8,
               ?9, ?10, ?11, ?12, ?13, ?14,
               ?15, ?16, ?17,
               ?18, ?19, ?20, ?21
             )",
            params![
                artifactid,
                prov.cirunid,
                prov.workflowfile,
                prov.repo,
                prov.energymode,
                prov.status,
                prov.sharddbpath,
                prov.shardcount,
                prov.lane.as_str(),
                prov.kmetric,
                prov.emetric,
                prov.rmetric,
                prov.vtmax,
                prov.kerdeployable.map(bool_to_i64),
                prov.rtopology,
                prov.wtopology,
                prov.planecontractid,
                prov.evidencehex,
                prov.rohanchorhex,
                prov.signingdid,
                prov.timestamputc,
            ],
        )?;
        Ok(self.conn.last_insert_rowid())
    }
}

fn bool_to_i64(b: bool) -> i64 {
    if b { 1 } else { 0 }
}

fn current_utc_iso8601() -> String {
    // Simple placeholder; in production you can use chrono if desired.
    // For now, fall back to RFC3339-style string based on SystemTime.
    let now = SystemTime::now();
    let ts = now.duration_since(SystemTime::UNIX_EPOCH).unwrap_or_default().as_secs();
    format!("1970-01-01T00:00:{:02}Z", ts % 60)
}
