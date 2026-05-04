// filename artifactregistrycore.rs
// destination Eco-Fort/src/artifactregistrycore.rs

use rusqlite::{params, Connection, Error as SqlError, Row};
use std::time::SystemTime;

#[derive(Debug, Clone)]
pub enum Lane {
    Research,
    ExpProd,
    Prod,
}

impl Lane {
    pub fn as_str(&self) -> &'static str {
        match self {
            Lane::Research => "RESEARCH",
            Lane::ExpProd  => "EXPPROD",
            Lane::Prod     => "PROD",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "RESEARCH" => Some(Lane::Research),
            "EXPPROD"  => Some(Lane::ExpProd),
            "PROD"     => Some(Lane::Prod),
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
    pub fn as_str(&self) -> &str {
        match self {
            ArtifactKind::Binary         => "BINARY",
            ArtifactKind::Kernel         => "KERNEL",
            ArtifactKind::Routine        => "ROUTINE",
            ArtifactKind::QpuDataShard   => "QPUDATASHARD",
            ArtifactKind::GovLog         => "GOVLOG",
            ArtifactKind::HealthcarePlan => "HEALTHCAREPLAN",
            ArtifactKind::IndexDb        => "INDEXDB",
            ArtifactKind::Other(s)       => s.as_str(),
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "BINARY"         => ArtifactKind::Binary,
            "KERNEL"         => ArtifactKind::Kernel,
            "ROUTINE"        => ArtifactKind::Routine,
            "QPUDATASHARD"   => ArtifactKind::QpuDataShard,
            "GOVLOG"         => ArtifactKind::GovLog,
            "HEALTHCAREPLAN" => ArtifactKind::HealthcarePlan,
            "INDEXDB"        => ArtifactKind::IndexDb,
            other            => ArtifactKind::Other(other.to_string()),
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
    pub fn as_str(&self) -> &str {
        match self {
            KerBand::Safe      => "SAFE",
            KerBand::Guarded   => "GUARDED",
            KerBand::Blocked   => "BLOCKED",
            KerBand::Other(s)  => s.as_str(),
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "SAFE"    => KerBand::Safe,
            "GUARDED" => KerBand::Guarded,
            "BLOCKED" => KerBand::Blocked,
            other     => KerBand::Other(other.to_string()),
        }
    }
}

#[derive(Debug, Clone)]
pub struct ArtifactRecord {
    pub artifactid:        i64,
    pub repoid:            i64,
    pub repofileid:        i64,
    pub shardid:           Option<i64>,
    pub catalogid:         Option<i64>,
    pub mt6883registryid:  Option<i64>,

    pub repotarget:        String,
    pub destinationpath:   String,
    pub filename:          String,
    pub fileext:           String,
    pub artifactkind:      ArtifactKind,
    pub contenthash:       String,
    pub sizebytes:         Option<i64>,

    pub primaryplane:      String,
    pub secondaryplanes:   Option<String>,
    pub lane:              Lane,
    pub kerband:           KerBand,
    pub planecontractid:   Option<i64>,
    pub blastradiusid:     Option<i64>,

    pub kmetric:           Option<f64>,
    pub emetric:           Option<f64>,
    pub rmetric:           Option<f64>,
    pub vtmax:             Option<f64>,
    pub kerdeployable:     bool,

    pub evidencehex:       String,
    pub rohanchorhex:      Option<String>,
    pub signingdid:        String,
    pub provenancehex:     Option<String>,

    pub createdutc:        String,
    pub updatedutc:        String,
    pub active:            bool,
}

impl ArtifactRecord {
    fn from_row(row: &Row<'_>) -> Result<Self, SqlError> {
        let lane_str: String    = row.get("lane")?;
        let kerband_str: String = row.get("kerband")?;
        let kind_str: String    = row.get("artifactkind")?;
        let kerdeployable_raw: Option<i64> = row.get("kerdeployable")?;
        let active_raw: i64               = row.get("active")?;

        Ok(ArtifactRecord {
            artifactid:       row.get("artifactid")?,
            repoid:           row.get("repoid")?,
            repofileid:       row.get("repofileid")?,
            shardid:          row.get("shardid")?,
            catalogid:        row.get("catalogid")?,
            mt6883registryid: row.get("mt6883registryid")?,
            repotarget:       row.get("repotarget")?,
            destinationpath:  row.get("destinationpath")?,
            filename:         row.get("filename")?,
            fileext:          row.get("fileext")?,
            artifactkind:     ArtifactKind::from_str(&kind_str),
            contenthash:      row.get("contenthash")?,
            sizebytes:        row.get("sizebytes")?,
            primaryplane:     row.get("primaryplane")?,
            secondaryplanes:  row.get("secondaryplanes")?,
            lane:             Lane::from_str(&lane_str)
                                 .ok_or_else(|| SqlError::FromSqlConversionFailure(
                                     0, rusqlite::types::Type::Text,
                                     Box::new(std::fmt::Error)
                                 ))?,
            kerband:          KerBand::from_str(&kerband_str),
            planecontractid:  row.get("planecontractid")?,
            blastradiusid:    row.get("blastradiusid")?,
            kmetric:          row.get("kmetric")?,
            emetric:          row.get("emetric")?,
            rmetric:          row.get("rmetric")?,
            vtmax:            row.get("vtmax")?,
            kerdeployable:    kerdeployable_raw.map(|v| v != 0).unwrap_or(false),
            evidencehex:      row.get("evidencehex")?,
            rohanchorhex:     row.get("rohanchorhex")?,
            signingdid:       row.get("signingdid")?,
            provenancehex:    row.get("provenancehex")?,
            createdutc:       row.get("createdutc")?,
            updatedutc:       row.get("updatedutc")?,
            active:           active_raw != 0,
        })
    }
}

#[derive(Debug, Clone)]
pub struct ProvenanceRecord {
    pub provenanceid:    i64,
    pub artifactid:      i64,
    pub cirunid:         String,
    pub workflowfile:    String,
    pub repo:            String,
    pub energymode:      String,
    pub status:          String,
    pub sharddbpath:     Option<String>,
    pub shardcount:      Option<i64>,

    pub lane:            Lane,
    pub kmetric:         Option<f64>,
    pub emetric:         Option<f64>,
    pub rmetric:         Option<f64>,
    pub vtmax:           Option<f64>,
    pub kerdeployable:   Option<bool>,
    pub rtopology:       Option<f64>,
    pub wtopology:       Option<f64>,
    pub planecontractid: Option<i64>,
    pub evidencehex:     String,
    pub rohanchorhex:    Option<String>,
    pub signingdid:      String,
    pub timestamputc:    String,
}

impl ProvenanceRecord {
    fn from_row(row: &Row<'_>) -> Result<Self, SqlError> {
        let lane_str: String = row.get("lane")?;
        let kerdeployable_raw: Option<i64> = row.get("kerdeployable")?;

        Ok(ProvenanceRecord {
            provenanceid:    row.get("provenanceid")?,
            artifactid:      row.get("artifactid")?,
            cirunid:         row.get("cirunid")?,
            workflowfile:    row.get("workflowfile")?,
            repo:            row.get("repo")?,
            energymode:      row.get("energymode")?,
            status:          row.get("status")?,
            sharddbpath:     row.get("sharddbpath")?,
            shardcount:      row.get("shardcount")?,
            lane:            Lane::from_str(&lane_str)
                                 .ok_or_else(|| SqlError::FromSqlConversionFailure(
                                     0, rusqlite::types::Type::Text,
                                     Box::new(std::fmt::Error)
                                 ))?,
            kmetric:         row.get("kmetric")?,
            emetric:         row.get("emetric")?,
            rmetric:         row.get("rmetric")?,
            vtmax:           row.get("vtmax")?,
            kerdeployable:   kerdeployable_raw.map(|v| v != 0),
            rtopology:       row.get("rtopology")?,
            wtopology:       row.get("wtopology")?,
            planecontractid: row.get("planecontractid")?,
            evidencehex:     row.get("evidencehex")?,
            rohanchorhex:    row.get("rohanchorhex")?,
            signingdid:      row.get("signingdid")?,
            timestamputc:    row.get("timestamputc")?,
        })
    }
}

#[derive(Debug)]
pub struct ArtifactRegistryCore<'a> {
    conn: &'a Connection,
}

impl<'a> ArtifactRegistryCore<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        ArtifactRegistryCore { conn }
    }

    pub fn get_artifact_by_id(&self, artifactid: i64) -> Result<Option<ArtifactRecord>, SqlError> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM artifactregistry WHERE artifactid = ?1"
        )?;
        let mut rows = stmt.query(params![artifactid])?;
        if let Some(row) = rows.next()? {
            Ok(Some(ArtifactRecord::from_row(row)?))
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
             WHERE repoid = ?1 AND artifactkind = ?2 AND active = 1"
        )?;
        let mut rows = stmt.query(params![repoid, kind.as_str()])?;
        let mut out = Vec::new();
        while let Some(row) = rows.next()? {
            out.push(ArtifactRecord::from_row(row)?);
        }
        Ok(out)
    }

    pub fn latest_provenance_for_artifact(
        &self,
        artifactid: i64,
    ) -> Result<Option<ProvenanceRecord>, SqlError> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM artifactprovenance
             WHERE artifactid = ?1
             ORDER BY timestamputc DESC
             LIMIT 1"
        )?;
        let mut rows = stmt.query(params![artifactid])?;
        if let Some(row) = rows.next()? {
            Ok(Some(ProvenanceRecord::from_row(row)?))
        } else {
            Ok(None)
        }
    }

    pub fn insert_artifact(&self, rec: &ArtifactRecord) -> Result<i64, SqlError> {
        let now = iso8601_now();
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
             )
             VALUES (
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
                if rec.kerdeployable { 1 } else { 0 },
                rec.evidencehex,
                rec.rohanchorhex,
                rec.signingdid,
                rec.provenancehex,
                now.as_str(),
                now.as_str(),
                1_i64,
            ],
        )?;
        Ok(self.conn.last_insert_rowid())
    }
}

fn iso8601_now() -> String {
    let now = SystemTime::now();
    let datetime: chrono::DateTime<chrono::Utc> = now.into();
    datetime.to_rfc3339()
}
