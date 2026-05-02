-- filename: db/eco_planes.sql
-- destination: Eco-Fort/db/eco_planes.sql

CREATE TABLE IF NOT EXISTS plane_properties (
    plane_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT NOT NULL UNIQUE, -- 'carbon','biodiversity','energy','hydraulics','materials'
    weight        REAL NOT NULL,
    non_offsettable INTEGER NOT NULL CHECK (non_offsettable IN (0,1)),
    mandatory     INTEGER NOT NULL CHECK (mandatory IN (0,1))
);

INSERT OR IGNORE INTO plane_properties (name, weight, non_offsettable, mandatory) VALUES
    ('carbon',       1.0, 1, 1),
    ('biodiversity', 1.0, 1, 1),
    ('energy',       0.7, 0, 1),
    ('hydraulics',   0.7, 0, 1),
    ('materials',    0.8, 0, 1),
    ('dataquality',  0.6, 0, 1);
