import time
import random
from google.cloud import pubsub_v1

project_id = $(gcloud config get-value project)
topic_id = "neptune-activities"

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project_id, topic_id)

actions = ["CREATE", "UPDATE", "DELETE", "EXPORTS"]
names = ["Emily Blair", "John Doe", "Sarah Lee", "Robert Fox", "Linda White", "Michael Green", "Jessica Brown", "David Wilson"]

print(f"Streaming messages to {topic_path} (Ctrl+C to stop)...")

try:
    while True:
        message = (
            f"2020081204080{random.randint(100000,999999)},"
            f"195.174.170.{random.randint(1,255)},"
            f"{random.choice(actions)},"
            f"GB25BZMX{random.randint(1000000000000000,9999999999999999)},"
            f"{random.randint(1,10)},"
            f"{random.choice(names)},"
            f"STAFF"
        )
        publisher.publish(topic_path, message.encode("utf-8"))
        print(f"Published: {message}")
        time.sleep(3)
except KeyboardInterrupt:
    print("Stopped publishing.")
