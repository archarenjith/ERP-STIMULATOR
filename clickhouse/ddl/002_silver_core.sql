-- 002_silver_core.sql : Silver core (validated events, quarantine, helper views)

CREATE DATABASE IF NOT EXISTS mfg_silver;

CREATE TABLE IF NOT EXISTS mfg_silver.events
(
    event_id         String,
    event_type       LowCardinality(String),
    event_version    UInt8,
    operation        LowCardinality(String),
    entity_id        String,
    source_topic     LowCardinality(String),
    event_ts         DateTime64(3, 'UTC'),
    produced_at      DateTime64(3, 'UTC'),
    payload_json     String CODEC(ZSTD(3)),
    lag_hours        Float32,
    bronze_partition UInt16,
    bronze_offset    UInt64,
    ingested_at      DateTime64(3, 'UTC'),
    silver_loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree
ORDER BY event_id;

CREATE TABLE IF NOT EXISTS mfg_silver.quarantine
(
    source_topic     LowCardinality(String),
    bronze_partition UInt16,
    bronze_offset    UInt64,
    reject_reason    String,
    event_id         String,
    raw_payload      String CODEC(ZSTD(3)),
    ingested_at      DateTime64(3, 'UTC'),
    quarantined_at   DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree
ORDER BY (source_topic, bronze_partition, bronze_offset);

CREATE OR REPLACE VIEW mfg_silver.v_bronze_parsed AS
SELECT
    source_topic,
    kafka_partition AS bronze_partition,
    kafka_offset    AS bronze_offset,
    ingested_at,
    raw_payload,
    JSONExtractString(raw_payload, 'event_id')   AS event_id,
    JSONExtractString(raw_payload, 'event_type') AS event_type,
    JSONExtractRaw(raw_payload, 'event_version') AS event_version_raw,
    parseDateTime64BestEffortOrNull(JSONExtractString(raw_payload, 'event_ts'), 3, 'UTC')    AS event_ts,
    parseDateTime64BestEffortOrNull(JSONExtractString(raw_payload, 'produced_at'), 3, 'UTC') AS produced_at,
    JSONExtractString(raw_payload, 'operation')  AS operation,
    JSONExtractString(raw_payload, 'entity_id')  AS entity_id,
    JSONExtractRaw(raw_payload, 'payload')       AS payload_json,
    if(NOT isValidJSON(raw_payload), 'malformed_json',
       arrayStringConcat(arrayFilter(x -> x != '', [
           if(event_id = '', 'missing_event_id', ''),
           if(event_ts IS NULL, 'missing_or_bad_event_ts', ''),
           if(produced_at IS NULL, 'missing_or_bad_produced_at', ''),
           if(match(event_version_raw, '^[0-9]+$'),
              if(toUInt64OrZero(event_version_raw) IN (1, 2), '', 'unsupported_event_version'),
              'non_integer_event_version'),
           if(operation IN ('c', 'u', 'd'), '', 'invalid_operation'),
           if(entity_id = '', 'missing_entity_id', ''),
           if(payload_json IN ('', '{}', 'null'), 'missing_payload', '')
       ]), ';')
    ) AS reject_reason
FROM mfg_bronze.raw_events;

CREATE OR REPLACE VIEW mfg_silver.v_events AS
SELECT * FROM mfg_silver.events FINAL;

CREATE OR REPLACE VIEW mfg_silver.v_quarantine AS
SELECT * FROM mfg_silver.quarantine FINAL;

CREATE OR REPLACE VIEW mfg_silver.v_duplicate_events AS
SELECT event_id, source_topic, count() AS copies,
       min(bronze_offset) AS first_offset, max(bronze_offset) AS last_offset
FROM mfg_silver.v_bronze_parsed
WHERE reject_reason = ''
GROUP BY event_id, source_topic
HAVING copies > 1;
