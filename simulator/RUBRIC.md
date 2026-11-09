# Manual assessment rubric (100 points)

Score outcomes demonstrated in the candidate's repository and demo. Equivalent designs are valid; do not deduct merely because a candidate did not use a preferred framework.

| Area | Points | Full-credit evidence |
| --- | ---: | --- |
| Reproducibility and documentation | 10 | Clear clean-clone startup, versioned configuration/templates, sensible service health checks, architecture/data-flow diagram, no secrets. |
| Kafka and source integration | 10 | All contracted topics are usable; simulator connects without source modifications; topic/consumer choices and restart behaviour are explained. |
| Bronze layer | 15 | Immutable/auditable ClickHouse intake with raw event, source topic, useful Kafka metadata where available, and ingestion timestamp; source records can be traced. |
| Silver layer and data quality | 20 | Typed/validated tables, idempotent duplicate handling, late-data treatment, updates/deletes policy, invalid-event quarantine with reasons, and v2 policy all work in the demo. |
| Gold models and SQL quality | 15 | Useful documented business models in ClickHouse; transformations are SQL-led, readable, safe to rerun, and do not bypass Silver. |
| Airflow orchestration and operations | 15 | Versioned DAGs run transformations and quality checks on a short cadence; sensible retries/logs, recoverability, and observable failures. |
| Superset analytics | 10 | At least three usable dashboards cover all required business areas, read trusted Gold data, and state meaningful metric definitions. |
| Engineering judgement | 5 | Clear trade-offs, appropriate local scope, tests/validation queries, clean repository structure, and accurate limitations. |

## Score anchors

- **90–100:** Reproducible, complete, and robust under all selected fault demonstrations; clearly reasoned design and trustworthy analytics.
- **75–89:** Complete core pipeline and dashboards with small operational/documentation gaps or a limited edge-case weakness.
- **60–74:** Basic end-to-end path works but significant gaps exist in quality handling, orchestration, reproducibility, or analytical depth.
- **Below 60:** Cannot reliably demonstrate a working pipeline from simulator to Superset, lacks the required technologies/layers, or cannot explain data correctness.

## Critical evidence to record

For fair comparison, note whether each candidate demonstrated: historical + live ingestion; three-layer ClickHouse layout; duplicate, late, update/delete, invalid, and v2 behaviour; Airflow runs; all required dashboard domains; clean-start instructions; and assessor access to the private repository.

An implementation may lose points in a section without invalidating the whole submission. However, a dashboard reading only raw Kafka/JSON, no ClickHouse medallion layers, or a non-reproducible environment cannot meet the core requirements.
