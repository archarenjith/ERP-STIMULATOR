-- 003_silver_work_orders.sql : typed work orders (full history + current-state view)

CREATE TABLE IF NOT EXISTS mfg_silver.work_orders_history
(
    work_order_id              String,
    operation                  LowCardinality(String),
    is_deleted                 UInt8,
    deleted_reason             String,
    product_id                 String,
    machine_id                 String,
    planned_quantity           UInt32,
    good_quantity              UInt32,
    scrap_quantity             UInt32,
    status                     LowCardinality(String),
    planned_processing_minutes UInt32,
    actual_processing_minutes  UInt32,
    planned_start_date         Nullable(Date),
    revision_note              String,
    schema_v2_note             String,
    event_id                   String,
    event_version              UInt8,
    event_ts                   DateTime64(3, 'UTC'),
    produced_at                DateTime64(3, 'UTC'),
    lag_hours                  Float32,
    source_loaded_at           DateTime64(3, 'UTC'),
    loaded_at                  DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree
ORDER BY event_id;

-- Latest version per work order by business time; deleted ones are hidden
CREATE OR REPLACE VIEW mfg_silver.v_work_orders_current AS
SELECT *
FROM
(
    SELECT *
    FROM mfg_silver.work_orders_history FINAL
    ORDER BY event_ts DESC, produced_at DESC
    LIMIT 1 BY work_order_id
)
WHERE is_deleted = 0;
