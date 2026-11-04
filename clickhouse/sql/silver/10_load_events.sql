-- 10_load_events.sql : valid Bronze rows -> mfg_silver.events (incremental, idempotent)
INSERT INTO mfg_silver.events
    (event_id, event_type, event_version, operation, entity_id, source_topic,
     event_ts, produced_at, payload_json, lag_hours,
     bronze_partition, bronze_offset, ingested_at)
SELECT
    event_id,
    event_type,
    toUInt8OrZero(event_version_raw),
    operation,
    entity_id,
    source_topic,
    assumeNotNull(event_ts),
    assumeNotNull(produced_at),
    payload_json,
    round(dateDiff('second', assumeNotNull(event_ts), assumeNotNull(produced_at)) / 3600, 2),
    bronze_partition,
    bronze_offset,
    ingested_at
FROM mfg_silver.v_bronze_parsed
WHERE reject_reason = ''
  AND ingested_at > (SELECT max(ingested_at) FROM mfg_silver.events) - INTERVAL 5 MINUTE
ORDER BY bronze_offset
LIMIT 1 BY event_id;
