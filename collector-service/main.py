import json
import os
import random
import time
from datetime import datetime, timezone

from google.cloud import pubsub_v1
from google.cloud import storage

PROJECT_ID = os.environ.get("PROJECT_ID")
TOPIC_ID = os.environ.get("TOPIC_ID", "qos-telemetry-topic")
BUCKET_NAME = os.environ.get("BUCKET_NAME")

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)

storage_client = storage.Client()
bucket = storage_client.bucket(BUCKET_NAME)

nodes = ["node-jakarta-01", "node-jakarta-02", "node-jakarta-03"]

def generate_telemetry():
    node = random.choice(nodes)

    latency = round(random.uniform(25, 140), 2)
    jitter = round(random.uniform(3, 35), 2)
    packet_loss = round(random.uniform(0.1, 4.5), 2)
    throughput = round(max(10, 110 - latency * 0.45 - packet_loss * 4), 2)
    bandwidth_utilization = round(random.uniform(35, 92), 2)

    return {
        "node_id": node,
        "throughput": throughput,
        "latency": latency,
        "jitter": jitter,
        "packet_loss": packet_loss,
        "bandwidth_utilization": bandwidth_utilization,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

def main():
    while True:
        data = generate_telemetry()
        payload = json.dumps(data).encode("utf-8")

        publisher.publish(topic_path, payload)

        object_name = f"raw/{data['node_id']}/{int(time.time())}.json"
        blob = bucket.blob(object_name)
        blob.upload_from_string(
            json.dumps(data, indent=2),
            content_type="application/json"
        )

        print("Published telemetry:", data, flush=True)
        time.sleep(10)

if __name__ == "__main__":
    main()
