-- 008_ops.sql : operational tables (data-quality check results)
CREATE DATABASE IF NOT EXISTS mfg_ops;

CREATE TABLE IF NOT EXISTS mfg_ops.dq_results
(
    checked_at  DateTime64(3, 'UTC') DEFAULT now64(3),
    run_id      String,
    check_name  LowCardinality(String),
    violations  Int64,
    passed      UInt8
)
ENGINE = MergeTree
ORDER BY (checked_at, check_name)
TTL toDateTime(checked_at) + INTERVAL 30 DAY;
