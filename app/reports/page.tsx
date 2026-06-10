"use client";

import { useEffect, useState } from "react";
import {
  AlertTriangle,
  BarChart3,
  Download,
  FileSpreadsheet,
  FileText,
  RefreshCw,
  ShieldCheck,
  TrendingUp,
} from "lucide-react";

function n(v: any) {
  const x = Number(v);
  return Number.isFinite(x) ? x : 0;
}

function Kpi({ label, value, desc, tone = "cyan" }: any) {
  const color =
    tone === "green" ? "text-emerald-300" :
    tone === "yellow" ? "text-yellow-300" :
    tone === "red" ? "text-red-300" :
    tone === "purple" ? "text-purple-300" :
    "text-cyan-300";

  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <p className="text-sm text-slate-400">{label}</p>
      <p className={`mt-3 text-3xl font-black ${color}`}>{value}</p>
      <p className="mt-2 text-xs text-slate-500">{desc}</p>
    </div>
  );
}

export default function ReportsPage() {
  const [metrics, setMetrics] = useState<any>({});
  const [history, setHistory] = useState<any[]>([]);
  const [alerts, setAlerts] = useState<any[]>([]);
  const [lastRefresh, setLastRefresh] = useState("-");

  async function load() {
    const [m, h, a] = await Promise.all([
      fetch("/api/qos-metrics?x=" + Date.now(), { cache: "no-store" }).then(r => r.json()).catch(() => ({})),
      fetch("/api/qos-history?x=" + Date.now(), { cache: "no-store" }).then(r => r.json()).catch(() => []),
      fetch("/api/qos-alerts?x=" + Date.now(), { cache: "no-store" }).then(r => r.json()).catch(() => []),
    ]);
    setMetrics(m || {});
    setHistory(Array.isArray(h) ? h : []);
    setAlerts(Array.isArray(a) ? a : []);
    setLastRefresh(new Date().toLocaleTimeString());
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 5000);
    return () => clearInterval(interval);
  }, []);

  const avgThroughput = history.length ? history.reduce((s, r) => s + n(r.throughput || r.downloadMbps || r.bandwidth), 0) / history.length : 0;
  const avgLatency = history.length ? history.reduce((s, r) => s + n(r.latency), 0) / history.length : 0;
  const avgJitter = history.length ? history.reduce((s, r) => s + n(r.jitter), 0) / history.length : 0;
  const maxLatency = history.length ? Math.max(...history.map(r => n(r.latency))) : 0;
  const minThroughput = history.length ? Math.min(...history.map(r => n(r.throughput || r.downloadMbps || r.bandwidth))) : 0;
  const availability = alerts.length === 0 ? "100.00%" : `${Math.max(90, 100 - alerts.length * 2).toFixed(2)}%`;

  function openPdf() {
    window.open("/api/reports/pdf?x=" + Date.now(), "_blank");
  }

  function openCsv() {
    window.open("/api/reports/csv?x=" + Date.now(), "_blank");
  }

  return (
    <main className="space-y-7 p-6 text-white">
      <section className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">SLA / KPI Report Generator</h1>
          <p className="mt-2 max-w-5xl text-slate-400">
            Server-side report generated from live QoE telemetry, active alerts, architecture metadata,
            measurement window statistics, and engineering interpretation. The export is not a dashboard screenshot.
          </p>
        </div>

        <div className="flex flex-wrap gap-3">
          <button
            onClick={load}
            className="rounded-xl border border-slate-700 bg-slate-900 px-4 py-2 text-sm font-black text-slate-200 hover:border-cyan-500/40"
          >
            <RefreshCw className="mr-2 inline h-4 w-4" />
            Refresh
          </button>
          <button
            onClick={openPdf}
            className="rounded-xl border border-cyan-500/40 bg-cyan-500/10 px-4 py-2 text-sm font-black text-cyan-300 hover:bg-cyan-500/20"
          >
            <FileText className="mr-2 inline h-4 w-4" />
            Generate PDF
          </button>
          <button
            onClick={openCsv}
            className="rounded-xl border border-emerald-500/40 bg-emerald-500/10 px-4 py-2 text-sm font-black text-emerald-300 hover:bg-emerald-500/20"
          >
            <FileSpreadsheet className="mr-2 inline h-4 w-4" />
            Export CSV
          </button>
        </div>
      </section>

      <section className="rounded-3xl border border-emerald-500/30 bg-emerald-500/10 p-6">
        <div className="flex items-start gap-4">
          <ShieldCheck className="mt-1 h-8 w-8 text-emerald-300" />
          <div>
            <h2 className="text-2xl font-black text-emerald-300">
              {alerts.length === 0 ? "SLA PASSED" : "SLA WATCH"}
            </h2>
            <p className="mt-1 text-sm text-slate-300">
              Current QoE status is <b>{metrics.streaming_status || "WAITING"}</b> with QoE score <b>{n(metrics.qoe_score).toFixed(0)}</b>.
              The report uses the latest {history.length} telemetry samples.
            </p>
          </div>
        </div>
      </section>

      <section className="grid gap-4 xl:grid-cols-4">
        <Kpi label="Availability" value={availability} desc="Derived from active alert window" tone="green" />
        <Kpi label="Avg Throughput" value={`${avgThroughput.toFixed(2)} Mbps`} desc="Measurement window average" />
        <Kpi label="Avg Latency" value={`${avgLatency.toFixed(1)} ms`} desc="Cloud Run RTT / QoE latency" tone="yellow" />
        <Kpi label="Active Alerts" value={alerts.length} desc="Backend threshold and QoE alerts" tone={alerts.length ? "red" : "green"} />
        <Kpi label="Avg Jitter" value={`${avgJitter.toFixed(1)} ms`} desc="Latency variation window" tone="purple" />
        <Kpi label="Max Latency" value={`${maxLatency.toFixed(1)} ms`} desc="Worst latency in latest window" tone="yellow" />
        <Kpi label="Min Throughput" value={`${minThroughput.toFixed(2)} Mbps`} desc="Lowest throughput in latest window" tone="red" />
        <Kpi label="Samples" value={history.length} desc={`Last refresh ${lastRefresh}`} />
      </section>

      <section className="grid gap-5 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Report Scope</h2>
          <div className="mt-4 space-y-3 text-sm text-slate-300">
            <p>• Live KPI snapshot: throughput, latency, jitter, packet loss, QoE score, and source.</p>
            <p>• Measurement window: average, minimum, maximum, and active alert interpretation.</p>
            <p>• Architecture: Cloud Run, FastAPI, Next.js, Cloud SQL, BigQuery, Pub/Sub, ML inference.</p>
            <p>• Engineering notes: SLA watch, buffering risk, latency/jitter diagnosis, and improvement actions.</p>
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Engineering Interpretation</h2>
          <div className="mt-4 space-y-3 text-sm text-slate-300">
            <p>
              The platform measures browser-to-Cloud Run performance and correlates it with QoE status.
              When throughput drops while latency and jitter rise, the dashboard classifies the condition as streaming risk.
            </p>
            <p>
              The current report intentionally avoids inactive architecture claims. GKE, Vertex AI, RTMP,
              Prometheus, and Grafana are treated as future enhancement options, not active runtime components.
            </p>
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
        <h2 className="text-xl font-black">Report Sample Window</h2>
        <div className="mt-5 overflow-x-auto rounded-2xl border border-slate-800">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950 text-xs uppercase tracking-[0.2em] text-slate-400">
              <tr>
                <th className="px-4 py-3">Timestamp</th>
                <th className="px-4 py-3">Throughput</th>
                <th className="px-4 py-3">Latency</th>
                <th className="px-4 py-3">Jitter</th>
                <th className="px-4 py-3">QoE</th>
              </tr>
            </thead>
            <tbody>
              {history.slice(0, 10).map((row, index) => (
                <tr key={index} className="border-t border-slate-800">
                  <td className="px-4 py-3">{row.timestamp || row.time || "-"}</td>
                  <td className="px-4 py-3 text-cyan-300">{n(row.throughput || row.downloadMbps || row.bandwidth).toFixed(2)} Mbps</td>
                  <td className="px-4 py-3 text-yellow-300">{n(row.latency).toFixed(1)} ms</td>
                  <td className="px-4 py-3 text-purple-300">{n(row.jitter).toFixed(1)} ms</td>
                  <td className="px-4 py-3 text-emerald-300">{n(row.qoe_score || row.qoeScore).toFixed(0)}</td>
                </tr>
              ))}
              {history.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-4 py-8 text-center text-slate-500">
                    Waiting for telemetry samples.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
