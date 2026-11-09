# Manufacturing Data Platform

Data flows: ERP simulator -> Kafka -> ClickHouse (Bronze, Silver, Gold) -> Superset dashboards.
Airflow runs the pipeline `mfg_pipeline` every minute.

## How to start
1. Copy the settings file (cp .env.example .env), then replace every change_me with a real value
2. Start everything: docker compose up -d
3. Start the simulator and then live data: curl -X POST http://localhost:8080/api/v1/stream/start

## How to check it works
- Airflow: http://localhost:8081 (health: curl http://localhost:8081/health returns 200)
- Superset: http://localhost:8088
- Simulator: curl http://localhost:8080/healthz

## Layers
- Bronze (mfg_bronze): raw events, never changed.
- Silver (mfg_silver): cleaned events, bad events go to quarantine with a reason.
- Gold (mfg_gold): business views used by the dashboards.
- Ops (mfg_ops): results of the data-quality checks, one row per check per run.

## Limits
OEE and inventory balances are approximations because the source events do not carry every needed field.

## Start the simulator

The ERP simulator is included in the `simulator/` folder. Start the platform first, then:

```bash
docker build -t manufacturing-erp-simulator ./simulator
docker run -d --name erp-simulator --network mfg-net -p 8080:8080 \
  -e KAFKA_BOOTSTRAP_SERVERS=kafka:9092 manufacturing-erp-simulator
curl http://localhost:8080/healthz
curl -X POST http://localhost:8080/api/v1/stream/start
```
