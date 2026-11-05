-- 006_gold_inventory.sql : Gold - inventory and procurement (views over Silver current-state)
-- NOTE: stock is movement-based (sum of quantity_delta since the start of the data),
-- not an audited balance: the source has no opening balance event.

CREATE OR REPLACE VIEW mfg_gold.inventory_position AS
SELECT
    i.material_id AS material_id,
    r.ma_name     AS material_name,
    i.stock_category,
    i.uom,
    round(i.stock_on_hand, 2) AS stock_on_hand,
    r.ma_reorder  AS reorder_level,
    multiIf(r.ma_reorder IS NULL, 'unknown',
            i.stock_on_hand <= 0, 'out_of_stock',
            i.stock_on_hand < r.ma_reorder, 'reorder_now',
            i.stock_on_hand < 1.5 * r.ma_reorder, 'watch',
            'ok') AS reorder_risk,
    i.movements,
    i.last_movement
FROM
(
    SELECT material_id, any(stock_category) AS stock_category, any(uom) AS uom,
           sum(quantity_delta) AS stock_on_hand, count() AS movements, max(event_ts) AS last_movement
    FROM mfg_silver.v_inventory_movements_current
    WHERE material_id != ''
    GROUP BY material_id
) AS i
LEFT JOIN (SELECT entity_id AS ma_id, entity_name AS ma_name, reorder_level AS ma_reorder
           FROM mfg_silver.v_reference_current WHERE entity_type = 'material') AS r ON i.material_id = r.ma_id
SETTINGS join_use_nulls = 1;

-- Daily movements by type (raw material receipts/issues, finished goods)
CREATE OR REPLACE VIEW mfg_gold.inventory_movements_daily AS
SELECT
    toDate(event_ts) AS day,
    stock_category,
    movement_type,
    count() AS movements,
    round(sum(quantity_delta), 2) AS net_quantity,
    round(sum(quantity_delta * unit_cost), 2) AS net_value
FROM mfg_silver.v_inventory_movements_current
GROUP BY day, stock_category, movement_type;

-- Finished goods position per product
CREATE OR REPLACE VIEW mfg_gold.finished_goods_position AS
SELECT
    f.product_id AS product_id,
    r.pr_name    AS product_name,
    round(f.stock_on_hand, 2) AS stock_on_hand,
    f.movements,
    f.last_movement
FROM
(
    SELECT product_id, sum(quantity_delta) AS stock_on_hand, count() AS movements, max(event_ts) AS last_movement
    FROM mfg_silver.v_inventory_movements_current
    WHERE stock_category = 'finished_goods' AND product_id != ''
    GROUP BY product_id
) AS f
LEFT JOIN (SELECT entity_id AS pr_id, entity_name AS pr_name
           FROM mfg_silver.v_reference_current WHERE entity_type = 'product') AS r ON f.product_id = r.pr_id
SETTINGS join_use_nulls = 1;

-- One row per purchase order, with open / received status and receipt percentage
CREATE OR REPLACE VIEW mfg_gold.purchase_orders_status AS
SELECT
    p.po_id,
    p.supplier_id,
    s.su_name AS supplier_name,
    p.material_id,
    p.order_quantity,
    p.received_quantity,
    p.uom,
    p.unit_cost,
    round(p.order_quantity * p.unit_cost, 2) AS order_value,
    p.status,
    if(p.received_quantity >= p.order_quantity AND p.order_quantity > 0, 'received',
       if(p.received_quantity > 0, 'partially_received', 'open')) AS receipt_state,
    round(100 * p.received_quantity / nullIf(p.order_quantity, 0), 1) AS received_pct,
    p.expected_delivery_date,
    (p.received_quantity < p.order_quantity AND p.expected_delivery_date < today()) AS is_overdue
FROM mfg_silver.v_purchase_orders_current AS p
LEFT JOIN (SELECT entity_id AS su_id, entity_name AS su_name
           FROM mfg_silver.v_reference_current WHERE entity_type = 'supplier') AS s ON p.supplier_id = s.su_id
SETTINGS join_use_nulls = 1;

-- Supplier view: order volume, value, receipt performance, overdue orders
CREATE OR REPLACE VIEW mfg_gold.supplier_summary AS
SELECT
    supplier_id,
    any(supplier_name) AS supplier_name,
    count() AS purchase_orders,
    countIf(receipt_state = 'open') AS open_orders,
    countIf(receipt_state = 'received') AS received_orders,
    countIf(is_overdue) AS overdue_orders,
    round(sum(order_value), 2) AS total_order_value,
    round(100 * sum(received_quantity) / nullIf(sum(order_quantity), 0), 1) AS received_pct
FROM mfg_gold.purchase_orders_status
GROUP BY supplier_id;
