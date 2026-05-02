// filename: econet-index/src/migration.rs

use rusqlite::{Connection, params};

pub fn run_migrations(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(
        r#"
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS repo_role_band (
            role_band   TEXT PRIMARY KEY,
            description TEXT NOT NULL
        );

        INSERT OR IGNORE INTO repo_role_band (role_band, description) VALUES
            ('SPINE',    'Core grammar, KER, and ALN schema spine'),
            ('RESEARCH', 'Non-actuating research / shard generation'),
            ('ENGINE',   'Controllers, kernels, HUDs under ecosafety spine'),
            ('MATERIAL', 'Biodegradable materials, species corridors, substrates'),
            ('GOV',      'Governance, finance, routing, value, identity'),
            ('APP',      'End-user or specialized application repo');

        CREATE TABLE IF NOT EXISTS repo (
            repo_id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name             TEXT NOT NULL UNIQUE,
            github_slug      TEXT NOT NULL,
            visibility       TEXT NOT NULL CHECK (visibility IN ('Public','Private')),
            language_primary TEXT NOT NULL,
            role_band        TEXT NOT NULL REFERENCES repo_role_band(role_band),
            description      TEXT,
            last_updated_utc TEXT
        );

        CREATE TABLE IF NOT EXISTS repo_file (
            file_id          INTEGER PRIMARY KEY AUTOINCREMENT,
            repo_id          INTEGER NOT NULL REFERENCES repo(repo_id) ON DELETE CASCADE,
            rel_path         TEXT NOT NULL,
            filename         TEXT NOT NULL,
            ext              TEXT NOT NULL,
            file_kind        TEXT NOT NULL CHECK (
                                file_kind IN ('ALN','CSV','RUST','CPP','C_SHARP','LUA','KOTLIN',
                                              'JS','HTML','DOC','CONFIG','OTHER')
                              ),
            dir_class        TEXT NOT NULL CHECK (
                                dir_class IN ('QPUDATASHARD','PARTICLE','SCHEMA','SRC','DOC','CONFIG','OTHER')
                              ),
            sha256_hex       TEXT,
            bytes_size       INTEGER,
            last_commit_sha  TEXT,
            last_updated_utc TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_repo_file_repo_kind ON repo_file (repo_id, file_kind, dir_class);
        CREATE INDEX IF NOT EXISTS idx_repo_file_relpath   ON repo_file (rel_path);

        CREATE TABLE IF NOT EXISTS aln_schema (
            schema_id        INTEGER PRIMARY KEY AUTOINCREMENT,
            repo_file_id     INTEGER NOT NULL REFERENCES repo_file(file_id) ON DELETE CASCADE,
            schema_name      TEXT NOT NULL,
            version_tag      TEXT,
            title            TEXT,
            description      TEXT,
            category         TEXT,
            spec_hash_hex    TEXT,
            mandatory        INTEGER NOT NULL DEFAULT 0 CHECK (mandatory IN (0,1)),
            deprecated       INTEGER NOT NULL DEFAULT 0 CHECK (deprecated IN (0,1))
        );

        CREATE UNIQUE INDEX IF NOT EXISTS idx_aln_schema_name ON aln_schema(schema_name);

        CREATE TABLE IF NOT EXISTS aln_particle (
            particle_id      INTEGER PRIMARY KEY AUTOINCREMENT,
            schema_id        INTEGER NOT NULL REFERENCES aln_schema(schema_id) ON DELETE CASCADE,
            particle_name    TEXT NOT NULL,
            role             TEXT NOT NULL CHECK (
                                role IN ('RISKVECTOR','CORRIDOR','QPUDATASHARD','DECISION',
                                         'SUBSTRATE','HYDRAULIC_NODE','MOTOR_HEALTH',
                                         'MATERIAL_KINETICS','GOVERNANCE','OTHER')
                              ),
            version_tag      TEXT,
            description      TEXT,
            lyap_channel     TEXT,
            has_ker_fields   INTEGER NOT NULL DEFAULT 0 CHECK (has_ker_fields IN (0,1)),
            has_risk_fields  INTEGER NOT NULL DEFAULT 0 CHECK (has_risk_fields IN (0,1)),
            has_admissibility INTEGER NOT NULL DEFAULT 0 CHECK (has_admissibility IN (0,1))
        );

        CREATE INDEX IF NOT EXISTS idx_particle_role ON aln_particle(role);

        CREATE TABLE IF NOT EXISTS aln_field (
            field_id         INTEGER PRIMARY KEY AUTOINCREMENT,
            particle_id      INTEGER NOT NULL REFERENCES aln_particle(particle_id) ON DELETE CASCADE,
            field_name       TEXT NOT NULL,
            data_type        TEXT NOT NULL,
            units            TEXT,
            is_risk_coord    INTEGER NOT NULL DEFAULT 0 CHECK (is_risk_coord IN (0,1)),
            is_ker_component INTEGER NOT NULL DEFAULT 0 CHECK (is_ker_component IN (0,1)),
            is_coord_index   INTEGER NOT NULL DEFAULT 0 CHECK (is_coord_index IN (0,1)),
            corridor_ref     TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_aln_field_name ON aln_field(field_name);

        CREATE TABLE IF NOT EXISTS corridor_definition (
            corridor_id      INTEGER PRIMARY KEY AUTOINCREMENT,
            varid            TEXT NOT NULL,
            safe             REAL NOT NULL,
            gold             REAL NOT NULL,
            hard             REAL NOT NULL,
            weight           REAL NOT NULL,
            lyap_channel     TEXT NOT NULL,
            mandatory        INTEGER NOT NULL CHECK (mandatory IN (0,1)),
            schema_id        INTEGER REFERENCES aln_schema(schema_id) ON DELETE SET NULL
        );

        CREATE UNIQUE INDEX IF NOT EXISTS idx_corridor_varid ON corridor_definition(varid);

        CREATE TABLE IF NOT EXISTS shard_instance (
            shard_id         INTEGER PRIMARY KEY AUTOINCREMENT,
            repo_file_id     INTEGER NOT NULL REFERENCES repo_file(file_id) ON DELETE CASCADE,
            particle_id      INTEGER REFERENCES aln_particle(particle_id) ON DELETE SET NULL,
            node_id          TEXT,
            asset_type       TEXT,
            medium           TEXT,
            region           TEXT,
            t_start_utc      TEXT,
            t_end_utc        TEXT,
            lane             TEXT,
            k_metric         REAL,
            e_metric         REAL,
            r_metric         REAL,
            vt_max           REAL,
            kerdeployable    INTEGER NOT NULL DEFAULT 0 CHECK (kerdeployable IN (0,1)),
            evidence_hex     TEXT,
            signing_did      TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_shard_node_time ON shard_instance(node_id, t_start_utc, t_end_utc);
        CREATE INDEX IF NOT EXISTS idx_shard_ker_lane  ON shard_instance(lane, kerdeployable, e_metric, r_metric);
        CREATE INDEX IF NOT EXISTS idx_shard_region    ON shard_instance(region);

        CREATE TABLE IF NOT EXISTS knowledge_eco_score (
            score_id         INTEGER PRIMARY KEY AUTOINCREMENT,
            scope_type       TEXT NOT NULL CHECK (
                                scope_type IN ('REPO','FILE','SCHEMA','PARTICLE','SHARD','DOCUMENT')
                              ),
            scope_ref_id     INTEGER NOT NULL,
            k_factor         REAL NOT NULL,
            e_factor         REAL NOT NULL,
            r_factor         REAL NOT NULL,
            rationale        TEXT,
            timestamp_utc    TEXT NOT NULL,
            issued_by        TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_kerscore_scope ON knowledge_eco_score(scope_type, scope_ref_id);
        "#,
    )?;

    seed_example_data(conn)?;
    Ok(())
}

fn seed_example_data(conn: &Connection) -> rusqlite::Result<()> {
    // Insert example repos if they don't exist.
    conn.execute(
        r#"INSERT OR IGNORE INTO repo
           (name, github_slug, visibility, language_primary, role_band, description, last_updated_utc)
           VALUES
           ('EcoNet-CEIM-PhoenixWater', 'Doctor0Evil/EcoNet-CEIM-PhoenixWater',
            'Public', 'Rust', 'ENGINE',
            'Phoenix water CEIM/CPVM kernels and controllers under ecosafety spine',
            '2026-01-08T00:00:00Z')
        "#,
        [],
    )?;

    conn.execute(
        r#"INSERT OR IGNORE INTO repo
           (name, github_slug, visibility, language_primary, role_band, description, last_updated_utc)
           VALUES
           ('BugsLife', 'Doctor0Evil/BugsLife',
            'Public', 'Rust', 'MATERIAL',
            'Eco-friendly pest solutions and biodegradable substrates with hard ecosafety corridors',
            '2026-03-18T00:00:00Z')
        "#,
        [],
    )?;

    // Lookup repo_ids.
    let phoenix_repo_id: i64 = conn.query_row(
        "SELECT repo_id FROM repo WHERE name = 'EcoNet-CEIM-PhoenixWater'",
        [],
        |row| row.get(0),
    )?;

    let bugslife_repo_id: i64 = conn.query_row(
        "SELECT repo_id FROM repo WHERE name = 'BugsLife'",
        [],
        |row| row.get(0),
    )?;

    // Register ALN files (these paths are illustrative; adjust to your tree).
    conn.execute(
        r#"INSERT OR IGNORE INTO repo_file
           (repo_id, rel_path, filename, ext, file_kind, dir_class)
           VALUES
           (?1, 'qpudatashards/particles/HydrologicalBufferPhoenix2026v1.aln',
            'HydrologicalBufferPhoenix2026v1.aln', 'aln', 'ALN', 'QPUDATASHARD')
        "#,
        params![phoenix_repo_id],
    )?;

    conn.execute(
        r#"INSERT OR IGNORE INTO repo_file
           (repo_id, rel_path, filename, ext, file_kind, dir_class)
           VALUES
           (?1, 'qpudatashards/particles/FlowVacSubstrateShard.v1.aln',
            'FlowVacSubstrateShard.v1.aln', 'aln', 'ALN', 'QPUDATASHARD')
        "#,
        params![bugslife_repo_id],
    )?;

    let hydro_file_id: i64 = conn.query_row(
        r#"SELECT file_id FROM repo_file
           WHERE filename = 'HydrologicalBufferPhoenix2026v1.aln'
        "#,
        [],
        |row| row.get(0),
    )?;

    let flowvac_file_id: i64 = conn.query_row(
        r#"SELECT file_id FROM repo_file
           WHERE filename = 'FlowVacSubstrateShard.v1.aln'
        "#,
        [],
        |row| row.get(0),
    )?;

    // Register schemas and particles.
    conn.execute(
        r#"INSERT OR IGNORE INTO aln_schema
           (repo_file_id, schema_name, version_tag, title, description, category, mandatory)
           VALUES
           (?1, 'HydrologicalBufferShard.v1', 'v1',
            'Hydrological Buffer Phoenix 2026',
            'qpudatashard for CEIM/CPVM hydrological buffer nodes in Central AZ',
            'HYDRO', 0)
        "#,
        params![hydro_file_id],
    )?;

    conn.execute(
        r#"INSERT OR IGNORE INTO aln_schema
           (repo_file_id, schema_name, version_tag, title, description, category, mandatory)
           VALUES
           (?1, 'FlowVacSubstrateShard.v1', 'v1',
            'FlowVac biodegradable substrate shard',
            'Material kinetics and toxicity coordinates for FlowVac substrates',
            'FLOWVAC', 0)
        "#,
        params![flowvac_file_id],
    )?;

    let hydro_schema_id: i64 = conn.query_row(
        "SELECT schema_id FROM aln_schema WHERE schema_name = 'HydrologicalBufferShard.v1'",
        [],
        |row| row.get(0),
    )?;

    let flowvac_schema_id: i64 = conn.query_row(
        "SELECT schema_id FROM aln_schema WHERE schema_name = 'FlowVacSubstrateShard.v1'",
        [],
        |row| row.get(0),
    )?;

    conn.execute(
        r#"INSERT OR IGNORE INTO aln_particle
           (schema_id, particle_name, role, version_tag, description,
            lyap_channel, has_ker_fields, has_risk_fields, has_admissibility)
           VALUES
           (?1, 'HydrologicalBufferPhoenix2026v1', 'QPUDATASHARD', 'v1',
            'Phoenix hydrological buffer shard rows for CEIM/CPVM',
            'hydraulics', 1, 1, 1)
        "#,
        params![hydro_schema_id],
    )?;

    conn.execute(
        r#"INSERT OR IGNORE INTO aln_particle
           (schema_id, particle_name, role, version_tag, description,
            lyap_channel, has_ker_fields, has_risk_fields, has_admissibility)
           VALUES
           (?1, 'FlowVacSubstrateShard.v1', 'SUBSTRATE', 'v1',
            'FlowVac substrate batch coordinates: rmassloss,rtox,rmicro,rPFASresid,rcarbon,rbiodiversity',
            'materials', 1, 1, 1)
        "#,
        params![flowvac_schema_id],
    )?;

    let hydro_particle_id: i64 = conn.query_row(
        "SELECT particle_id FROM aln_particle WHERE particle_name = 'HydrologicalBufferPhoenix2026v1'",
        [],
        |row| row.get(0),
    )?;

    let flowvac_particle_id: i64 = conn.query_row(
        "SELECT particle_id FROM aln_particle WHERE particle_name = 'FlowVacSubstrateShard.v1'",
        [],
        |row| row.get(0),
    )?;

    // Example hydrological buffer shard instance (CAP-LP-HBUF-01).
    conn.execute(
        r#"INSERT OR IGNORE INTO shard_instance
           (repo_file_id, particle_id, node_id, asset_type, medium, region,
            t_start_utc, t_end_utc, lane,
            k_metric, e_metric, r_metric, vt_max,
            kerdeployable, evidence_hex, signing_did)
           VALUES
           (?1, ?2,
            'CAP-LP-HBUF-01', 'MixingPump', 'water', 'Phoenix-AZ',
            '2026-01-01T00:00:00Z', '2026-01-31T23:59:59Z', 'PROD',
            0.94, 0.88, 0.12, 0.42,
            1,
            'a1b2c3d4e5f67890',
            'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7')
        "#,
        params![hydro_file_id, hydro_particle_id],
    )?;

    // Example FlowVac substrate shard instance.
    conn.execute(
        r#"INSERT OR IGNORE INTO shard_instance
           (repo_file_id, particle_id, node_id, asset_type, medium, region,
            t_start_utc, t_end_utc, lane,
            k_metric, e_metric, r_metric, vt_max,
            kerdeployable, evidence_hex, signing_did)
           VALUES
           (?1, ?2,
            'FLOWVAC-BATCH-2026-01', 'SubstrateBatch', 'material', 'Lab-CI',
            '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 'RESEARCH',
            0.93, 0.95, 0.12, 0.37,
            1,
            'f0e1d2c3b4a59687',
            'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7')
        "#,
        params![flowvac_file_id, flowvac_particle_id],
    )?;

    // Score the schemas themselves.
    conn.execute(
        r#"INSERT INTO knowledge_eco_score
           (scope_type, scope_ref_id, k_factor, e_factor, r_factor,
            rationale, timestamp_utc, issued_by)
           VALUES
           ('SCHEMA', ?1, 0.95, 0.90, 0.12,
            'HydrologicalBufferShard.v1 reuses CEIM/CPVM and rxVt grammar for Phoenix water nodes',
            '2026-05-02T00:00:00Z',
            'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7')
        "#,
        params![hydro_schema_id],
    )?;

    conn.execute(
        r#"INSERT INTO knowledge_eco_score
           (scope_type, scope_ref_id, k_factor, e_factor, r_factor,
            rationale, timestamp_utc, issued_by)
           VALUES
           ('SCHEMA', ?1, 0.93, 0.95, 0.12,
            'FlowVacSubstrateShard.v1 hard-gates biodegradable substrates on kinetics and toxicity',
            '2026-05-02T00:00:00Z',
            'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7')
        "#,
        params![flowvac_schema_id],
    )?;

    Ok(())
}
