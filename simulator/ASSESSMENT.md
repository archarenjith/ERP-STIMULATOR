# Manufacturing analytics platform assessment

## Objective

Individually build a reproducible local manufacturing analytics platform that ingests the supplied ERP simulator's Kafka events and exposes trusted analytical dashboards in Apache Superset.

You have **4–5 days**. This repository is the source system and event contract only. Your repository must contain your complete solution; it must be private and you must grant the assessor access before the demonstration.

## Required technology and boundaries

- Run your solution locally with Docker Compose. You are responsible for provisioning and configuring Docker services.
- Use Kafka for continuous event transport and ClickHouse as the only Bronze, Silver, and Gold data store.
- Use SQL for transformations.
- Use Airflow for orchestration, quality checks, retry/failure behaviour, and repeatable transformation runs. Airflow is not required to be the continuous Kafka consumer.
- Use Apache Superset for the final dashboards.
- Point the supplied ERP simulator at your Kafka bootstrap address. Do not change topic names, the supplied source code, or the v1 contract to simplify ingestion.
- You may select any valid Kafka-to-ClickHouse pattern. Explain the choice and trade-offs in your README.

## Functional requirements

1. **Platform startup.** A fresh clone must have clear, tested startup instructions. The assessor should be able to bring up required services and see health/status information without hand-editing source code.
2. **Kafka ingestion.** Provision and consume all ten contracted topics. Configure durable retention appropriate for a local demo and demonstrate that a consumer restart does not create unmanageable duplication.
3. **Bronze in ClickHouse.** Store the raw source event, source topic, Kafka metadata where available, and an ingestion timestamp. Bronze must be append-oriented and auditable; do not replace it with only typed current-state tables.
4. **Silver in ClickHouse.** Validate and type the records. Implement documented handling for duplicate events, late data, updates, deletes, invalid events, and `event_version = 2`. Invalid records must be observable in a quarantine/reject path with a reason.
5. **Gold in ClickHouse.** Build documented business-ready models that support the dashboard metrics below. Gold must be produced from your curated data, not directly from Kafka or raw JSON.
6. **Airflow.** Provide version-controlled DAGs that run the SQL transformations and quality checks at a reasonable short interval (for example, every minute). Include useful retry/logging behaviour and a way to rerun safely.
7. **Superset.** Configure data access to ClickHouse and create the required dashboards. Include importable dashboard/dataset assets or precise repeatable setup instructions.

## Required analytical outcomes

Create at least three dashboards, covering all of the following:

- **Production and machines:** throughput, planned vs actual processing time, runtime/idle/downtime, machine utilisation, and a documented OEE-style or equivalent operational calculation.
- **Inventory and procurement:** raw-material position/movements, finished-goods position, reorder-risk view, open/received purchase orders, and supplier view.
- **Cost, quality, and demand:** labour cost, electricity cost, material/production cost where justified by available data, defects/rejection rate, and sales-order demand or fulfilment status.

Clearly state every metric definition and any assumptions/limitations. Do not claim exact inventory balances or OEE if the source fields only support an approximation.

## Mandatory test scenario

During the demo, the assessor will start/pause the live source and request one or more fault types through the supplied REST API. Your platform must make the following outcomes visible:

- historical seed data and newly arrived live data are queryable;
- duplicate event IDs do not double-count curated metrics;
- a late event is retained and shown/handled according to your policy;
- a correction and a deletion change the curated state according to your documented policy while audit history remains available;
- invalid data is quarantined with a reason;
- a v2 event does not silently corrupt the pipeline.

## Submission contents

- Private GitHub repository; grant the assessor access.
- `docker-compose.yml` (or an equally clear Compose entry point), environment template, and startup guide.
- Dockerfiles/configuration, Kafka topic/configuration scripts, Airflow DAGs, SQL models/scripts, ClickHouse DDL, and Superset configuration/export or reproducible setup steps.
- A concise architecture diagram and data-flow explanation.
- A data dictionary, metric definitions, and documented policies for late data, duplicates, updates/deletes, invalid data, and schema change.
- Evidence of tests or repeatable validation queries.
- No secrets committed to Git. Include only templates/placeholders.

## Non-goals

You do not need to build a production-grade ERP, a cloud deployment, multi-node ClickHouse/Kafka cluster, or application authentication. Judgement, reproducibility, data correctness, and clear reasoning matter more than adopting a specific ingestion framework.
