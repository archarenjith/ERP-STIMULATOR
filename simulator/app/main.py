"""FastAPI control plane for the manufacturing ERP event source."""

from __future__ import annotations

from fastapi import FastAPI, HTTPException

from .config import TOPICS, Settings
from .models import FaultRequest, HistoryRequest, RateRequest
from .simulator import Simulator

settings = Settings.from_environment()
simulator = Simulator(settings)

app = FastAPI(
    title="Manufacturing ERP Simulator",
    version="1.0.0",
    description="Assessment-only source system. It publishes JSON events but never creates Kafka topics.",
)


@app.get("/")
def root() -> dict:
    return {"service": "manufacturing-erp-simulator", "docs": "/docs", "status": "/api/v1/status"}


@app.get("/healthz")
def healthcheck() -> dict:
    return {"status": "ok"}


@app.get("/api/v1/status")
def status() -> dict:
    return simulator.status()


@app.post("/api/v1/stream/start")
def start_stream() -> dict:
    return simulator.start()


@app.post("/api/v1/stream/pause")
def pause_stream() -> dict:
    return simulator.pause()


@app.post("/api/v1/stream/rate")
def set_stream_rate(request: RateRequest) -> dict:
    return simulator.set_rate(request.events_per_second)


@app.post("/api/v1/history/publish", status_code=202)
def publish_history(request: HistoryRequest) -> dict:
    try:
        simulator.publish_history(request.days, request.events_per_second)
    except RuntimeError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return {
        "accepted": True,
        "days": request.days,
        "events_per_second": request.events_per_second,
        "message": "Check /api/v1/status for completion.",
    }


@app.post("/api/v1/faults/inject")
def inject_fault(request: FaultRequest) -> dict:
    try:
        return simulator.inject_fault(request.kind, request.count)
    except Exception as error:
        raise HTTPException(status_code=503, detail=f"Kafka publish failed: {error}") from error


@app.post("/api/v1/reset")
def reset_simulator() -> dict:
    state = simulator.reset()
    return {
        "message": "Simulator state reset. Existing Kafka records and topics were not changed.",
        "status": state,
    }


@app.get("/api/v1/contracts")
def contracts() -> dict:
    return {
        "topics": TOPICS,
        "event_envelope": [
            "event_id",
            "event_type",
            "event_version",
            "event_ts",
            "produced_at",
            "operation",
            "entity_id",
            "source",
            "payload",
        ],
        "full_documentation": "EVENT_CONTRACT.md in the assessment repository",
    }


@app.on_event("shutdown")
def shutdown() -> None:
    simulator.close()
