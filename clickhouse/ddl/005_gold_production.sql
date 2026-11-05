-- 005_gold_production.sql : Gold - production and machines (views over Silver current-state)

CREATE DATABASE IF NOT EXISTS mfg_gold;

-- One row per work order: planned vs actual processing time, yield
CREATE OR REPLACE VIEW mfg_gold.production_work_orders AS
SELECT
    w.work_order_id,
    w.product_id,
    p.pr_name AS product_name,
    w.machine_id,
    m.ma_name AS machine_name,
    w.status,
    w.planned_start_date,
    w.planned_quantity,
    w.good_quantity,
    w.scrap_quantity,
    w.planned_processing_minutes AS planned_minutes,
    w.actual_processing_minutes  AS actual_minutes,
    if(w.actual_processing_minutes > 0,
       toInt32(w.actual_processing_minutes) - toInt32(w.planned_processing_minutes), NULL) AS schedule_variance_minutes,
    if(w.good_quantity + w.scrap_quantity > 0,
       round(100 * w.good_quantity / (w.good_quantity + w.scrap_quantity), 2), NULL) AS yield_pct
FROM mfg_silver.v_work_orders_current AS w
LEFT JOIN (SELECT entity_id AS pr_id, entity_name AS pr_name
           FROM mfg_silver.v_reference_current WHERE entity_type = 'product') AS p ON w.product_id = p.pr_id
LEFT JOIN (SELECT entity_id AS ma_id, entity_name AS ma_name
           FROM mfg_silver.v_reference_current WHERE entity_type = 'machine') AS m ON w.machine_id = m.ma_id
SETTINGS join_use_nulls = 1;

-- Machine time and output per day (throughput = units_produced)
CREATE OR REPLACE VIEW mfg_gold.machine_daily AS
SELECT
    machine_id,
    toDate(event_ts) AS day,
    round(sum(runtime_minutes), 1)  AS runtime_minutes,
    round(sum(idle_minutes), 1)     AS idle_minutes,
    round(sum(downtime_minutes), 1) AS downtime_minutes,
    sum(units_produced)             AS units_produced,
    count()                         AS readings
FROM mfg_silver.v_machine_telemetry_current
GROUP BY machine_id, day;

-- Per machine: utilisation, availability, yield and an OEE-style approximation
--   utilisation  = runtime / (runtime + idle + downtime)
--   availability = (runtime + idle) / (runtime + idle + downtime)
--   yield        = good / (good + scrap) over work orders with output
--   OEE-style    = availability x yield   (performance is NOT measurable from these fields)
CREATE OR REPLACE VIEW mfg_gold.machine_summary AS
SELECT
    t.machine_id AS machine_id,
    m.ma_name    AS machine_name,
    m.ma_center  AS work_center,
    t.runtime_minutes,
    t.idle_minutes,
    t.downtime_minutes,
    t.units_produced,
    round(100 * t.runtime_minutes / nullIf(t.runtime_minutes + t.idle_minutes + t.downtime_minutes, 0), 1) AS utilisation_pct,
    round(100 * (t.runtime_minutes + t.idle_minutes) / nullIf(t.runtime_minutes + t.idle_minutes + t.downtime_minutes, 0), 1) AS availability_pct,
    q.yield_pct AS yield_pct,
    round(availability_pct * yield_pct / 100, 1) AS oee_style_pct
FROM
(
    SELECT machine_id,
           sum(runtime_minutes) AS runtime_minutes, sum(idle_minutes) AS idle_minutes,
           sum(downtime_minutes) AS downtime_minutes, sum(units_produced) AS units_produced
    FROM mfg_gold.machine_daily GROUP BY machine_id
) AS t
LEFT JOIN (SELECT entity_id AS ma_id, entity_name AS ma_name, work_center AS ma_center
           FROM mfg_silver.v_reference_current WHERE entity_type = 'machine') AS m ON t.machine_id = m.ma_id
LEFT JOIN (SELECT machine_id AS q_machine,
                  round(100 * sum(good_quantity) / nullIf(sum(good_quantity) + sum(scrap_quantity), 0), 2) AS yield_pct
           FROM mfg_silver.v_work_orders_current
           WHERE good_quantity + scrap_quantity > 0 GROUP BY machine_id) AS q ON t.machine_id = q.q_machine
SETTINGS join_use_nulls = 1;
