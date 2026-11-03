-- 001_bronze.sql : Bronze layer (raw, append-oriented, auditable)

CREATE DATABASE IF NOT EXISTS mfg_bronze;

-- Raw events exactly as received, plus Kafka metadata and ingestion time.
-- ReplacingMergeTree on (topic, partition, offset): a replayed offset
-- collapses to one row, so a consumer restart cannot create duplicates.
CREATE TABLE IF NOT EXISTS mfg_bronze.raw_events
(
    source_topic    LowCardinality(String),
    kafka_partition UInt16,
    kafka_offset    UInt64,
    kafka_ts        DateTime64(3, 'UTC'),
    kafka_key       String,
    raw_payload     String CODEC(ZSTD(3)),
    ingested_at     DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(kafka_ts)
ORDER BY (source_topic, kafka_partition, kafka_offset);

-- Kafka consumer: one table for all 10 contracted topics.
CREATE TABLE IF NOT EXISTS mfg_bronze.kafka_erp_queue
(
    raw_payload String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'erp.reference.v1,erp.inventory.v1,erp.purchase_orders.v1,erp.work_orders.v1,erp.machine_telemetry.v1,erp.labour_bookings.v1,erp.electricity_readings.v1,erp.quality_inspections.v1,erp.maintenance.v1,erp.sales_orders.v1',
    kafka_group_name = 'clickhouse_mfg_bronze',
    kafka_format = 'LineAsString',
    kafka_num_consumers = 1,
    kafka_max_block_size = 1000;

-- Moves each consumed message into Bronze with its Kafka metadata.
CREATE MATERIALIZED VIEW IF NOT EXISTS mfg_bronze.mv_kafka_to_raw
TO mfg_bronze.raw_events AS
SELECT
    _topic        AS source_topic,
    _partition    AS kafka_partition,
    _offset       AS kafka_offset,
    ifNull(_timestamp_ms, now64(3)) AS kafka_ts,
    _key          AS kafka_key,
    raw_payload
FROM mfg_bronze.kafka_erp_queue;