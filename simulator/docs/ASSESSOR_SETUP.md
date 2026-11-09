# Publishing and administering the assessment

## Publish the source

1. Create a new **private** GitHub repository owned by the assessor or training organisation.
2. Copy this directory's complete contents into it and push the initial commit.
3. Give candidates read access to this source repository, or distribute an archive of it.
4. Share [ASSESSMENT.md](../ASSESSMENT.md), [EVENT_CONTRACT.md](../EVENT_CONTRACT.md), and the assessment deadline. Keep [RUBRIC.md](../RUBRIC.md) and this guide assessor-only if you do not want the scoring details shared.

The simulator repository deliberately has no `docker-compose.yml` for Kafka, ClickHouse, Airflow, or Superset. Candidates must create those services in their own private solution repository.

## Candidate handoff text

> You have 4–5 days to complete this individual assessment. Build a local Docker Compose solution using Kafka, ClickHouse, Airflow, SQL transformations, and Apache Superset. The supplied ERP simulator is the event source only; do not alter its topic names or contract. Submit a private GitHub repository and grant the assessor access before your demo. Follow `ASSESSMENT.md` and `EVENT_CONTRACT.md` exactly.

## Before every candidate demo

- Ask the candidate to run the simulator on port 8080, connected to their Kafka broker.
- Confirm `curl http://localhost:8080/healthz` returns `{"status":"ok"}`.
- Confirm `curl http://localhost:8080/api/v1/status` has `"last_error": null` after a small source test.
- Do not use `POST /api/v1/reset` as a cleanup mechanism for Kafka. It does not delete topics or downstream tables. Have candidates document their own reset/cleanup procedure for their platform.
- Use [DEMO_SCRIPT.md](../DEMO_SCRIPT.md) and record rubric evidence consistently.

## Fairness safeguards

- State whether documentation, use of external libraries, and AI assistance are permitted before work begins.
- Give every candidate the same contract, time window, and selected fault scenarios.
- Permit equivalent ingestion patterns; grade the documented behaviour and evidence, not a tool preference.
- Avoid injecting invalid events before candidates have shown baseline historical/live ingestion.
