import random
import time
from sqlalchemy import text
from database import engine

NODE_ID = "eNB-001"

print("LIVE QoS Generator Running...")

while True:

    throughput = random.randint(900, 2200)
    latency = random.randint(18, 95)
    jitter = random.randint(4, 30)
    packet_loss = round(random.uniform(0.05, 2.5), 2)
    bandwidth = random.randint(45, 95)

    with engine.begin() as conn:

        conn.execute(
            text("""
                INSERT INTO qosmetrics
                (
                    node_id,
                    throughput,
                    latency,
                    jitter,
                    packet_loss,
                    bandwidth_utilization
                )
                VALUES
                (
                    :node_id,
                    :throughput,
                    :latency,
                    :jitter,
                    :packet_loss,
                    :bandwidth
                )
            """),
            {
                "node_id": NODE_ID,
                "throughput": throughput,
                "latency": latency,
                "jitter": jitter,
                "packet_loss": packet_loss,
                "bandwidth": bandwidth,
            }
        )

    print(
        f"Inserted: TP={throughput} "
        f"LAT={latency} "
        f"PL={packet_loss}"
    )

    time.sleep(5)