-- scenario_validation.sql : repeatable evidence for the mandatory test scenario
SELECT 'bronze_rows' AS check_name, count() AS value FROM mfg_bronze.raw_events
UNION ALL SELECT 'silver_events', count() FROM mfg_silver.v_events
UNION ALL SELECT 'quarantine_rows', count() FROM mfg_silver.v_quarantine
UNION ALL SELECT 'duplicate_groups', count() FROM mfg_silver.v_duplicate_events
UNION ALL SELECT 'late_events_24h_plus', count() FROM mfg_silver.v_events WHERE lag_hours >= 24
UNION ALL SELECT 'v2_events_in_silver', count() FROM mfg_silver.v_events WHERE event_version = 2
UNION ALL SELECT 'deleted_but_visible_work_orders', count() FROM (
    SELECT work_order_id, argMax(is_deleted, (event_ts, produced_at)) AS latest_deleted
    FROM mfg_silver.work_orders_history GROUP BY work_order_id HAVING latest_deleted = 1)
  WHERE work_order_id IN (SELECT work_order_id FROM mfg_silver.v_work_orders_current)
FORMAT TSVWithNames;
