-- filename db_qpu_citizen_continuity.sql
-- destination Eco-Fort/db/db_qpu_citizen_continuity.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS qpu_citizen_continuity (
    citizen_id                 TEXT PRIMARY KEY,    -- pseudonymous citizen id
    hardware_id                INTEGER
                                   REFERENCES qpu_virtual_hardware(hardware_id),
    augmentation_profile       TEXT NOT NULL,       -- 'mt6883-handset','mt6883-hud'
    continuity_contract        TEXT NOT NULL,       -- policy id / contract name
    min_continuity_window_secs INTEGER NOT NULL,   -- minimum uninterrupted operation
    max_state_gap_secs         INTEGER NOT NULL,   -- max allowed gap between state samples
    consent_ref                TEXT,               -- shard or doc id for informed-consent
    guardianship_ref           TEXT,               -- optional guardian authority record
    notes                      TEXT
);

CREATE INDEX IF NOT EXISTS idx_qpu_citizen_hw
    ON qpu_citizen_continuity (hardware_id);
