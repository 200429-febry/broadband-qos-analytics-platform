"use client";

import { useEffect } from "react";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

async function runGlobalQoSProbe() {
  if (!API_URL || typeof window === "undefined") return;

  const samples: number[] = [];
  let lost = 0;

  for (let i = 0; i < 3; i++) {
    const start = performance.now();

    try {
      const res = await fetch(`${API_URL}/api/health?probe=${Date.now()}-${i}`, {
        cache: "no-store",
      });

      await res.text();
      samples.push(performance.now() - start);
    } catch {
      lost++;
    }

    await new Promise((resolve) => setTimeout(resolve, 120));
  }

  if (samples.length === 0) return;

  const latency =
    samples.reduce((sum, value) => sum + value, 0) / samples.length;

  const jitter =
    samples.length > 1
      ? samples
          .slice(1)
          .reduce(
            (sum, value, index) => sum + Math.abs(value - samples[index]),
            0
          ) /
        (samples.length - 1)
      : 0;

  const packetLoss = (lost / (samples.length + lost)) * 100;

  const downloadStart = performance.now();

  const downloadResponse = await fetch(
    `${API_URL}/api/coverage?streamProbe=${Date.now()}`,
    { cache: "no-store" }
  );

  const downloadText = await downloadResponse.text();
  const downloadSeconds = Math.max(
    (performance.now() - downloadStart) / 1000,
    0.001
  );

  const bytes = new TextEncoder().encode(downloadText).length;
  const measuredThroughput = (bytes * 8) / downloadSeconds / 1_000_000;

  const connection = (navigator as any).connection;
  const browserDownlink =
    typeof connection?.downlink === "number" ? connection.downlink : null;

  const throughput = browserDownlink
    ? Math.min(measuredThroughput, browserDownlink * 1.2)
    : measuredThroughput;

  const payload = {
    node_id: `stream-browser-${navigator.platform.replace(/\s+/g, "-")}`,
    throughput: Number(throughput.toFixed(2)),
    latency: Number(latency.toFixed(2)),
    jitter: Number(jitter.toFixed(2)),
    packet_loss: Number(packetLoss.toFixed(2)),
    bandwidth: Number(Math.min(100, throughput * 10).toFixed(2)),
  };

  await fetch(`${API_URL}/api/qos/ingest`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
    cache: "no-store",
  });
}

export function GlobalQoSProbe() {
  useEffect(() => {
    runGlobalQoSProbe();

    const interval = setInterval(runGlobalQoSProbe, 1000);

    return () => clearInterval(interval);
  }, []);

  return null;
}
