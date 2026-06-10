"use client";

import { TechnicalChartGrid } from "@/components/technical-chart-grid";

import { useEffect, useMemo, useState } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

type Metric = {
  throughput: number;
  latency: number;
  jitter: number;
  packet_loss: number;
  qoe_score?: number;
  source?: string;
  streaming_status?: string;
  timestamp?: string;
};

type AlertItem = {
  id: number | string;
  type: string;
  message: string;
  metric: string;
  time: string;
  source?: string;
};

function Card({ label, value, unit }: { label: string; value: string | number; unit?: string }) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <p className="text-sm text-slate-400">{label}</p>
      <div className="mt-3 flex items-end gap-2">
        <span className="text-3xl font-black text-white">{value}</span>
        {unit ? <span className="mb-1 text-sm text-slate-400">{unit}</span> : null}
      </div>
    </div>
  );
}

export default function AnalyticsPage() {
  const [metric, setMetric] = useState<Metric | null>(null);
  const [history, setHistory] = useState<Metric[]>([]);
  const [alerts, setAlerts] = useState<AlertItem[]>([]);

  const fetchData = async () => {
    const [metricRes, historyRes, alertsRes] = await Promise.all([
      fetch(`/api/qos-metrics?x=${Date.now()}`, { cache: "no-store" }),
      fetch(`/api/qos-history?x=${Date.now()}`, { cache: "no-store" }),
      fetch(`/api/qos-alerts?x=${Date.now()}`, { cache: "no-store" }),
    ]);

    const metricJson = await metricRes.json();
    const historyJson = await historyRes.json();
    const alertsJson = await alertsRes.json();

    setMetric(metricJson);
    setHistory(Array.isArray(historyJson) ? historyJson : []);
    setAlerts(Array.isArray(alertsJson) ? alertsJson : []);
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 3000);
    return () => clearInterval(interval);
  }, []);

  const healthIndex = useMemo(() => Math.round(Number(metric?.qoe_score ?? 0)), [metric]);

  const classification = useMemo(() => {
    const qoe = Number(metric?.qoe_score ?? 0);
    if (qoe >= 90) return "EXCELLENT";
    if (qoe >= 75) return "STABLE";
    if (qoe >= 60) return "BUFFER RISK";
    return "CRITICAL";
  }, [metric]);

  const chartData = history
    .slice()
    .reverse()
    .map((item) => ({
      time: item.timestamp || "-",
      throughput: Number(item.throughput ?? 0),
      latency: Number(item.latency ?? 0),
      jitter: Number(item.jitter ?? 0),
      qoe: Number(item.qoe_score ?? 0),
    }));

  return (
    <main className="space-y-8 p-6 text-white">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-3xl font-black">QoS Intelligence Analytics</h1>
          <p className="mt-2 max-w-4xl text-slate-400">
            Technical network analytics powered by real Streaming QoE telemetry, active browser-side traffic probe, alert classification, and cloud observability.
          </p>
        </div>
        <button onClick={fetchData} className="rounded-xl border border-emerald-500/30 px-5 py-3 text-sm font-bold text-emerald-300 hover:bg-emerald-500/10">
          Refresh Analytics
        </button>
      </div>

      <section className="grid gap-4 md:grid-cols-4">
        <Card label="Network Health Index" value={healthIndex} />
        <Card label="Avg Throughput" value={metric?.throughput ?? 0} unit="Mbps" />
        <Card label="Avg Latency" value={metric?.latency ?? 0} unit="ms" />
        <Card label="Packet Loss" value={metric?.packet_loss ?? 0} unit="%" />
      </section>

      <section className={`rounded-3xl border p-6 ${
        classification === "CRITICAL"
          ? "border-red-500/40 bg-red-500/10"
          : classification === "BUFFER RISK"
          ? "border-yellow-500/40 bg-yellow-500/10"
          : "border-emerald-500/40 bg-emerald-500/10"
      }`}>
        <h2 className="text-3xl font-black">{classification}</h2>
        <p className="mt-3 text-slate-300">
          Current risk classification is calculated from real QoE score, latency, jitter, throughput, and active alert conditions.
        </p>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6">
        <h2 className="mb-4 text-xl font-black">Throughput vs Latency Trend</h2>
        {chartData.length === 0 ? (
          <div className="flex h-[320px] items-center justify-center text-slate-500">Waiting for real QoE history...</div>
        ) : (
          <div className="h-[320px]">
            <ResponsiveContainer width="100%" height={360}>
              <AreaChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                <XAxis dataKey="time" stroke="#64748b" fontSize={11} />
                <YAxis stroke="#64748b" fontSize={11} />
                <Tooltip contentStyle={{ background: "#020617", border: "1px solid #1e293b", borderRadius: "12px", color: "#e2e8f0" }} />
                <Area type="monotone" dataKey="throughput" name="Throughput Mbps" stroke="#22d3ee" fill="#22d3ee" fillOpacity={0.18} />
                <Area type="monotone" dataKey="latency" name="Latency ms" stroke="#facc15" fill="#facc15" fillOpacity={0.12} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6">
        <h2 className="text-xl font-black">Active Real QoE Alerts</h2>
        <p className="mt-2 text-sm text-slate-400">Alerts are generated from real browser-to-Cloud Run traffic probe conditions.</p>
        <div className="mt-4 space-y-3">
          {alerts.length === 0 ? (
            <div className="rounded-xl border border-emerald-500/20 bg-emerald-500/10 p-4 text-sm text-emerald-300">
              No active QoE alerts. Current streaming condition is stable.
            </div>
          ) : (
            alerts.slice(0, 8).map((alert) => (
              <div key={alert.id} className="rounded-xl border border-red-500/20 bg-red-500/10 p-4">
                <p className="font-bold text-red-300">{alert.message}</p>
                <p className="mt-1 text-sm text-slate-400">{alert.metric} • {alert.time} • {alert.source || "Real QoE"}</p>
              </div>
            ))
          )}
        </div>
      </section>
          <TechnicalChartGrid scope="analytics" />
    </main>
  );
}
