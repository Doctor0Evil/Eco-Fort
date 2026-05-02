-- filename: migrations/017_shardinstance_plane_contract.sql

ALTER TABLE shardinstance
    ADD COLUMN plane_contract_id INTEGER
        REFERENCES planeweights_contract(contract_id)
        ON DELETE SET NULL;

CREATE VIEW IF NOT EXISTS shard_residual_view AS
SELECT
    s.shardid,
    s.nodeid,
    s.lane,
    s.kmetric,
    s.emetric,
    s.rmetric,
    s.vtmax,
    p.contract_name,
    p.version_tag
FROM shardinstance s
LEFT JOIN planeweights_contract p
  ON s.plane_contract_id = p.contract_id;
