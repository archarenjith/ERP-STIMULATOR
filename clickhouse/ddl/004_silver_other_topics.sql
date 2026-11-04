-- 004_silver_other_topics.sql : typed history table + current-state view per topic
-- Every table keeps ALL events (audit). The v_*_current views keep the latest
-- version per key by business time (event_ts) and hide deleted rows.

CREATE TABLE IF NOT EXISTS mfg_silver.machine_telemetry_history
(
    telemetry_id String, machine_id String, machine_status LowCardinality(String),
    interval_minutes UInt16, runtime_minutes Float32, idle_minutes Float32, downtime_minutes Float32,
    downtime_reason String, units_produced UInt32, work_order_id String, corrected UInt8,
    operation LowCardinality(String), is_deleted UInt8, deleted_reason String, revision_note String,
    schema_v2_note String, event_id String, event_version UInt8, event_ts DateTime64(3, 'UTC'),
    produced_at DateTime64(3, 'UTC'), lag_hours Float32, source_loaded_at DateTime64(3, 'UTC'),
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
) ENGINE = ReplacingMergeTree ORDER BY event_id;

CREATE TABLE IF NOT EXISTS mfg_silver.labour_bookings_history
(
    booking_id String, employee_id String, machine_id String, work_order_id String,
    minutes_worked Float32, hourly_cost Float64, shift LowCardinality(String), activity LowCardinality(String),
    operation LowCardinality(String), is_deleted UInt8, deleted_reason String, revision_note String,
    schema_v2_note String, event_id String, event_version UInt8, event_ts DateTime64(3, 'UTC'),
    produced_at DateTime64(3, 'UTC'), lag_hours Float32, source_loaded_at DateTime64(3, 'UTC'),
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
) ENGINE = ReplacingMergeTree ORDER BY event_id;

CREATE TABLE IF NOT EXISTS mfg_silver.electricity_readings_history
(
    reading_id String, meter_id String, machine_id String, interval_minutes UInt16,
    energy_kwh Float64, tariff_per_kwh Float64,
    operation LowCardinality(String), is_deleted UInt8, deleted_reason String, revision_note String,
    schema_v2_note String, event_id String, event_version UInt8, event_ts DateTime64(3, 'UTC'),
    produced_at DateTime64(3, 'UTC'), lag_hours Float32, source_loaded_at DateTime64(3, 'UTC'),
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
) ENGINE = ReplacingMergeTree ORDER BY event_id;

CREATE TABLE IF NOT EXISTS mfg_silver.inventory_movements_history
(
    movement_id String, material_id String, product_id String, stock_category LowCardinality(String),
    movement_type LowCardinality(String), quantity_delta Float64, uom LowCardinality(String),
    warehouse_id String, reference_id String, unit_cost Float64,
    operation LowCardinality(String), is_deleted UInt8, deleted_reason String, revision_note String,
    schema_v2_note String, event_id String, event_version UInt8, event_ts DateTime64(3, 'UTC'),
    produced_at DateTime64(3, 'UTC'), lag_hours Float32, source_loaded_at DateTime64(3, 'UTC'),
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
) ENGINE = ReplacingMergeTree ORDER BY event_id;

CREATE TABLE IF NOT EXISTS mfg_silver.purchase_orders_history
(
    po_id String, supplier_id String, material_id String, order_quantity Float64,
    received_quantity Float64, uom LowCardinality(String), unit_cost Float64,
    status LowCardinality(String), expected_delivery_date Nullable(Date),
    operation LowCardinality(String), is_deleted UInt8, deleted_reason String, revision_note String,
    schema_v2_note String, event_id String, event_version UInt8, event_ts DateTime64(3, 'UTC'),
    produced_at DateTime64(3, 'UTC'), lag_hours Float32, source_loaded_at DateTime64(3, 'UTC'),
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
) ENGINE = ReplacingMergeTree ORDER BY event_id;

CREATE TABLE IF NOT EXISTS mfg_silver.quality_inspections_history
(
    inspection_id String, work_order_id String, product_id String, sample_size UInt32,
    accepted_quantity UInt32, rejected_quantity UInt32, result LowCardinality(String), defect_code String,
    operation LowCardinality(String), is_deleted UInt8, deleted_reason String, revision_note String,
    schema_v2_note String, event_id String, event_version UInt8, event_ts DateTime64(3, 'UTC'),
    produced_at DateTime64(3, 'UTC'), lag_hours Float32, source_loaded_at DateTime64(3, 'UTC'),
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
) ENGINE = ReplacingMergeTree ORDER BY event_id;

CREATE TABLE IF NOT EXISTS mfg_silver.maintenance_history
(
    maintenance_id String, machine_id String, maintenance_type LowCardinality(String),
    status LowCardinality(String), planned_minutes Float32, actual_minutes Float32,
    maintenance_cost Float64, reason_code String,
    operation LowCardinality(String), is_deleted UInt8, deleted_reason String, revision_note String,
    schema_v2_note String, event_id String, event_version UInt8, event_ts DateTime64(3, 'UTC'),
    produced_at DateTime64(3, 'UTC'), lag_hours Float32, source_loaded_at DateTime64(3, 'UTC'),
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
) ENGINE = ReplacingMergeTree ORDER BY event_id;

CREATE TABLE IF NOT EXISTS mfg_silver.sales_orders_history
(
    sales_order_id String, customer_id String, product_id String, ordered_quantity Float64,
    shipped_quantity Float64, unit_price Float64, status LowCardinality(String),
    requested_delivery_date Nullable(Date),
    operation LowCardinality(String), is_deleted UInt8, deleted_reason String, revision_note String,
    schema_v2_note String, event_id String, event_version UInt8, event_ts DateTime64(3, 'UTC'),
    produced_at DateTime64(3, 'UTC'), lag_hours Float32, source_loaded_at DateTime64(3, 'UTC'),
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
) ENGINE = ReplacingMergeTree ORDER BY event_id;

CREATE TABLE IF NOT EXISTS mfg_silver.reference_history
(
    entity_type LowCardinality(String), entity_id String, entity_name String, country String, rating String,
    uom String, reorder_level Float64, standard_cycle_minutes Float32, work_center String,
    rated_kw Float32, role String,
    operation LowCardinality(String), is_deleted UInt8, deleted_reason String, revision_note String,
    schema_v2_note String, event_id String, event_version UInt8, event_ts DateTime64(3, 'UTC'),
    produced_at DateTime64(3, 'UTC'), lag_hours Float32, source_loaded_at DateTime64(3, 'UTC'),
    loaded_at DateTime64(3, 'UTC') DEFAULT now64(3)
) ENGINE = ReplacingMergeTree ORDER BY event_id;

CREATE OR REPLACE VIEW mfg_silver.v_machine_telemetry_current AS
SELECT * FROM (SELECT * FROM mfg_silver.machine_telemetry_history FINAL
               ORDER BY event_ts DESC, produced_at DESC LIMIT 1 BY telemetry_id) WHERE is_deleted = 0;
CREATE OR REPLACE VIEW mfg_silver.v_labour_bookings_current AS
SELECT * FROM (SELECT * FROM mfg_silver.labour_bookings_history FINAL
               ORDER BY event_ts DESC, produced_at DESC LIMIT 1 BY booking_id) WHERE is_deleted = 0;
CREATE OR REPLACE VIEW mfg_silver.v_electricity_readings_current AS
SELECT * FROM (SELECT * FROM mfg_silver.electricity_readings_history FINAL
               ORDER BY event_ts DESC, produced_at DESC LIMIT 1 BY reading_id) WHERE is_deleted = 0;
CREATE OR REPLACE VIEW mfg_silver.v_inventory_movements_current AS
SELECT * FROM (SELECT * FROM mfg_silver.inventory_movements_history FINAL
               ORDER BY event_ts DESC, produced_at DESC LIMIT 1 BY movement_id) WHERE is_deleted = 0;
CREATE OR REPLACE VIEW mfg_silver.v_purchase_orders_current AS
SELECT * FROM (SELECT * FROM mfg_silver.purchase_orders_history FINAL
               ORDER BY event_ts DESC, produced_at DESC LIMIT 1 BY po_id) WHERE is_deleted = 0;
CREATE OR REPLACE VIEW mfg_silver.v_quality_inspections_current AS
SELECT * FROM (SELECT * FROM mfg_silver.quality_inspections_history FINAL
               ORDER BY event_ts DESC, produced_at DESC LIMIT 1 BY inspection_id) WHERE is_deleted = 0;
CREATE OR REPLACE VIEW mfg_silver.v_maintenance_current AS
SELECT * FROM (SELECT * FROM mfg_silver.maintenance_history FINAL
               ORDER BY event_ts DESC, produced_at DESC LIMIT 1 BY maintenance_id) WHERE is_deleted = 0;
CREATE OR REPLACE VIEW mfg_silver.v_sales_orders_current AS
SELECT * FROM (SELECT * FROM mfg_silver.sales_orders_history FINAL
               ORDER BY event_ts DESC, produced_at DESC LIMIT 1 BY sales_order_id) WHERE is_deleted = 0;
CREATE OR REPLACE VIEW mfg_silver.v_reference_current AS
SELECT * FROM (SELECT * FROM mfg_silver.reference_history FINAL
               ORDER BY event_ts DESC, produced_at DESC LIMIT 1 BY entity_type, entity_id) WHERE is_deleted = 0;
