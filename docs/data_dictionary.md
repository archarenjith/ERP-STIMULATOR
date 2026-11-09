# Data dictionary: Gold layer (database mfg_gold)

Gold views are built only from the Silver current-state views. Formulas for the derived percentages are in
clickhouse/ddl/005 to 007.

## Production
- production_work_orders (one row per work order, latest state): work_order_id, product_id, machine_id, machine_name, status, planned_start_date, planned_quantity, good_quantity, scrap_quantity, planned_minutes, actual_minutes, schedule_variance_minutes, yield_pct
- machine_daily: machine_id, day, runtime_minutes, idle_minutes, downtime_minutes, units_produced, readings
- machine_summary (one row per machine): machine_id, machine_name, work_center, runtime_minutes, idle_minutes, downtime_minutes, units_produced, utilisation_pct, availability_pct, yield_pct, oee_style_pct

## Inventory and procurement
- inventory_position: material_id, material_name, stock_category, uom, stock_on_hand, reorder_level, reorder_risk, movements, last_movement
- finished_goods_position: product_id, product_name, stock_on_hand, movements, last_movement
- inventory_movements_daily: day, stock_category, movement_type, movements, net_quantity, net_value
- purchase_orders_status: po_id, supplier_id, supplier_name, material_id, order_quantity, received_quantity, uom, unit_cost, order_value, status, receipt_state, received_pct, expected_delivery_date, is_overdue
- supplier_summary: supplier_id, supplier_name, purchase_orders, open_orders, received_orders, overdue_orders, total_order_value, received_pct

## Cost, quality and demand
- cost_daily: day, labour_cost, electricity_cost, material_cost, total_cost
- cost_by_machine: machine_id, machine_name, labour_cost, electricity_cost, total_cost
- quality_daily: day, product_id, product_name, inspections, sample_size, rejected_quantity, rejection_rate_pct, failed_inspections
- quality_defects: defect_code, inspections, rejected_quantity
- demand_by_product: product_id, product_name, sales_orders, ordered_quantity, shipped_quantity, open_quantity, order_value, fulfilment_pct
- sales_orders_status: sales_order_id, customer_id, product_id, product_name, ordered_quantity, shipped_quantity, open_quantity, fulfilment_pct, fulfilment_state, status, order_value, requested_delivery_date, is_overdue

## Metric definitions and limits
- Stock on hand is built from inventory movement events, so it is an approximation, not a physical count.
- oee_style_pct is an approximation of OEE. The source events carry no ideal cycle times, so exact OEE is not claimed.
- Cost covers labour, electricity and material cost per day. Material cost is the largest part. The source does not state a currency.
- Rejection rate is rejected quantity divided by inspected sample size, in percent.
- Fulfilment is shipped quantity divided by ordered quantity. It is low because the simulated orders far outnumber shipments.
