import time
import unittest
from unittest.mock import patch

from app.config import Settings
from app.simulator import Simulator


class FakePublisher:
    instances = []

    def __init__(self, bootstrap_servers: str, client_id: str) -> None:
        self.bootstrap_servers = bootstrap_servers
        self.client_id = client_id
        self.messages = []
        self.flushed = False
        self.closed = False
        self.__class__.instances.append(self)

    def publish(self, topic, event) -> None:
        self.messages.append((topic, event))

    def flush(self) -> None:
        self.flushed = True

    def close(self) -> None:
        self.closed = True


class SimulatorTests(unittest.TestCase):
    def test_history_live_and_faults_publish_without_a_real_broker(self) -> None:
        FakePublisher.instances.clear()
        settings = Settings("fake-kafka:9092", "test-client", 100, 1)
        with patch("app.simulator.KafkaPublisher", FakePublisher):
            simulator = Simulator(settings)
            simulator.publish_history(days=1, events_per_second=2_000)
            deadline = time.monotonic() + 3
            while simulator.status()["history_in_progress"] and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertFalse(simulator.status()["history_in_progress"])
            self.assertEqual(simulator.status()["historical_events_published"], 55)

            simulator.start()
            time.sleep(0.06)
            simulator.pause()
            live_count = simulator.status()["published_events_in_simulator_lifetime"]
            self.assertGreater(live_count, 55)

            result = simulator.inject_fault("duplicates", 2)
            self.assertEqual(result["published_events"], 4)
            self.assertTrue(FakePublisher.instances[0].flushed)
            simulator.close()
            self.assertTrue(FakePublisher.instances[0].closed)


if __name__ == "__main__":
    unittest.main()
