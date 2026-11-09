# Event contract

This is the stable contract for the assessment. All values are JSON. Each Kafka message has a UTF-8 key equal to `entity_id` and a JSON value. Topic names and version-1 field names must not be changed by candidates.

## Common envelope

Every **valid v1 event** contains exactly these top-level fields. `payload` varies by topic.

| Field | Type | Meaning |
| --- | --- | --- |
| `event_id` | UUID string | Unique logical event identifier; use it to deduplicate. |
| `event_type` | string | `<entity>.(created|updated|deleted)`. |
| `event_version` | integer | Contract version; normal events are `1`. |
| `event_ts` | ISO-8601 UTC timestamp | When the business event occurred. It is not necessarily arrival order. |
| `produced_at` | ISO-8601 UTC timestamp | When this simulator emitted the event. |
| `operation` | `c`, `u`, or `d` | Create, correction/update, or deletion. |
| `entity_id` | string | Business primary key for the changed entity. |
| `source` | string | Always `manufacturing_erp_simulator`. |
| `payload` | object | Topic-specific source record. |

Example valid event:

```json
{
  "event_id": "9c5e9b86-b469-4f7b-9d63-473fcd899c55",
  "event_type": "work_order.updated",
  "event_version": 1,
  "event_ts": "2026-10-29T09:15:00Z",
  "produced_at": "2026-10-31T10:12:04Z",
  "operation": "u",
  "entity_id": "WO-0000042",
  "source": "manufacturing_erp_simulator",
  "payload": {
    "work_order_id": "WO-0000042",
    "product_id": "FG-200",
    "machine_id": "MC-02",
    "planned_quantity": 120,
    "good_quantity": 80,
    "scrap_quantity": 2,
    "status": "in_progress",
    "planned_processing_minutes": 7200,
    "actual_processing_minutes": 4900,
    "planned_start_date": "2026-10-29",
    "revision_note": "source correction"
  }
}
```

## Topics and payloads

All topics use the common envelope. Required payload fields for each v1 topic follow; a candidate must preserve unrecognised payload fields rather than silently discard them.

| Topic | Entity / primary key | Required payload fields |
| --- | --- | --- |
| `erp.reference.v1` | Supplier, material, product, machine, or employee ID | `entity_type` plus the corresponding master-data fields below |
| `erp.inventory.v1` | `movement_id` | `movement_id`, `stock_category`, `movement_type`, `quantity_delta`, `uom`, `warehouse_id`, `reference_id`, `unit_cost`; exactly one of `material_id` or `product_id` |
| `erp.purchase_orders.v1` | `po_id` | `po_id`, `supplier_id`, `material_id`, `order_quantity`, `received_quantity`, `uom`, `unit_cost`, `status`, `expected_delivery_date` |
| `erp.work_orders.v1` | `work_order_id` | `work_order_id`, `product_id`, `machine_id`, `planned_quantity`, `good_quantity`, `scrap_quantity`, `status`, `planned_processing_minutes`, `actual_processing_minutes`, `planned_start_date` |
| `erp.machine_telemetry.v1` | `telemetry_id` | `telemetry_id`, `machine_id`, `machine_status`, `interval_minutes`, `runtime_minutes`, `idle_minutes`, `downtime_minutes`, `downtime_reason`, `units_produced`, `work_order_id` |
| `erp.labour_bookings.v1` | `booking_id` | `booking_id`, `employee_id`, `machine_id`, `work_order_id`, `minutes_worked`, `hourly_cost`, `shift`, `activity` |
| `erp.electricity_readings.v1` | `reading_id` | `reading_id`, `meter_id`, `machine_id`, `interval_minutes`, `energy_kwh`, `tariff_per_kwh` |
| `erp.quality_inspections.v1` | `inspection_id` | `inspection_id`, `work_order_id`, `product_id`, `sample_size`, `accepted_quantity`, `rejected_quantity`, `result`, `defect_code` |
| `erp.maintenance.v1` | `maintenance_id` | `maintenance_id`, `machine_id`, `maintenance_type`, `status`, `planned_minutes`, `actual_minutes`, `maintenance_cost`, `reason_code` |
| `erp.sales_orders.v1` | `sales_order_id` | `sales_order_id`, `customer_id`, `product_id`, `ordered_quantity`, `shipped_quantity`, `unit_price`, `status`, `requested_delivery_date` |

### Reference payloads

`erp.reference.v1` is a heterogeneous master-data topic. It always includes `entity_type` and uses one of these field sets:

| `entity_type` | Fields |
| --- | --- |
| `supplier` | `supplier_id`, `supplier_name`, `country`, `rating` |
| `material` | `material_id`, `material_name`, `uom`, `reorder_level` |
| `product` | `product_id`, `product_name`, `uom`, `standard_cycle_minutes` |
| `machine` | `machine_id`, `machine_name`, `work_center`, `rated_kw` |
| `employee` | `employee_id`, `employee_name`, `role` |

## Temporal and change semantics

- The 90-day seed is generated chronologically. It contains reference data and operational history.
- A live feed produces 2–5 events/second when started (3 by default); `event_ts` is the business timestamp and may differ from Kafka arrival time.
- An update has a **new `event_id`**, the same `entity_id`, `operation: "u"`, and a complete corrected record in `payload`.
- A delete has a **new `event_id`**, `operation: "d"`, and a payload with `deleted_reason` and `previous_record`. It is an application-level delete event, not a Kafka null-value tombstone.
- An event's `reference_id` and `work_order_id` are usually joinable to prior source entities. At the beginning of the seed a small number of valid forward references can exist; robust pipelines must not assume parent-first arrival.

## Deliberately injected edge cases

Use `POST /api/v1/faults/inject` only after the normal pipeline is working. These are contractual conditions candidates must demonstrate handling for.

| `kind` | Behaviour | Expected treatment |
| --- | --- | --- |
| `late_events` | Valid events whose `event_ts` is 24–72 hours before `produced_at`. | Retain and expose late-arrival handling; do not discard silently. |
| `duplicates` | Each requested count creates an original plus an identical copy, including the same `event_id`. | Deduplicate idempotently. |
| `updates` | Valid corrections for existing entities. | Keep raw history; reflect the latest valid state in curated state models. |
| `deletes` | Valid application-level deletes for existing entities. | Keep audit history and apply a documented curated-layer policy. |
| `invalid` | Removes `event_ts` and changes `event_version` to string `"one"`. | Quarantine/reject with a visible reason; do not make it silently valid. |
| `schema_v2` | Sets `event_version` to `2` and adds `payload.schema_v2_note`. | Preserve raw data and implement/document a compatible or quarantined policy. |

There are no hidden fields or hidden events. Candidates may add metadata in their own pipeline, but must preserve the source event and the original source topic in Bronze.
