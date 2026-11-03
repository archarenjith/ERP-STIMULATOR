#!/bin/bash
set -euo pipefail
BS=kafka:9092
TOPICS="erp.reference.v1 erp.inventory.v1 erp.purchase_orders.v1 erp.work_orders.v1 erp.machine_telemetry.v1 erp.labour_bookings.v1 erp.electricity_readings.v1 erp.quality_inspections.v1 erp.maintenance.v1 erp.sales_orders.v1"
for t in $TOPICS; do
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BS" --create --if-not-exists \
    --topic "$t" --partitions 1 --replication-factor 1 \
    --config retention.ms=604800000
done
/opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BS" --list