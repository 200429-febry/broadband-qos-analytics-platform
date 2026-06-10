"use client";

import { useEffect, useMemo, useState } from "react";

type Metric = {
  throughput: number;
  latency: number;
  jitter: number;
  packet_loss: number;
  qoe_score?: number;
  source?: string;
  streaming_status?: string;
};

type AlertItem = { id: number | string; type: string; message: string; metric: string; time: string; source?: string };

function Card({ label, value, helper }: { label: string; value: string | number; helper?: string }) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <p className="text-sm text-slate-400">{label}</p>
      <p className="mt-3 text-3xl font-black text-white">{value}</p>
      {helper ? <p className="mt-2 text-xs text-slate-500">{helper}</p> : null}
    </div>
  );
}

export default function ObservabilityPage() {
  const [metric, setMetric] = useState<Metric | null>(null);
  const [alerts, setAlerts] = useState<AlertItem[]>([]);
  const [health, setHealth] = useState<any>(null);
  const [history, setHistory] = useState<Metric[]>([]);

  const fetchData = async () => {
    const [metricRes, alertsRes, healthRes, historyRes] = await Promise.all([
      fetch(`/api/qos-metrics?x=${Date.now()}`, { cache: "no-store" }),
      fetch(`/api/qos-alerts?x=${Date.now()}`, { cache: "no-store" }),
      fetch(`/api/health-live?x=${Date.now()}`, { cache: "no-store" }),
      fetch(`/api/qos-history?x=${Date.now()}`, { cache: "no-store" }),
    ]);

    setMetric(await metricRes.json());
    const alertJson = await alertsRes.json();
    setAlerts(Array.isArray(alertJson) ? alertJson : []);
    setHealth(await healthRes.json());
    const historyJson = await historyRes.json();
    setHistory(Array.isArray(historyJson) ? historyJson : []);
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  const state = useMemo(() => {
    if (alerts.some((a) => a.type === "critical")) return "CRITICAL";
    if (alerts.length) return "WARNING";
    return "STABLE";
  }, [alerts]);

  return (
    <main className="space-y-8 p-6 text-white">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-3xl font-black">NOC Observability Center</h1>
          <p className="mt-2 text-slate-400">Internal metrics explorer for API health, real QoE telemetry, alert rate, incident risk, and ML-ready observability.</p>
        </div>
        <button onClick={fetchData} className="rounded-xl border border-emerald-500/30 px-5 py-3 text-sm font-bold text-emerald-300">Refresh Metrics</button>
      </div>

      <section className={`rounded-3xl border p-6 ${state === "STABLE" ? "border-emerald-500/30 bg-emerald-500/10" : "border-red-500/30 bg-red-500/10"}`}>
        <p className="text-xs uppercase tracking-[0.3em] text-slate-400">Current Network State</p>
        <h2 className="mt-3 text-4xl font-black">{state}</h2>
        <p className="mt-3 text-sm text-slate-300">Last observability refresh uses real-qoe-probe and API health.</p>
      </section>

      <section className="grid gap-4 md:grid-cols-4">
        <Card label="Throughput" value={`${metric?.throughput ?? 0} Mbps`} helper="Real client probe" />
        <Card label="Latency" value={`${metric?.latency ?? 0} ms`} helper="Browser to Cloud Run RTT" />
        <Card label="Jitter" value={`${metric?.jitter ?? 0} ms`} helper="Latency variation" />
        <Card label="Packet Loss" value={`${metric?.packet_loss ?? 0} %`} helper="QoE approximation" />
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Live Telemetry Trace</h2>
          <p className="mt-2 text-sm text-slate-400">Latest measurement window generated from browser QoE probe and backend metrics.</p>
          <div className="mt-5 space-y-2">
            {history.slice(0, 8).map((h, i) => (
              <div key={i} className="rounded-xl border border-slate-800 bg-slate-950 p-3 text-sm">
                {h.throughput} Mbps • {h.latency} ms • {h.jitter} ms • QoE {h.qoe_score ?? "-"}
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Prometheus-style Metrics Explorer</h2>
          <div className="mt-5 grid gap-3 md:grid-cols-2">
            <Card label="Metric Source" value={metric?.source || "waiting"} />
            <Card label="API State" value={health?.status || "unknown"} />
            <Card label="Active Alerts" value={alerts.length} />
            <Card label="Telemetry Samples" value={history.length} />
          </div>
        </div>
      </section>
    </main>
  );
}
