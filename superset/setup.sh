#!/bin/bash
# Registers the ClickHouse Gold connection in Superset (run after docker compose up)
source .env
docker exec superset superset set-database-uri -d "ClickHouse Gold" -u "clickhousedb://${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}@clickhouse:8123/mfg_gold"
