"use client";

import React, { useEffect, useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import {
  ArrowUpRight,
  ArrowDownRight,
  Activity,
  Zap,
  Network,
  ShieldAlert,
} from "lucide-react";
import { cn } from "@/lib/utils";

interface KpiData {
  title: string;
  value: string;
  unit: string;
  trend: number;
  icon: React.ElementType;
  status: "good" | "warning" | "critical";
}

interface QoSMetricsResponse {
  throughput?: number;
  latency?: number;
  jitter?: number;
  packet_loss?: number;
  bandwidth?: number;
}

async function runRealClientQoSProbe() {
  const api = "https://qos-api-gh3tn2a6oa-et.a.run.app";
  if (!api || typeof window === "undefined") return null;

  const samples: number[] = [];
  let lost = 0;

  for (let i = 0; i < 8; i++) {
    const start = performance.now();

    try {
      const response = await fetch(`${api}/api/health?probe=${Date.now()}-${i}`, {
        cache: "no-store",
      });

      await response.text();
      samples.push(performance.now() - start);
    } catch {
      lost++;
    }

    await new Promise((resolve) => setTimeout(resolve, 250));
  }

  if (samples.length === 0) return null;

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

  const coverageResponse = await fetch(`${api}/api/coverage?probe=${Date.now()}`, {
    cache: "no-store",
  });

  const coverageText = await coverageResponse.text();
  const downloadSeconds = Math.max(
    (performance.now() - downloadStart) / 1000,
    0.001
  );

  const bytes = new TextEncoder().encode(coverageText).length;
  const throughput = (bytes * 8) / downloadSeconds / 1_000_000;

  const payload = {
    node_id: `browser-${navigator.platform.replace(/\s+/g, "-")}`,
    throughput: Number(throughput.toFixed(2)),
    latency: Number(latency.toFixed(2)),
    jitter: Number(jitter.toFixed(2)),
    packet_loss: Number(packetLoss.toFixed(2)),
    bandwidth: Number(Math.min(100, throughput * 10).toFixed(2)),
  };

  await fetch(`${api}/api/qos/ingest`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
    cache: "no-store",
  });

  return payload;
}

export function KpiCards() {
  const [metrics, setMetrics] = useState<KpiData[]>([]);

  useEffect(() => {
    const fetchMetrics = async () => {
      try {
        await runRealClientQoSProbe();

        const response = await fetch(
          `https://qos-api-gh3tn2a6oa-et.a.run.app/api/qos/metrics?refresh=${Date.now()}`,
          { cache: "no-store" }
        );

        const data: QoSMetricsResponse = await response.json();

        const throughput = Number(data.throughput ?? 0);
        const latency = Number(data.latency ?? 0);
        const packetLoss = Number(data.packet_loss ?? 0);
        const jitter = Number(data.jitter ?? 0);

        setMetrics([
          {
            title: "Avg Throughput",
            value: throughput.toFixed(2),
            unit: "Mbps",
            trend: 0,
            icon: Zap,
            status: throughput >= 50 ? "good" : throughput >= 20 ? "warning" : "critical",
          },
          {
            title: "Network Latency",
            value: latency.toFixed(2),
            unit: "ms",
            trend: 0,
            icon: Activity,
            status: latency <= 80 ? "good" : latency <= 150 ? "warning" : "critical",
          },
          {
            title: "Packet Loss",
            value: packetLoss.toFixed(2),
            unit: "%",
            trend: 0,
            icon: ShieldAlert,
            status: packetLoss <= 1 ? "good" : packetLoss <= 3 ? "warning" : "critical",
          },
          {
            title: "Jitter",
            value: jitter.toFixed(2),
            unit: "ms",
            trend: 0,
            icon: Network,
            status: jitter <= 20 ? "good" : jitter <= 40 ? "warning" : "critical",
          },
        ]);
      } catch (error) {
        console.error("Failed to run real client QoS probe:", error);
      }
    };

    fetchMetrics();

    const interval = setInterval(fetchMetrics, 3000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      {metrics.map((metric) => (
        <Card key={metric.title} className="relative overflow-hidden group">
          <div className="absolute inset-0 bg-gradient-to-br from-emerald-500/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />

          <CardContent className="p-6">
            <div className="flex justify-between items-start">
              <div>
                <p className="text-sm font-medium text-slate-400 mb-1">
                  {metric.title}
                </p>

                <div className="flex items-baseline gap-2">
                  <h4 className="text-3xl font-bold tracking-tight text-white">
                    {metric.value}
                  </h4>

                  <span className="text-sm text-slate-500">
                    {metric.unit}
                  </span>
                </div>
              </div>

              <div
                className={cn(
                  "p-3 rounded-xl backdrop-blur-md border",
                  metric.status === "good"
                    ? "bg-emerald-500/10 border-emerald-500/20 text-emerald-400"
                    : metric.status === "warning"
                    ? "bg-amber-500/10 border-amber-500/20 text-amber-400"
                    : "bg-red-500/10 border-red-500/20 text-red-400"
                )}
              >
                <metric.icon className="h-5 w-5" />
              </div>
            </div>

            <div className="mt-4 flex items-center text-sm">
              <span className="flex items-center font-medium text-emerald-400">
                {metric.trend > 0 ? (
                  <ArrowUpRight className="h-4 w-4 mr-1" />
                ) : (
                  <ArrowDownRight className="h-4 w-4 mr-1" />
                )}

                {Math.abs(metric.trend)}%
              </span>

              <span className="text-slate-500 ml-2">vs last hour</span>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
