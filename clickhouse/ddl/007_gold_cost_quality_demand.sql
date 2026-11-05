-- 007_gold_cost_quality_demand.sql : Gold - cost, quality and demand (views over Silver current-state)

-- Daily cost by component
CREATE OR REPLACE VIEW mfg_gold.cost_daily AS
SELECT
    day,
    round(sum(labour_cost), 2)      AS labour_cost,
    round(sum(electricity_cost), 2) AS electricity_cost,
    round(sum(material_cost), 2)    AS material_cost,
    round(sum(labour_cost) + sum(electricity_cost) + sum(material_cost), 2) AS total_cost
FROM
(
    SELECT toDate(event_ts) AS day, minutes_worked / 60 * hourly_cost AS labour_cost,
           0. AS electricity_cost, 0. AS material_cost
    FROM mfg_silver.v_labour_bookings_current
    UNION ALL
    SELECT toDate(event_ts), 0., energy_kwh * tariff_per_kwh, 0.
    FROM mfg_silver.v_electricity_readings_current
    UNION ALL
    SELECT toDate(event_ts), 0., 0., -quantity_delta * unit_cost
    FROM mfg_silver.v_inventory_movements_current
    WHERE movement_type = 'production_issue'
)
GROUP BY day;

-- Cost per machine (labour + electricity; material is not tied to a machine in the source)
CREATE OR REPLACE VIEW mfg_gold.cost_by_machine AS
SELECT
    c.machine_id AS machine_id,
    m.ma_name    AS machine_name,
    round(sum(c.labour_cost), 2)      AS labour_cost,
    round(sum(c.electricity_cost), 2) AS electricity_cost,
    round(sum(c.labour_cost) + sum(c.electricity_cost), 2) AS total_cost
FROM
(
    SELECT machine_id, minutes_worked / 60 * hourly_cost AS labour_cost, 0. AS electricity_cost
    FROM mfg_silver.v_labour_bookings_current
    UNION ALL
    SELECT machine_id, 0., energy_kwh * tariff_per_kwh
    FROM mfg_silver.v_electricity_readings_current
) AS c
LEFT JOIN (SELECT entity_id AS ma_id, entity_name AS ma_name
           FROM mfg_silver.v_reference_current WHERE entity_type = 'machine') AS m ON c.machine_id = m.ma_id
GROUP BY machine_id, machine_name
SETTINGS join_use_nulls = 1;

-- Quality by day and product: rejection rate = rejected / sample size
CREATE OR REPLACE VIEW mfg_gold.quality_daily AS
SELECT
    toDate(q.event_ts) AS day,
    q.product_id AS product_id,
    p.pr_name AS product_name,
    count() AS inspections,
    sum(q.sample_size) AS sample_size,
    sum(q.rejected_quantity) AS rejected_quantity,
    round(100 * sum(q.rejected_quantity) / nullIf(sum(q.sample_size), 0), 2) AS rejection_rate_pct,
    countIf(q.result != 'pass') AS failed_inspections
FROM mfg_silver.v_quality_inspections_current AS q
LEFT JOIN (SELECT entity_id AS pr_id, entity_name AS pr_name
           FROM mfg_silver.v_reference_current WHERE entity_type = 'product') AS p ON q.product_id = p.pr_id
GROUP BY day, product_id, product_name
SETTINGS join_use_nulls = 1;

-- Defects by code
CREATE OR REPLACE VIEW mfg_gold.quality_defects AS
SELECT
    defect_code,
    count() AS inspections,
    sum(rejected_quantity) AS rejected_quantity
FROM mfg_silver.v_quality_inspections_current
WHERE defect_code != ''
GROUP BY defect_code;

-- Sales orders: fulfilment status
CREATE OR REPLACE VIEW mfg_gold.sales_orders_status AS
SELECT
    s.sales_order_id,
    s.customer_id,
    s.product_id,
    p.pr_name AS product_name,
    s.ordered_quantity,
    s.shipped_quantity,
    greatest(s.ordered_quantity - s.shipped_quantity, 0) AS open_quantity,
    round(100 * s.shipped_quantity / nullIf(s.ordered_quantity, 0), 1) AS fulfilment_pct,
    multiIf(s.shipped_quantity >= s.ordered_quantity AND s.ordered_quantity > 0, 'fulfilled',
            s.shipped_quantity > 0, 'partially_shipped', 'not_shipped') AS fulfilment_state,
    s.status,
    round(s.ordered_quantity * s.unit_price, 2) AS order_value,
    s.requested_delivery_date,
    (s.shipped_quantity < s.ordered_quantity AND s.requested_delivery_date < today()) AS is_overdue
FROM mfg_silver.v_sales_orders_current AS s
LEFT JOIN (SELECT entity_id AS pr_id, entity_name AS pr_name
           FROM mfg_silver.v_reference_current WHERE entity_type = 'product') AS p ON s.product_id = p.pr_id
SETTINGS join_use_nulls = 1;

-- Demand by product
CREATE OR REPLACE VIEW mfg_gold.demand_by_product AS
SELECT
    product_id,
    any(product_name) AS product_name,
    count() AS sales_orders,
    sum(ordered_quantity) AS ordered_quantity,
    sum(shipped_quantity) AS shipped_quantity,
    sum(open_quantity) AS open_quantity,
    round(sum(order_value), 2) AS order_value,
    round(100 * sum(shipped_quantity) / nullIf(sum(ordered_quantity), 0), 1) AS fulfilment_pct
FROM mfg_gold.sales_orders_status
GROUP BY product_id;
