import unittest
from datetime import datetime, timezone

from app.config import TOPICS
from app.generator import EventFactory


class EventFactoryTests(unittest.TestCase):
    def test_history_has_valid_common_envelope_and_all_topics(self) -> None:
        factory = EventFactory(seed=7)
        events = factory.historical_events(days=3)
        self.assertGreater(len(events), 50)
        self.assertTrue(set(TOPICS.values()).issubset({topic for topic, _ in events}))

        event_ids = set()
        for topic, event in events:
            self.assertIn(topic, TOPICS.values())
            self.assertEqual(
                set(event),
                {
                    "event_id",
                    "event_type",
                    "event_version",
                    "event_ts",
                    "produced_at",
                    "operation",
                    "entity_id",
                    "source",
                    "payload",
                },
            )
            self.assertIn(event["operation"], {"c", "u", "d"})
            self.assertNotIn(event["event_id"], event_ids)
            event_ids.add(event["event_id"])

    def test_faults_express_their_documented_edge_cases(self) -> None:
        factory = EventFactory(seed=8)
        factory.historical_events(days=1)
        now = datetime.now(timezone.utc)

        duplicates = factory.fault_events("duplicates", 2)
        self.assertEqual(len(duplicates), 4)
        self.assertEqual(duplicates[0][1], duplicates[1][1])

        late = factory.fault_events("late_events", 1)[0][1]
        self.assertLess(late["event_ts"], now.isoformat())

        invalid = factory.fault_events("invalid", 1)[0][1]
        self.assertNotIn("event_ts", invalid)
        self.assertEqual(invalid["event_version"], "one")

        schema_v2 = factory.fault_events("schema_v2", 1)[0][1]
        self.assertEqual(schema_v2["event_version"], 2)
        self.assertIn("schema_v2_note", schema_v2["payload"])

    def test_inventory_contains_raw_and_finished_stock_movements(self) -> None:
        factory = EventFactory(seed=9)
        inventory = []
        for _ in range(100):
            topic, event = factory.next_event()
            if topic == TOPICS["inventory"] and event["operation"] == "c":
                inventory.append(event["payload"])
        categories = {record["stock_category"] for record in inventory}
        self.assertIn("raw_material", categories)
        self.assertIn("finished_goods", categories)


if __name__ == "__main__":
    unittest.main()
