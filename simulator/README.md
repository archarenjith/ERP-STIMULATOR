# Manufacturing ERP Simulator — assessment source

This repository is the **source system supplied to assessment candidates**. It simulates a manufacturing ERP, retains a small in-memory operational state, and publishes JSON events to Kafka. It contains no Kafka, ClickHouse, Airflow, Superset, or solution Docker Compose configuration.

Candidates build that analytics platform themselves, then point this service at their Kafka bootstrap server.

## What it publishes

| Topic | Content |
| --- | --- |
| `erp.reference.v1` | suppliers, raw materials, products, machines, employees |
| `erp.inventory.v1` | raw-material and finished-goods movements |
| `erp.purchase_orders.v1` | supplier purchase orders and receipt updates |
| `erp.work_orders.v1` | manufacturing orders and production progress |
| `erp.machine_telemetry.v1` | machine status, runtime, idle time, downtime, output |
| `erp.labour_bookings.v1` | shift labour/time and hourly cost |
| `erp.electricity_readings.v1` | machine-level energy readings and tariffs |
| `erp.quality_inspections.v1` | inspections, defects, and rejects |
| `erp.maintenance.v1` | scheduled/corrective maintenance |
| `erp.sales_orders.v1` | demand and shipment updates |

The authoritative contract is [EVENT_CONTRACT.md](EVENT_CONTRACT.md). Kafka topics must exist and be writable before data is published; the simulator intentionally does **not** create them.

## Run the simulator

The source can run on the host or as a service in a candidate's own Docker Compose stack. Copy the sample environment and set the bootstrap hostname that is reachable *from the simulator process/container*.

```bash
cp .env.example .env
docker build -t manufacturing-erp-simulator:latest .
docker run --rm --env-file .env -p 8080:8080 manufacturing-erp-simulator:latest
```

For a candidate's Compose setup, the equivalent service is intentionally only illustrative:

```yaml
erp-simulator:
  build: ./manufacturing-erp-assessment
  environment:
    KAFKA_BOOTSTRAP_SERVERS: kafka:9092
  ports:
    - "8080:8080"
```

Open `http://localhost:8080/docs` to use the interactive API documentation. `GET /healthz` succeeds even when Kafka is unavailable; publishing failures are reported at `GET /api/v1/status`.

## Control the feed

Data does not flow until it is explicitly requested. The normal live rate defaults to **3 events/second** and can be set from 0.1–50 events/second.

```bash
# Publish reference data plus 90 days of history; returns immediately, then publishes at 500 events/s.
curl -X POST http://localhost:8080/api/v1/history/publish \
  -H 'content-type: application/json' \
  -d '{"days":90,"events_per_second":500}'

# Check history completion / Kafka errors.
curl http://localhost:8080/api/v1/status

# Begin or pause the ongoing 2–5 events/s live feed.
curl -X POST http://localhost:8080/api/v1/stream/start
curl -X POST http://localhost:8080/api/v1/stream/rate \
  -H 'content-type: application/json' -d '{"events_per_second":3}'
curl -X POST http://localhost:8080/api/v1/stream/pause
```

## Test data-quality handling

Faults are deliberately emitted only when requested. They are intended for the assessment demo—not as a hidden grading trick.

```bash
# Replace `late_events` with duplicates, updates, deletes, invalid, or schema_v2.
curl -X POST http://localhost:8080/api/v1/faults/inject \
  -H 'content-type: application/json' \
  -d '{"kind":"late_events","count":10}'
```

`duplicates` emits two byte-for-byte identical events per requested count. `invalid` violates the documented envelope by removing `event_ts` and making `event_version` a string. `schema_v2` changes the version to `2` and adds an optional payload field. The candidate should make these conditions observable and handle them according to their documented policy.

`POST /api/v1/reset` only resets the in-memory generator and pauses live streaming. It never deletes existing Kafka records, topics, or downstream data.

## Local development

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
make run
```

Run the lightweight contract/generator checks with `make test`.

## Included assessor material

- [ASSESSMENT.md](ASSESSMENT.md) — the candidate brief and submission rules
- [EVENT_CONTRACT.md](EVENT_CONTRACT.md) — Kafka topics, envelope, event payloads, and expected edge cases
- [DEMO_SCRIPT.md](DEMO_SCRIPT.md) — manual assessment sequence
- [RUBRIC.md](RUBRIC.md) — 100-point manual scoring guide
