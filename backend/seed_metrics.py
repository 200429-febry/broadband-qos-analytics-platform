import random
from datetime import datetime, timedelta

from sqlalchemy import text
from database import engine

TOTAL_RECORDS = 100
NODE_ID = "eNB-001"

now = datetime.now()

with engine.begin() as conn:
    for i in range(TOTAL_RECORDS):
        timestamp = now - timedelta(minutes=TOTAL_RECORDS - i)

        throughput = random.randint(900, 2200)
        latency = random.randint(18, 95)
        jitter = random.randint(4, 32)
        packet_loss = round(random.uniform(0.01, 2.8), 2)
        bandwidth = random.randint(45, 96)

        conn.execute(
            text("""
                INSERT INTO qosmetrics
                (
                    node_id,
                    throughput,
                    latency,
                    jitter,
                    packet_loss,
                    bandwidth_utilization,
                    timestamp
                )
                VALUES
                (
                    :node_id,
                    :throughput,
                    :latency,
                    :jitter,
                    :packet_loss,
                    :bandwidth,
                    :timestamp
                )
            """),
            {
                "node_id": NODE_ID,
                "throughput": throughput,
                "latency": latency,
                "jitter": jitter,
                "packet_loss": packet_loss,
                "bandwidth": bandwidth,
                "timestamp": timestamp,
            }
        )

print(f"{TOTAL_RECORDS} QoS metrics inserted successfully")