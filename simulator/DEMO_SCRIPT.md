# Assessor demo script

This is a manual demo guide, not a prescribed implementation. Allow roughly 35–45 minutes per candidate, excluding initial image builds.

## Before the demo

1. Confirm that the submitted repository is private and the assessor has access.
2. Start from the candidate's documented clean-clone procedure. Confirm expected containers, Airflow UI, ClickHouse, Kafka, and Superset are reachable.
3. Confirm the candidate has configured the supplied simulator with the correct `KAFKA_BOOTSTRAP_SERVERS` and that `GET /api/v1/status` has no error.

## Core flow

1. Ask the candidate to explain their architecture in five minutes: Kafka topic layout, the ingestion path, Bronze/Silver/Gold responsibilities, Airflow's role, and how Superset reads Gold.
2. Ask them to create/provision topics using their documented mechanism and show consumer/ingestion health.
3. Request historical data from the simulator:

   ```bash
   curl -X POST http://localhost:8080/api/v1/history/publish \
     -H 'content-type: application/json' \
     -d '{"days":90,"events_per_second":500}'
   ```

4. When the simulator reports history complete, have the candidate show representative rows/counts in Bronze, Silver, and Gold. Ask them to point out source topic, source event, ingestion time, and a metric trace through each layer.
5. Start the live stream at three events/second:

   ```bash
   curl -X POST http://localhost:8080/api/v1/stream/rate \
     -H 'content-type: application/json' -d '{"events_per_second":3}'
   curl -X POST http://localhost:8080/api/v1/stream/start
   ```

6. Allow the candidate's documented Airflow cadence to run. They should show newly generated data in a Gold model and then refresh/inspect Superset.
7. Have the candidate present the required three dashboards and the metric definitions behind one visual from each.

## Data-quality tests

Use any subset below. Let the candidate run their normal orchestration; do not require instant dashboard refresh if their documented cadence is one minute.

| Test | Source call | What to ask the candidate to prove |
| --- | --- | --- |
| Duplicate pairs | `{"kind":"duplicates","count":3}` | The exact same `event_id` exists in raw intake as expected but does not double-count Silver/Gold. |
| Late events | `{"kind":"late_events","count":5}` | The event is retained; its event/business date versus ingestion date is visible and policy is followed. |
| Updates | `{"kind":"updates","count":3}` | Raw history contains the correction; curated current-state or facts obey their stated rule. |
| Deletes | `{"kind":"deletes","count":2}` | Audit evidence remains and curated records are removed/flagged/otherwise treated per their written policy. |
| Invalid records | `{"kind":"invalid","count":2}` | Record is observable with a clear rejection reason and does not corrupt trusted models. |
| Schema v2 | `{"kind":"schema_v2","count":2}` | The v2 input is intentionally accepted, routed, or quarantined according to a documented compatibility policy. |

For each test use this request shape:

```bash
curl -X POST http://localhost:8080/api/v1/faults/inject \
  -H 'content-type: application/json' \
  -d '{"kind":"duplicates","count":3}'
```

Pause the live source at the end if desired:

```bash
curl -X POST http://localhost:8080/api/v1/stream/pause
```

## Suggested follow-up questions

- Why does your Kafka-to-ClickHouse ingestion method fit this workload? What would change at higher throughput?
- What data is intentionally immutable? What can be recomputed safely?
- How do you distinguish an event that is late from an event that merely arrives after a pipeline restart?
- Why is Airflow used where it is, instead of as the real-time message consumer?
- Which dashboard metric is an approximation, and what source data would make it more exact?
- How would you migrate the v1 contract without breaking existing reports?
