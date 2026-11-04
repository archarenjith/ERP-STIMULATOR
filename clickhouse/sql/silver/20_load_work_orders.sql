-- 20_load_work_orders.sql : work_order.* events -> mfg_silver.work_orders_history (incremental, idempotent)
-- A delete event carries the last known record in payload.previous_record.
INSERT INTO mfg_silver.work_orders_history
    (work_order_id, operation, is_deleted, deleted_reason, product_id, machine_id,
     planned_quantity, good_quantity, scrap_quantity, status,
     planned_processing_minutes, actual_processing_minutes, planned_start_date,
     revision_note, schema_v2_note, event_id, event_version, event_ts, produced_at,
     lag_hours, source_loaded_at)
SELECT
    entity_id,
    operation,
    operation = 'd',
    JSONExtractString(payload_json, 'deleted_reason'),
    JSONExtractString(pr, 'product_id'),
    JSONExtractString(pr, 'machine_id'),
    JSONExtractUInt(pr, 'planned_quantity'),
    JSONExtractUInt(pr, 'good_quantity'),
    JSONExtractUInt(pr, 'scrap_quantity'),
    JSONExtractString(pr, 'status'),
    JSONExtractUInt(pr, 'planned_processing_minutes'),
    JSONExtractUInt(pr, 'actual_processing_minutes'),
    toDateOrNull(JSONExtractString(pr, 'planned_start_date')),
    JSONExtractString(pr, 'revision_note'),
    JSONExtractString(payload_json, 'schema_v2_note'),
    event_id,
    event_version,
    event_ts,
    produced_at,
    lag_hours,
    silver_loaded_at
FROM
(
    SELECT *, if(operation = 'd', JSONExtractRaw(payload_json, 'previous_record'), payload_json) AS pr
    FROM mfg_silver.v_events
    WHERE event_type LIKE 'work_order.%'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.work_orders_history) - INTERVAL 5 MINUTE
);
