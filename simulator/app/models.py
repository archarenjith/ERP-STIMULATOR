"""HTTP request models. Event payloads intentionally remain plain JSON dicts."""

from typing import Literal

from pydantic import BaseModel, Field


class RateRequest(BaseModel):
    events_per_second: float = Field(ge=0.1, le=50)


class HistoryRequest(BaseModel):
    events_per_second: int = Field(default=500, ge=10, le=2_000)
    days: int = Field(default=90, ge=1, le=365)


class FaultRequest(BaseModel):
    kind: Literal["late_events", "duplicates", "updates", "deletes", "invalid", "schema_v2"]
    count: int = Field(default=5, ge=1, le=100)
