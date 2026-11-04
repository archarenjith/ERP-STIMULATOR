-- 11_load_quarantine.sql : invalid Bronze rows -> mfg_silver.quarantine (incremental, idempotent)
INSERT INTO mfg_silver.quarantine
    (source_topic, bronze_partition, bronze_offset, reject_reason, event_id, raw_payload, ingested_at)
SELECT
    source_topic, bronze_partition, bronze_offset, reject_reason, event_id, raw_payload, ingested_at
FROM mfg_silver.v_bronze_parsed
WHERE reject_reason != ''
  AND ingested_at > (SELECT max(ingested_at) FROM mfg_silver.quarantine) - INTERVAL 5 MINUTE;
