"""Concurrency and lifecycle management for live, history, and fault streams."""

from __future__ import annotations

import threading
import time
from datetime import datetime, timezone
from typing import Any

from .config import Settings
from .generator import EventFactory, isoformat_z
from .producer import KafkaPublisher


class Simulator:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._factory = EventFactory(settings.random_seed)
        self._publisher: KafkaPublisher | None = None
        self._factory_lock = threading.Lock()
        self._state_lock = threading.RLock()
        self._live_enabled = threading.Event()
        self._shutdown = threading.Event()
        self._live_thread: threading.Thread | None = None
        self._history_in_progress = False
        self._event_rate = settings.default_event_rate
        self._published_count = 0
        self._fault_count = 0
        self._history_count = 0
        self._last_error: str | None = None
        self._last_event_at: str | None = None
        self._last_reset_at = isoformat_z(datetime.now(timezone.utc))

    def _get_publisher(self) -> KafkaPublisher:
        with self._state_lock:
            if self._publisher is None:
                self._publisher = KafkaPublisher(
                    self.settings.kafka_bootstrap_servers, self.settings.kafka_client_id
                )
            return self._publisher

    def _record_error(self, error: Exception) -> None:
        with self._state_lock:
            self._last_error = f"{type(error).__name__}: {error}"

    def _publish(self, item: tuple[str, dict[str, Any]], category: str) -> None:
        topic, event = item
        publisher = self._get_publisher()
        publisher.publish(topic, event)
        with self._state_lock:
            self._published_count += 1
            if category == "history":
                self._history_count += 1
            elif category == "fault":
                self._fault_count += 1
            self._last_event_at = isoformat_z(datetime.now(timezone.utc))
            self._last_error = None

    def _live_loop(self) -> None:
        while not self._shutdown.is_set():
            if not self._live_enabled.wait(timeout=0.25):
                continue
            try:
                with self._factory_lock:
                    item = self._factory.next_event()
                self._publish(item, "live")
            except Exception as error:  # keep API responsive while Kafka is unavailable
                self._record_error(error)
                time.sleep(1)
                continue
            with self._state_lock:
                delay = 1 / self._event_rate
            time.sleep(delay)

    def start(self) -> dict[str, Any]:
        with self._state_lock:
            if self._live_thread is None or not self._live_thread.is_alive():
                self._live_thread = threading.Thread(
                    target=self._live_loop, name="erp-live-event-stream", daemon=True
                )
                self._live_thread.start()
            self._live_enabled.set()
        return self.status()

    def pause(self) -> dict[str, Any]:
        self._live_enabled.clear()
        return self.status()

    def set_rate(self, events_per_second: float) -> dict[str, Any]:
        with self._state_lock:
            self._event_rate = events_per_second
        return self.status()

    def publish_history(self, days: int, events_per_second: int) -> None:
        with self._state_lock:
            if self._history_in_progress:
                raise RuntimeError("Historical publishing is already in progress")
            self._history_in_progress = True
        thread = threading.Thread(
            target=self._history_worker,
            args=(days, events_per_second),
            name="erp-history-publisher",
            daemon=True,
        )
        thread.start()

    def _history_worker(self, days: int, events_per_second: int) -> None:
        try:
            with self._factory_lock:
                items = self._factory.historical_events(days)
            delay = 1 / events_per_second
            for item in items:
                if self._shutdown.is_set():
                    break
                self._publish(item, "history")
                time.sleep(delay)
            if self._publisher is not None:
                self._publisher.flush()
        except Exception as error:
            self._record_error(error)
        finally:
            with self._state_lock:
                self._history_in_progress = False

    def inject_fault(self, kind: str, count: int) -> dict[str, Any]:
        with self._factory_lock:
            items = self._factory.fault_events(kind, count)
        try:
            for item in items:
                self._publish(item, "fault")
            if self._publisher is not None:
                self._publisher.flush()
        except Exception as error:
            self._record_error(error)
            raise
        return {
            "kind": kind,
            "requested_count": count,
            "published_events": len(items),
            "note": "duplicates publish two events for every requested duplicate pair",
        }

    def reset(self) -> dict[str, Any]:
        """Reset only generator state; Kafka records are intentionally not deleted."""
        self.pause()
        with self._factory_lock, self._state_lock:
            self._factory = EventFactory(self.settings.random_seed)
            self._event_rate = self.settings.default_event_rate
            self._last_error = None
            self._last_reset_at = isoformat_z(datetime.now(timezone.utc))
        return self.status()

    def status(self) -> dict[str, Any]:
        with self._state_lock:
            return {
                "live_streaming": self._live_enabled.is_set(),
                "history_in_progress": self._history_in_progress,
                "event_rate_per_second": self._event_rate,
                "kafka_bootstrap_servers": self.settings.kafka_bootstrap_servers,
                "publisher_initialized": self._publisher is not None,
                "published_events_in_simulator_lifetime": self._published_count,
                "historical_events_published": self._history_count,
                "fault_events_published": self._fault_count,
                "last_event_at": self._last_event_at,
                "last_error": self._last_error,
                "last_reset_at": self._last_reset_at,
            }

    def close(self) -> None:
        self._live_enabled.clear()
        self._shutdown.set()
        if self._publisher is not None:
            self._publisher.close()
