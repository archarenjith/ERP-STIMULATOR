#!/bin/bash
# Run SQL from stdin against the platform ClickHouse
docker exec -i clickhouse sh -c 'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --multiquery'
