-- 21_load_other_topics.sql : Silver events -> typed history tables (incremental, idempotent)
-- A delete event carries the last known record in payload.previous_record.

INSERT INTO mfg_silver.machine_telemetry_history
SELECT entity_id, JSONExtractString(pr,'machine_id'), JSONExtractString(pr,'machine_status'),
  JSONExtractUInt(pr,'interval_minutes'), JSONExtractFloat(pr,'runtime_minutes'), JSONExtractFloat(pr,'idle_minutes'),
  JSONExtractFloat(pr,'downtime_minutes'), JSONExtractString(pr,'downtime_reason'), JSONExtractUInt(pr,'units_produced'),
  JSONExtractString(pr,'work_order_id'), JSONExtractBool(pr,'corrected'),
  operation, operation = 'd', JSONExtractString(payload_json,'deleted_reason'), JSONExtractString(pr,'revision_note'),
  JSONExtractString(payload_json,'schema_v2_note'), event_id, event_version, event_ts, produced_at, lag_hours,
  silver_loaded_at, now64(3)
FROM (SELECT *, if(operation = 'd', JSONExtractRaw(payload_json,'previous_record'), payload_json) AS pr
      FROM mfg_silver.v_events WHERE source_topic = 'erp.machine_telemetry.v1'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.machine_telemetry_history) - INTERVAL 5 MINUTE);

INSERT INTO mfg_silver.labour_bookings_history
SELECT entity_id, JSONExtractString(pr,'employee_id'), JSONExtractString(pr,'machine_id'), JSONExtractString(pr,'work_order_id'),
  JSONExtractFloat(pr,'minutes_worked'), JSONExtractFloat(pr,'hourly_cost'), JSONExtractString(pr,'shift'), JSONExtractString(pr,'activity'),
  operation, operation = 'd', JSONExtractString(payload_json,'deleted_reason'), JSONExtractString(pr,'revision_note'),
  JSONExtractString(payload_json,'schema_v2_note'), event_id, event_version, event_ts, produced_at, lag_hours,
  silver_loaded_at, now64(3)
FROM (SELECT *, if(operation = 'd', JSONExtractRaw(payload_json,'previous_record'), payload_json) AS pr
      FROM mfg_silver.v_events WHERE source_topic = 'erp.labour_bookings.v1'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.labour_bookings_history) - INTERVAL 5 MINUTE);

INSERT INTO mfg_silver.electricity_readings_history
SELECT entity_id, JSONExtractString(pr,'meter_id'), JSONExtractString(pr,'machine_id'), JSONExtractUInt(pr,'interval_minutes'),
  JSONExtractFloat(pr,'energy_kwh'), JSONExtractFloat(pr,'tariff_per_kwh'),
  operation, operation = 'd', JSONExtractString(payload_json,'deleted_reason'), JSONExtractString(pr,'revision_note'),
  JSONExtractString(payload_json,'schema_v2_note'), event_id, event_version, event_ts, produced_at, lag_hours,
  silver_loaded_at, now64(3)
FROM (SELECT *, if(operation = 'd', JSONExtractRaw(payload_json,'previous_record'), payload_json) AS pr
      FROM mfg_silver.v_events WHERE source_topic = 'erp.electricity_readings.v1'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.electricity_readings_history) - INTERVAL 5 MINUTE);

INSERT INTO mfg_silver.inventory_movements_history
SELECT entity_id, JSONExtractString(pr,'material_id'), JSONExtractString(pr,'product_id'), JSONExtractString(pr,'stock_category'),
  JSONExtractString(pr,'movement_type'), JSONExtractFloat(pr,'quantity_delta'), JSONExtractString(pr,'uom'),
  JSONExtractString(pr,'warehouse_id'), JSONExtractString(pr,'reference_id'), JSONExtractFloat(pr,'unit_cost'),
  operation, operation = 'd', JSONExtractString(payload_json,'deleted_reason'), JSONExtractString(pr,'revision_note'),
  JSONExtractString(payload_json,'schema_v2_note'), event_id, event_version, event_ts, produced_at, lag_hours,
  silver_loaded_at, now64(3)
FROM (SELECT *, if(operation = 'd', JSONExtractRaw(payload_json,'previous_record'), payload_json) AS pr
      FROM mfg_silver.v_events WHERE source_topic = 'erp.inventory.v1'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.inventory_movements_history) - INTERVAL 5 MINUTE);

INSERT INTO mfg_silver.purchase_orders_history
SELECT entity_id, JSONExtractString(pr,'supplier_id'), JSONExtractString(pr,'material_id'), JSONExtractFloat(pr,'order_quantity'),
  JSONExtractFloat(pr,'received_quantity'), JSONExtractString(pr,'uom'), JSONExtractFloat(pr,'unit_cost'),
  JSONExtractString(pr,'status'), toDateOrNull(JSONExtractString(pr,'expected_delivery_date')),
  operation, operation = 'd', JSONExtractString(payload_json,'deleted_reason'), JSONExtractString(pr,'revision_note'),
  JSONExtractString(payload_json,'schema_v2_note'), event_id, event_version, event_ts, produced_at, lag_hours,
  silver_loaded_at, now64(3)
FROM (SELECT *, if(operation = 'd', JSONExtractRaw(payload_json,'previous_record'), payload_json) AS pr
      FROM mfg_silver.v_events WHERE source_topic = 'erp.purchase_orders.v1'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.purchase_orders_history) - INTERVAL 5 MINUTE);

INSERT INTO mfg_silver.quality_inspections_history
SELECT entity_id, JSONExtractString(pr,'work_order_id'), JSONExtractString(pr,'product_id'), JSONExtractUInt(pr,'sample_size'),
  JSONExtractUInt(pr,'accepted_quantity'), JSONExtractUInt(pr,'rejected_quantity'), JSONExtractString(pr,'result'),
  JSONExtractString(pr,'defect_code'),
  operation, operation = 'd', JSONExtractString(payload_json,'deleted_reason'), JSONExtractString(pr,'revision_note'),
  JSONExtractString(payload_json,'schema_v2_note'), event_id, event_version, event_ts, produced_at, lag_hours,
  silver_loaded_at, now64(3)
FROM (SELECT *, if(operation = 'd', JSONExtractRaw(payload_json,'previous_record'), payload_json) AS pr
      FROM mfg_silver.v_events WHERE source_topic = 'erp.quality_inspections.v1'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.quality_inspections_history) - INTERVAL 5 MINUTE);

INSERT INTO mfg_silver.maintenance_history
SELECT entity_id, JSONExtractString(pr,'machine_id'), JSONExtractString(pr,'maintenance_type'), JSONExtractString(pr,'status'),
  JSONExtractFloat(pr,'planned_minutes'), JSONExtractFloat(pr,'actual_minutes'), JSONExtractFloat(pr,'maintenance_cost'),
  JSONExtractString(pr,'reason_code'),
  operation, operation = 'd', JSONExtractString(payload_json,'deleted_reason'), JSONExtractString(pr,'revision_note'),
  JSONExtractString(payload_json,'schema_v2_note'), event_id, event_version, event_ts, produced_at, lag_hours,
  silver_loaded_at, now64(3)
FROM (SELECT *, if(operation = 'd', JSONExtractRaw(payload_json,'previous_record'), payload_json) AS pr
      FROM mfg_silver.v_events WHERE source_topic = 'erp.maintenance.v1'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.maintenance_history) - INTERVAL 5 MINUTE);

INSERT INTO mfg_silver.sales_orders_history
SELECT entity_id, JSONExtractString(pr,'customer_id'), JSONExtractString(pr,'product_id'), JSONExtractFloat(pr,'ordered_quantity'),
  JSONExtractFloat(pr,'shipped_quantity'), JSONExtractFloat(pr,'unit_price'), JSONExtractString(pr,'status'),
  toDateOrNull(JSONExtractString(pr,'requested_delivery_date')),
  operation, operation = 'd', JSONExtractString(payload_json,'deleted_reason'), JSONExtractString(pr,'revision_note'),
  JSONExtractString(payload_json,'schema_v2_note'), event_id, event_version, event_ts, produced_at, lag_hours,
  silver_loaded_at, now64(3)
FROM (SELECT *, if(operation = 'd', JSONExtractRaw(payload_json,'previous_record'), payload_json) AS pr
      FROM mfg_silver.v_events WHERE source_topic = 'erp.sales_orders.v1'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.sales_orders_history) - INTERVAL 5 MINUTE);

INSERT INTO mfg_silver.reference_history
SELECT JSONExtractString(pr,'entity_type'), entity_id,
  arrayFirst(x -> x != '', [JSONExtractString(pr,'supplier_name'), JSONExtractString(pr,'material_name'),
    JSONExtractString(pr,'product_name'), JSONExtractString(pr,'machine_name'), JSONExtractString(pr,'employee_name')]),
  JSONExtractString(pr,'country'), JSONExtractString(pr,'rating'), JSONExtractString(pr,'uom'),
  JSONExtractFloat(pr,'reorder_level'), JSONExtractFloat(pr,'standard_cycle_minutes'), JSONExtractString(pr,'work_center'),
  JSONExtractFloat(pr,'rated_kw'), JSONExtractString(pr,'role'),
  operation, operation = 'd', JSONExtractString(payload_json,'deleted_reason'), JSONExtractString(pr,'revision_note'),
  JSONExtractString(payload_json,'schema_v2_note'), event_id, event_version, event_ts, produced_at, lag_hours,
  silver_loaded_at, now64(3)
FROM (SELECT *, if(operation = 'd', JSONExtractRaw(payload_json,'previous_record'), payload_json) AS pr
      FROM mfg_silver.v_events WHERE source_topic = 'erp.reference.v1'
      AND silver_loaded_at > (SELECT max(source_loaded_at) FROM mfg_silver.reference_history) - INTERVAL 5 MINUTE);
