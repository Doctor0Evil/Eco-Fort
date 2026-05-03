-- filename dbhydrtelemetrywindowschema.sql
-- destination Eco-Fort/db/dbhydrtelemetrywindowschema.sql

CREATE TABLE IF NOT EXISTS hydr_telemetry_window (
  siteid           INTEGER NOT NULL REFERENCES node(nodeid) ON DELETE CASCADE,
  window_start_utc TEXT    NOT NULL,
  window_end_utc   TEXT    NOT NULL,
  flow_mean        REAL    NOT NULL,
  flow_p95         REAL    NOT NULL,
  contaminant_p95  REAL    NOT NULL,
  PRIMARY KEY (siteid, window_start_utc, window_end_utc)
);
