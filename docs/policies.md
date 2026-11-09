# Data handling policies

## Late data
Late events are kept, never thrown away. Silver stores lag_hours (produced_at minus event_ts) on every event,
so late events can be found with lag_hours >= 24. This covers the historical backfill and the late_events fault.

## Duplicates
Bronze keeps every copy. Silver keeps one row per event_id. The view mfg_silver.v_duplicate_events lists
duplicated IDs, so metrics do not count an event twice.

## Updates and deletes
Every event is kept in the history tables. Each current view shows the latest event per entity.
A delete hides the entity in the current view but stays in history, so the audit trail is kept.
An event newer than a delete brings the entity back.

## Invalid data
Events that fail checks go to mfg_silver.quarantine with a reject_reason. They are never made valid.

## Schema change (event_version 2)
Version 2 is accepted as compatible. The extra schema_v2_note stays in the raw payload, and v2 rows can be found
through event_version. Any other version is quarantined as unsupported_event_version.
