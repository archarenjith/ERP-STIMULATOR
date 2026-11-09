"""Runtime configuration for the simulator."""

from __future__ import annotations

import os
from dataclasses import dataclass


TOPICS = {
    "reference": "erp.reference.v1",
    "inventory": "erp.inventory.v1",
    "purchase_orders": "erp.purchase_orders.v1",
    "work_orders": "erp.work_orders.v1",
    "machine_telemetry": "erp.machine_telemetry.v1",
    "labour_bookings": "erp.labour_bookings.v1",
    "electricity_readings": "erp.electricity_readings.v1",
    "quality_inspections": "erp.quality_inspections.v1",
    "maintenance": "erp.maintenance.v1",
    "sales_orders": "erp.sales_orders.v1",
}


@dataclass(frozen=True)
class Settings:
    kafka_bootstrap_servers: str
    kafka_client_id: str
    default_event_rate: float
    random_seed: int

    @classmethod
    def from_environment(cls) -> "Settings":
        return cls(
            kafka_bootstrap_servers=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),
            kafka_client_id=os.getenv("KAFKA_CLIENT_ID", "manufacturing-erp-simulator"),
            default_event_rate=float(os.getenv("DEFAULT_EVENT_RATE", "3")),
            random_seed=int(os.getenv("ERP_RANDOM_SEED", "20261031")),
        )
