"""Deterministic, stateful manufacturing events for the assessment source."""

from __future__ import annotations

import copy
import random
import uuid
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from .catalog import EMPLOYEES, MACHINES, MATERIALS, PRODUCTS, SUPPLIERS, all_reference_records
from .config import TOPICS


DOMAIN_TOPIC = {
    "inventory": "inventory",
    "purchase_order": "purchase_orders",
    "work_order": "work_orders",
    "machine_telemetry": "machine_telemetry",
    "labour_booking": "labour_bookings",
    "electricity_reading": "electricity_readings",
    "quality_inspection": "quality_inspections",
    "maintenance": "maintenance",
    "sales_order": "sales_orders",
}


def isoformat_z(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


class EventFactory:
    """Produces valid envelopes and retains enough state to issue corrections/deletes."""

    def __init__(self, seed: int) -> None:
        self.random = random.Random(seed)
        self.sequence = defaultdict(int)
        self.known: dict[str, dict[str, dict[str, Any]]] = defaultdict(dict)

    def _id(self, prefix: str) -> str:
        self.sequence[prefix] += 1
        return f"{prefix}-{self.sequence[prefix]:07d}"

    def _pick(self, records: list[dict[str, Any]]) -> dict[str, Any]:
        return self.random.choice(records)

    def _known_id(self, domain: str, fallback_prefix: str) -> str:
        """Use a real prior entity when possible, creating a harmless reference otherwise."""
        known = self.known[domain]
        return self.random.choice(list(known)) if known else self._id(fallback_prefix)

    def _event(
        self,
        *,
        domain: str,
        entity_id: str,
        operation: str,
        payload: dict[str, Any],
        event_time: datetime,
        version: int = 1,
    ) -> dict[str, Any]:
        action = {"c": "created", "u": "updated", "d": "deleted"}[operation]
        return {
            "event_id": str(uuid.uuid4()),
            "event_type": f"{domain}.{action}",
            "event_version": version,
            "event_ts": isoformat_z(event_time),
            "produced_at": isoformat_z(datetime.now(timezone.utc)),
            "operation": operation,
            "entity_id": entity_id,
            "source": "manufacturing_erp_simulator",
            "payload": payload,
        }

    def reference_events(self, event_time: datetime | None = None) -> list[tuple[str, dict[str, Any]]]:
        moment = event_time or datetime.now(timezone.utc)
        result: list[tuple[str, dict[str, Any]]] = []
        for entity_type, record in all_reference_records():
            identifier = next(value for key, value in record.items() if key.endswith("_id"))
            payload = {"entity_type": entity_type, **record}
            result.append(
                (
                    TOPICS["reference"],
                    self._event(
                        domain="reference",
                        entity_id=identifier,
                        operation="c",
                        payload=payload,
                        event_time=moment,
                    ),
                )
            )
        return result

    def _new_payload(self, domain: str, moment: datetime) -> tuple[str, dict[str, Any]]:
        date_value = moment.date().isoformat()
        if domain == "inventory":
            movement_id = self._id("INV")
            is_finished_goods = self.random.random() < 0.27
            if is_finished_goods:
                product = self._pick(PRODUCTS)
                is_receipt = self.random.random() < 0.58
                return movement_id, {
                    "movement_id": movement_id,
                    "product_id": product["product_id"],
                    "stock_category": "finished_goods",
                    "movement_type": "production_receipt" if is_receipt else "customer_shipment",
                    "quantity_delta": self.random.randint(8, 80) if is_receipt else -self.random.randint(5, 60),
                    "uom": product["uom"],
                    "warehouse_id": "WH-FG-01",
                    "reference_id": self._known_id("work_order", "WOREF") if is_receipt else self._known_id("sales_order", "SOREF"),
                    "unit_cost": round(self.random.uniform(40, 480), 2),
                }
            material = self._pick(MATERIALS)
            is_receipt = self.random.random() < 0.36
            return movement_id, {
                "movement_id": movement_id,
                "material_id": material["material_id"],
                "stock_category": "raw_material",
                "movement_type": "purchase_receipt" if is_receipt else "production_issue",
                "quantity_delta": self.random.randint(100, 900) if is_receipt else -self.random.randint(10, 180),
                "uom": material["uom"],
                "warehouse_id": self.random.choice(["WH-RAW-01", "WH-RAW-02"]),
                "reference_id": self._known_id("purchase_order", "POREF") if is_receipt else self._known_id("work_order", "WOREF"),
                "unit_cost": round(self.random.uniform(4, 160), 2),
            }
        if domain == "purchase_order":
            material = self._pick(MATERIALS)
            supplier = self._pick(SUPPLIERS)
            po_id = self._id("PO")
            ordered = self.random.randint(500, 3_000)
            return po_id, {
                "po_id": po_id,
                "supplier_id": supplier["supplier_id"],
                "material_id": material["material_id"],
                "order_quantity": ordered,
                "received_quantity": 0,
                "uom": material["uom"],
                "unit_cost": round(self.random.uniform(4, 160), 2),
                "status": "approved",
                "expected_delivery_date": (moment.date() + timedelta(days=self.random.randint(2, 14))).isoformat(),
            }
        if domain == "work_order":
            product = self._pick(PRODUCTS)
            machine = self._pick(MACHINES)
            work_order_id = self._id("WO")
            planned_quantity = self.random.randint(40, 300)
            return work_order_id, {
                "work_order_id": work_order_id,
                "product_id": product["product_id"],
                "machine_id": machine["machine_id"],
                "planned_quantity": planned_quantity,
                "good_quantity": 0,
                "scrap_quantity": 0,
                "status": "released",
                "planned_processing_minutes": planned_quantity * product["standard_cycle_minutes"],
                "actual_processing_minutes": 0,
                "planned_start_date": date_value,
            }
        if domain == "machine_telemetry":
            machine = self._pick(MACHINES)
            status = self.random.choices(["running", "idle", "down"], weights=[0.72, 0.20, 0.08])[0]
            telemetry_id = self._id("TEL")
            return telemetry_id, {
                "telemetry_id": telemetry_id,
                "machine_id": machine["machine_id"],
                "machine_status": status,
                "interval_minutes": self.random.choice([1, 5, 10]),
                "runtime_minutes": self.random.randint(1, 10) if status == "running" else 0,
                "idle_minutes": self.random.randint(1, 10) if status == "idle" else 0,
                "downtime_minutes": self.random.randint(1, 10) if status == "down" else 0,
                "downtime_reason": self.random.choice(["tool_change", "material_shortage", "unplanned_failure"]) if status == "down" else None,
                "units_produced": self.random.randint(1, 12) if status == "running" else 0,
                "work_order_id": self._known_id("work_order", "WOREF"),
            }
        if domain == "labour_booking":
            employee = self._pick(EMPLOYEES)
            machine = self._pick(MACHINES)
            booking_id = self._id("LAB")
            minutes = self.random.choice([30, 60, 120, 240, 480])
            return booking_id, {
                "booking_id": booking_id,
                "employee_id": employee["employee_id"],
                "machine_id": machine["machine_id"],
                "work_order_id": self._known_id("work_order", "WOREF"),
                "minutes_worked": minutes,
                "hourly_cost": round(self.random.uniform(12, 28), 2),
                "shift": self.random.choice(["A", "B", "C"]),
                "activity": self.random.choice(["production", "setup", "inspection", "rework"]),
            }
        if domain == "electricity_reading":
            machine = self._pick(MACHINES)
            reading_id = self._id("ELEC")
            interval = self.random.choice([5, 10, 15])
            return reading_id, {
                "reading_id": reading_id,
                "meter_id": f"METER-{machine['machine_id']}",
                "machine_id": machine["machine_id"],
                "interval_minutes": interval,
                "energy_kwh": round(machine["rated_kw"] * interval / 60 * self.random.uniform(0.35, 0.92), 3),
                "tariff_per_kwh": round(self.random.uniform(0.08, 0.16), 3),
            }
        if domain == "quality_inspection":
            product = self._pick(PRODUCTS)
            inspection_id = self._id("QC")
            sampled = self.random.randint(5, 50)
            rejected = self.random.randint(1, max(1, sampled // 5)) if self.random.random() < 0.14 else 0
            return inspection_id, {
                "inspection_id": inspection_id,
                "work_order_id": self._known_id("work_order", "WOREF"),
                "product_id": product["product_id"],
                "sample_size": sampled,
                "accepted_quantity": sampled - rejected,
                "rejected_quantity": rejected,
                "result": "fail" if rejected else "pass",
                "defect_code": self.random.choice(["DIMENSION", "SURFACE", "ASSEMBLY"]) if rejected else None,
            }
        if domain == "maintenance":
            machine = self._pick(MACHINES)
            maintenance_id = self._id("MNT")
            return maintenance_id, {
                "maintenance_id": maintenance_id,
                "machine_id": machine["machine_id"],
                "maintenance_type": self.random.choice(["preventive", "corrective", "inspection"]),
                "status": "scheduled",
                "planned_minutes": self.random.choice([30, 60, 120, 240]),
                "actual_minutes": 0,
                "maintenance_cost": 0,
                "reason_code": self.random.choice(["calendar", "vibration", "breakdown"]),
            }
        if domain == "sales_order":
            product = self._pick(PRODUCTS)
            sales_order_id = self._id("SO")
            ordered = self.random.randint(10, 200)
            return sales_order_id, {
                "sales_order_id": sales_order_id,
                "customer_id": f"CUST-{self.random.randint(1, 25):03}",
                "product_id": product["product_id"],
                "ordered_quantity": ordered,
                "shipped_quantity": 0,
                "unit_price": round(self.random.uniform(80, 850), 2),
                "status": "confirmed",
                "requested_delivery_date": (moment.date() + timedelta(days=self.random.randint(3, 21))).isoformat(),
            }
        raise ValueError(f"Unsupported domain: {domain}")

    def _update_payload(self, domain: str, payload: dict[str, Any]) -> dict[str, Any]:
        updated = copy.deepcopy(payload)
        if domain == "purchase_order":
            updated["received_quantity"] = min(
                updated["order_quantity"], updated.get("received_quantity", 0) + self.random.randint(50, 500)
            )
            updated["status"] = "received" if updated["received_quantity"] == updated["order_quantity"] else "partially_received"
        elif domain == "work_order":
            produced = self.random.randint(5, 40)
            updated["good_quantity"] = min(updated["planned_quantity"], updated.get("good_quantity", 0) + produced)
            updated["scrap_quantity"] = updated.get("scrap_quantity", 0) + (1 if self.random.random() < 0.10 else 0)
            updated["actual_processing_minutes"] = updated.get("actual_processing_minutes", 0) + self.random.randint(20, 120)
            updated["status"] = "completed" if updated["good_quantity"] >= updated["planned_quantity"] else "in_progress"
        elif domain == "maintenance":
            updated["actual_minutes"] = updated["planned_minutes"] + self.random.randint(-10, 45)
            updated["maintenance_cost"] = round(self.random.uniform(40, 800), 2)
            updated["status"] = "completed"
        elif domain == "sales_order":
            updated["shipped_quantity"] = min(updated["ordered_quantity"], updated.get("shipped_quantity", 0) + self.random.randint(5, 60))
            updated["status"] = "shipped" if updated["shipped_quantity"] == updated["ordered_quantity"] else "partially_shipped"
        elif domain == "quality_inspection":
            updated["result"] = "pass" if updated["rejected_quantity"] == 0 else "rework_required"
        elif domain == "inventory":
            updated["unit_cost"] = round(updated["unit_cost"] * self.random.uniform(0.96, 1.04), 2)
        else:
            updated["corrected"] = True
        updated["revision_note"] = "source correction"
        return updated

    def next_event(
        self,
        event_time: datetime | None = None,
        forced_domain: str | None = None,
        forced_operation: str | None = None,
    ) -> tuple[str, dict[str, Any]]:
        moment = event_time or datetime.now(timezone.utc)
        domain = forced_domain or self.random.choice(list(DOMAIN_TOPIC))
        known_for_domain = self.known[domain]
        operation = forced_operation
        if operation is None:
            roll = self.random.random()
            operation = "u" if known_for_domain and roll < 0.16 else "d" if known_for_domain and roll < 0.19 else "c"
        if operation in {"u", "d"} and not known_for_domain:
            operation = "c"

        if operation == "c":
            entity_id, payload = self._new_payload(domain, moment)
            self.known[domain][entity_id] = copy.deepcopy(payload)
        else:
            entity_id = self.random.choice(list(known_for_domain))
            original = known_for_domain[entity_id]
            if operation == "u":
                payload = self._update_payload(domain, original)
                self.known[domain][entity_id] = copy.deepcopy(payload)
            else:
                payload = {"deleted_reason": "source_cleanup", "previous_record": original}
                del self.known[domain][entity_id]
        return TOPICS[DOMAIN_TOPIC[domain]], self._event(
            domain=domain,
            entity_id=entity_id,
            operation=operation,
            payload=payload,
            event_time=moment,
        )

    def historical_events(self, days: int = 90) -> list[tuple[str, dict[str, Any]]]:
        """Create about 1,700 chronological events, spanning the requested interval."""
        start = datetime.now(timezone.utc) - timedelta(days=days)
        output = self.reference_events(start)
        for day in range(days):
            day_start = start + timedelta(days=day)
            for _ in range(18):
                output.append(self.next_event(day_start + timedelta(minutes=self.random.randint(0, 1_439))))
        return output

    def fault_events(self, kind: str, count: int) -> list[tuple[str, dict[str, Any]]]:
        now = datetime.now(timezone.utc)
        if kind == "late_events":
            return [self.next_event(now - timedelta(hours=self.random.randint(24, 72))) for _ in range(count)]
        if kind == "duplicates":
            result: list[tuple[str, dict[str, Any]]] = []
            for _ in range(count):
                topic, event = self.next_event(now)
                result.extend([(topic, event), (topic, copy.deepcopy(event))])
            return result
        if kind in {"updates", "deletes"}:
            operation = "u" if kind == "updates" else "d"
            return [self.next_event(now, forced_operation=operation) for _ in range(count)]
        if kind == "invalid":
            result = []
            for _ in range(count):
                topic, event = self.next_event(now)
                event.pop("event_ts")
                event["event_version"] = "one"  # Intentionally violates the documented contract.
                result.append((topic, event))
            return result
        if kind == "schema_v2":
            result = []
            for _ in range(count):
                topic, event = self.next_event(now)
                event["event_version"] = 2
                event["payload"]["schema_v2_note"] = "new optional field; consumer compatibility test"
                result.append((topic, event))
            return result
        raise ValueError(f"Unsupported fault type: {kind}")
