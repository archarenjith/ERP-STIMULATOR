"""mfg_pipeline: Silver loads + data-quality checks, every minute.

All SQL lives in clickhouse/sql/silver/*.sql (mounted read-only into the container).
Every load is idempotent (ReplacingMergeTree + incremental window), so retries and
manual reruns are safe. Gold models are views over Silver, so they need no task.
"""
import logging
import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.exceptions import AirflowException
from airflow.operators.python import PythonOperator

SQL_DIR = "/opt/airflow/clickhouse/sql/silver"
log = logging.getLogger(__name__)


def _client():
    import clickhouse_connect

    return clickhouse_connect.get_client(
        host=os.environ["CLICKHOUSE_HOST"],
        port=int(os.environ.get("CLICKHOUSE_PORT", "8123")),
        username=os.environ["CLICKHOUSE_USER"],
        password=os.environ["CLICKHOUSE_PASSWORD"],
    )


def _statements(path):
    with open(path) as f:
        lines = [ln for ln in f.read().splitlines() if not ln.strip().startswith("--")]
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]


def run_sql_files(files):
    client = _client()
    for name in files:
        stmts = _statements(os.path.join(SQL_DIR, name))
        log.info("Running %s (%d statements)", name, len(stmts))
        for stmt in stmts:
            client.command(stmt)


TYPED_TABLES = [
    "work_orders_history", "machine_telemetry_history", "labour_bookings_history",
    "electricity_readings_history", "inventory_movements_history", "purchase_orders_history",
    "quality_inspections_history", "maintenance_history", "sales_orders_history",
    "reference_history",
]
_typed_sum = " + ".join(f"(SELECT count() FROM mfg_silver.{t} FINAL)" for t in TYPED_TABLES)

# Each check returns the number of violations; 0 means pass.
CHECKS = {
    "silver_no_duplicate_event_ids":
        "SELECT count() - uniqExact(event_id) FROM mfg_silver.v_events",
    "bronze_valid_events_all_in_silver":
        "SELECT count() FROM (SELECT DISTINCT event_id FROM mfg_silver.v_bronze_parsed "
        "WHERE reject_reason = '' AND ingested_at < now64(3) - INTERVAL 2 MINUTE "
        "AND event_id NOT IN (SELECT event_id FROM mfg_silver.events))",
    "bronze_invalid_events_all_quarantined":
        "SELECT count() FROM mfg_silver.v_bronze_parsed "
        "WHERE reject_reason != '' AND ingested_at < now64(3) - INTERVAL 2 MINUTE "
        "AND (source_topic, bronze_partition, bronze_offset) NOT IN "
        "(SELECT source_topic, bronze_partition, bronze_offset FROM mfg_silver.quarantine)",
    "quarantine_rows_have_reason":
        "SELECT count() FROM mfg_silver.v_quarantine WHERE reject_reason = ''",
    "typed_tables_equal_silver_events":
        f"SELECT abs((SELECT count() FROM mfg_silver.v_events) - ({_typed_sum}))",
    "gold_work_orders_match_silver":
        "SELECT abs((SELECT count() FROM mfg_gold.production_work_orders) "
        "- (SELECT count() FROM mfg_silver.v_work_orders_current))",
}


def quality_checks(run_id=None, **_):
    client = _client()
    rows, failed = [], []
    for name, sql in CHECKS.items():
        violations = int(client.query(sql).result_rows[0][0])
        passed = 1 if violations == 0 else 0
        log.info("DQ %-40s violations=%d %s", name, violations, "PASS" if passed else "FAIL")
        rows.append([run_id or "manual", name, violations, passed])
        if not passed:
            failed.append(f"{name}={violations}")
    client.insert("mfg_ops.dq_results", rows, column_names=["run_id", "check_name", "violations", "passed"])
    if failed:
        raise AirflowException("Data-quality checks failed: " + ", ".join(failed))


default_args = {
    "owner": "data-eng",
    "retries": 2,
    "retry_delay": timedelta(seconds=10),
}

with DAG(
    dag_id="mfg_pipeline",
    description="Bronze -> Silver loads and data-quality checks (every minute)",
    start_date=datetime(2026, 1, 1),
    schedule="* * * * *",
    catchup=False,
    max_active_runs=1,
    is_paused_upon_creation=False,
    dagrun_timeout=timedelta(minutes=5),
    default_args=default_args,
    tags=["mfg", "silver", "quality"],
) as dag:
    load_events = PythonOperator(
        task_id="load_silver_events",
        python_callable=run_sql_files,
        op_args=[["10_load_events.sql", "11_load_quarantine.sql"]],
    )
    load_typed = PythonOperator(
        task_id="load_silver_typed",
        python_callable=run_sql_files,
        op_args=[["20_load_work_orders.sql", "21_load_other_topics.sql"]],
    )
    dq = PythonOperator(task_id="quality_checks", python_callable=quality_checks)

    load_events >> load_typed >> dq
