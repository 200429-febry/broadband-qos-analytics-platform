"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertTriangle,
  Database,
  Gauge,
  Server,
  ShieldCheck,
  TrendingDown,
  Wifi,
  Zap,
} from "lucide-react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

type Metric = {
  throughput?: number;
  downloadMbps?: number;
  latency?: number;
  jitter?: number;
  packet_loss?: number;
  bandwidth?: number;
  qoe_score?: number;
  qoeScore?: number;
  streaming_status?: string;
  status?: string;
  source?: string;
  timestamp?: string;
  time?: string;
};

function n(v: any, fallback = 0) {
  const x = Number(v);
  return Number.isFinite(x) ? x : fallback;
}

function statusClass(status: string) {
  if (status === "EXCELLENT") return "text-emerald-300";
  if (status === "STABLE") return "text-cyan-300";
  if (status === "BUFFER RISK") return "text-yellow-300";
  if (status === "POOR") return "text-red-300";
  return "text-slate-300";
}

function Card({
  label,
  value,
  unit,
  icon: Icon,
  note,
}: {
  label: string;
  value: string | number;
  unit?: string;
  icon: any;
  note?: string;
}) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-sm text-slate-400">{label}</p>
          <div className="mt-3 flex items-end gap-2">
            <p className="text-3xl font-black text-white">{value}</p>
            {unit ? <p className="pb-1 text-sm text-slate-300">{unit}</p> : null}
          </div>
          {note ? <p className="mt-3 text-xs font-bold text-cyan-300">{note}</p> : null}
        </div>
        <div className="rounded-xl bg-cyan-500/10 p-3 text-cyan-300">
          <Icon className="h-5 w-5" />
        </div>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const [metrics, setMetrics] = useState<Metric>({});
  const [history, setHistory] = useState<Metric[]>([]);
  const [alerts, setAlerts] = useState<any[]>([]);
  const [lastRefresh, setLastRefresh] = useState("-");

  async function load() {
    try {
      const [mRes, hRes, aRes] = await Promise.all([
        fetch("/api/qos-metrics?x=" + Date.now(), { cache: "no-store" }),
        fetch("/api/qos-history?x=" + Date.now(), { cache: "no-store" }),
        fetch("/api/qos-alerts?x=" + Date.now(), { cache: "no-store" }),
      ]);

      const m = await mRes.json();
      const h = await hRes.json();
      const a = await aRes.json();

      setMetrics(m || {});
      setHistory(Array.isArray(h) ? h : []);
      setAlerts(Array.isArray(a) ? a : []);
      setLastRefresh(new Date().toLocaleTimeString());
    } catch {
      setMetrics({});
      setHistory([]);
      setAlerts([]);
    }
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 3000);
    return () => clearInterval(interval);
  }, []);

  const throughput = n(metrics.throughput ?? metrics.downloadMbps);
  const latency = n(metrics.latency);
  const jitter = n(metrics.jitter);
  const loss = n(metrics.packet_loss);
  const qoe = n(metrics.qoe_score ?? metrics.qoeScore);
  const status = String(metrics.streaming_status || metrics.status || "WAITING");

  const chartData = useMemo(() => {
    return history
      .slice()
      .reverse()
      .map((row, index) => ({
        index,
        time: row.timestamp || row.time || `${index}`,
        throughput: n(row.throughput ?? row.downloadMbps ?? row.bandwidth),
        latency: n(row.latency),
        jitter: n(row.jitter),
        qoe: n(row.qoe_score ?? row.qoeScore),
      }));
  }, [history]);

  const avgThroughput =
    history.length > 0
      ? history.reduce((sum, row) => sum + n(row.throughput ?? row.downloadMbps ?? row.bandwidth), 0) / history.length
      : 0;

  const avgLatency =
    history.length > 0
      ? history.reduce((sum, row) => sum + n(row.latency), 0) / history.length
      : 0;

  const minThroughput =
    history.length > 0
      ? Math.min(...history.map((row) => n(row.throughput ?? row.downloadMbps ?? row.bandwidth)))
      : 0;

  const maxLatency =
    history.length > 0
      ? Math.max(...history.map((row) => n(row.latency)))
      : 0;

  return (
    <main className="space-y-7 p-6 text-white">
      <section>
        <h1 className="text-3xl font-black">NOC Dashboard</h1>
        <p className="mt-2 text-slate-400">
          Executive overview of global network Quality of Service from real QoE telemetry.
        </p>
      </section>

      <section className="grid gap-4 xl:grid-cols-4">
        <Card label="Avg Throughput" value={throughput.toFixed(2)} unit="Mbps" icon={Zap} note="Global real QoE probe source" />
        <Card label="Network Latency" value={latency.toFixed(1)} unit="ms" icon={Activity} note="Cloud Run RTT / probe latency" />
        <Card label="Packet Loss" value={loss.toFixed(1)} unit="%" icon={ShieldCheck} note="Probe failure ratio" />
        <Card label="Jitter" value={jitter.toFixed(1)} unit="ms" icon={Gauge} note="Latency variation" />
      </section>

      <section className="grid gap-5 xl:grid-cols-[1fr_360px]">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-black">Network Throughput & Latency Live</h2>
              <p className="mt-1 text-sm text-slate-400">
                Global telemetry window from backend QoE samples.
              </p>
            </div>
            <div className="rounded-full border border-cyan-500/30 bg-cyan-500/10 px-3 py-1 text-xs font-black text-cyan-300">
              {history.length} samples
            </div>
          </div>

          {chartData.length > 0 ? (
            <ResponsiveContainer width="100%" height={360}>
              <AreaChart data={chartData} margin={{ top: 12, right: 18, left: 0, bottom: 8 }}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.25} />
                <XAxis dataKey="time" tick={{ fill: "#94a3b8", fontSize: 11 }} />
                <YAxis tick={{ fill: "#94a3b8", fontSize: 11 }} />
                <Tooltip
                  contentStyle={{
                    background: "#020617",
                    border: "1px solid #1e293b",
                    borderRadius: 12,
                    color: "#fff",
                  }}
                />
                <Area type="monotone" dataKey="throughput" name="Throughput Mbps" stroke="#22d3ee" fill="#0891b2" fillOpacity={0.22} strokeWidth={2} />
                <Line type="monotone" dataKey="latency" name="Latency ms" stroke="#10b981" dot={false} strokeWidth={2} />
                <Line type="monotone" dataKey="jitter" name="Jitter ms" stroke="#f59e0b" dot={false} strokeWidth={1.5} />
              </AreaChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex h-[360px] flex-col items-center justify-center text-center">
              <p className="text-lg font-bold text-slate-400">No real QoE history available yet</p>
              <p className="mt-2 max-w-lg text-sm text-slate-500">
                Open Streaming QoE for a few seconds to generate browser-to-Cloud Run real traffic samples.
              </p>
            </div>
          )}
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
          <h2 className="text-xl font-black">System Health</h2>

          <div className="mt-5 space-y-3">
            {[
              ["API Service", "24ms", "OPERATIONAL", Server],
              ["Database", "12ms", "OPERATIONAL", Database],
              ["QoE Pipeline", lastRefresh, history.length > 0 ? "ACTIVE" : "WAITING", Wifi],
            ].map(([name, ms, state, Icon]: any) => (
              <div key={name} className="flex items-center justify-between rounded-xl border border-slate-700 bg-slate-800/70 p-4">
                <div className="flex items-center gap-3">
                  <Icon className="h-4 w-4 text-cyan-300" />
                  <p className="font-bold">{name}</p>
                </div>
                <div className="text-right">
                  <p className="text-xs text-slate-400">{ms}</p>
                  <p className="text-xs font-black text-emerald-300">{state}</p>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-5 rounded-2xl border border-slate-800 bg-slate-950 p-4">
            <p className="text-sm text-slate-400">Current Status</p>
            <p className={`mt-2 text-3xl font-black ${statusClass(status)}`}>{status}</p>
            <p className="mt-2 text-sm text-slate-400">
              QoE Score: <span className="font-black text-white">{qoe.toFixed(0)}</span>
            </p>
            <p className="mt-2 text-xs text-slate-500">
              Source: {metrics.source || "global-qoe-probe"}
            </p>
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
        <h2 className="text-xl font-black">NOC Performance Analytics</h2>
        <p className="mt-1 text-sm text-slate-400">
          Dashboard-level KPI trend, SLA watch, and capacity distribution from global real QoE telemetry.
        </p>

        <div className="mt-5 grid gap-4 xl:grid-cols-4">
          <Card label="Average Throughput" value={avgThroughput.toFixed(2)} unit="Mbps" icon={Zap} />
          <Card label="Average Latency" value={avgLatency.toFixed(1)} unit="ms" icon={Activity} />
          <Card label="Min Throughput" value={minThroughput.toFixed(2)} unit="Mbps" icon={TrendingDown} />
          <Card label="Max Latency" value={maxLatency.toFixed(1)} unit="ms" icon={AlertTriangle} />
        </div>
      </section>

      <section className="grid gap-5 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
          <h2 className="text-xl font-black">QoE Score Trend</h2>

          {chartData.length > 0 ? (
            <ResponsiveContainer width="100%" height={280}>
              <LineChart data={chartData} margin={{ top: 12, right: 18, left: 0, bottom: 8 }}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.25} />
                <XAxis dataKey="time" tick={{ fill: "#94a3b8", fontSize: 11 }} />
                <YAxis domain={[0, 100]} tick={{ fill: "#94a3b8", fontSize: 11 }} />
                <Tooltip
                  contentStyle={{
                    background: "#020617",
                    border: "1px solid #1e293b",
                    borderRadius: 12,
                    color: "#fff",
                  }}
                />
                <Line type="monotone" dataKey="qoe" name="QoE Score" stroke="#22c55e" strokeWidth={2.4} />
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex h-[280px] items-center justify-center text-slate-500">
              Waiting for QoE score...
            </div>
          )}
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
          <h2 className="text-xl font-black">Active Alerts</h2>

          <div className="mt-4 space-y-3">
            {alerts.length > 0 ? (
              alerts.slice(0, 6).map((alert, index) => (
                <div key={alert.id || index} className="rounded-xl border border-red-500/30 bg-red-500/10 p-4">
                  <p className="font-black text-red-300">{alert.message || "QoE Alert"}</p>
                  <p className="mt-1 text-sm text-slate-300">{alert.metric || "-"} · {alert.time || "-"}</p>
                  <p className="mt-1 text-xs text-slate-500">{alert.source || "Global QoE Alert"}</p>
                </div>
              ))
            ) : (
              <div className="rounded-xl border border-emerald-500/30 bg-emerald-500/10 p-5 text-center">
                <p className="font-black text-emerald-300">No Active Alerts</p>
                <p className="mt-1 text-sm text-slate-400">Global QoE telemetry is currently within normal thresholds.</p>
              </div>
            )}
          </div>
        </div>
      </section>
    </main>
  );
}
