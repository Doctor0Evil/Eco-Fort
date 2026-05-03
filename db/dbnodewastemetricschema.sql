-- filename dbnodewastemetricschema.sql
-- destination Eco-Fort/db/dbnodewastemetricschema.sql

CREATE TABLE IF NOT EXISTS nodewastemetric (
  nodeid          INTEGER NOT NULL REFERENCES node(nodeid) ON DELETE CASCADE,
  window_start_utc TEXT   NOT NULL,
  window_end_utc   TEXT   NOT NULL,
  idle_congestion  REAL   NOT NULL,
  fragmentation    REAL   NOT NULL,
  PRIMARY KEY (nodeid, window_start_utc, window_end_utc)
);
