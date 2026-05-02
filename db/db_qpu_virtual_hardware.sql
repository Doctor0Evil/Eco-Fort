-- filename db_qpu_virtual_hardware.sql
-- destination Eco-Fort/db/db_qpu_virtual_hardware.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS qpu_virtual_hardware (
    hardware_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    hardware_family     TEXT NOT NULL,   -- 'MT6883','GPU','FPGA','EDGE_NODE'
    model_code          TEXT NOT NULL,   -- 'mt6883-handset-2026','mt6883-hud-01'
    vendor              TEXT,
    capabilities        TEXT,            -- ALN/JSON description of compute, sensors, radios
    max_energy_kw       REAL,            -- max sustainable power draw
    thermal_design_w    REAL,            -- design thermal envelope
    continuity_grade    TEXT,            -- 'A','B','C' continuity/resilience rating
    notes               TEXT,

    UNIQUE (hardware_family, model_code)
);

CREATE INDEX IF NOT EXISTS idx_qpu_hw_family
    ON qpu_virtual_hardware (hardware_family);

CREATE INDEX IF NOT EXISTS idx_qpu_hw_continuity
    ON qpu_virtual_hardware (continuity_grade);
