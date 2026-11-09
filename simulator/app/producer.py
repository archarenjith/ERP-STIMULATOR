"""A deliberately small Kafka JSON publisher.

The simulator does not create topics: topic creation/configuration is part of the
assessment candidate's platform setup.
"""

from __future__ import annotations

import json
from typing import Any

from kafka import KafkaProducer


class KafkaPublisher:
    def __init__(self, bootstrap_servers: str, client_id: str) -> None:
        self._producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            client_id=client_id,
            acks="all",
            retries=3,
            linger_ms=10,
            value_serializer=lambda value: json.dumps(
                value, separators=(",", ":"), default=str
            ).encode("utf-8"),
            key_serializer=lambda key: key.encode("utf-8"),
        )

    def publish(self, topic: str, event: dict[str, Any]) -> None:
        # Delivery is asynchronous so history publishing can be accelerated.
        self._producer.send(topic, key=event.get("entity_id", "unknown"), value=event)

    def flush(self) -> None:
        self._producer.flush(timeout=30)

    def close(self) -> None:
        self._producer.close(timeout=10)
