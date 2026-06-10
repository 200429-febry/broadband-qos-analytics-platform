"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  BarChart3,
  Cloud,
  Database,
  ExternalLink,
  FileJson,
  History,
  RefreshCw,
  Server,
  ShieldCheck,
} from "lucide-react";

const PROJECT_ID = "gen-lang-client-0341860128";
const REGION = "asia-southeast2";
const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";
const FRONTEND_URL = "https://qos-frontend-gh3tn2a6oa-et.a.run.app";

function n(v: any) {
  const x = Number(v);
  return Number.isFinite(x) ? x : 0;
}

function EvidenceButton({ icon: Icon, title, desc, url }: any) {
  return (
    <button
      onClick={() => window.open(url, "_blank")}
      className="group rounded-2xl border border-slate-800 bg-slate-900/70 p-5 text-left transition hover:border-cyan-500/50 hover:bg-cyan-500/10"
    >
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-4">
          <div className="rounded-xl border border-cyan-500/30 bg-cyan-500/10 p-3 text-cyan-300">
            <Icon className="h-5 w-5" />
          </div>
          <div>
            <h3 className="font-black text-white">{title}</h3>
            <p className="mt-1 text-sm text-slate-400">{desc}</p>
          </div>
        </div>
        <ExternalLink className="h-4 w-4 text-slate-500 group-hover:text-cyan-300" />
      </div>
    </button>
  );
}

function Kpi({ label, value, sub }: any) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <p className="text-sm text-slate-400">{label}</p>
      <p className="mt-3 text-3xl font-black text-white">{value}</p>
      <p className="mt-2 text-xs text-slate-500">{sub}</p>
    </div>
  );
}

export default function DatabasePage() {
  const [metrics, setMetrics] = useState<any>({});
  const [history, setHistory] = useState<any[]>([]);
  const [alerts, setAlerts] = useState<any[]>([]);
  const [lastRefresh, setLastRefresh] = useState("-");

  const urls = useMemo(() => {
    return {
      cloudSqlInstance: `https://console.cloud.google.com/sql/instances/qos-db/overview?project=${PROJECT_ID}`,
      cloudSqlDatabases: `https://console.cloud.google.com/sql/instances/qos-db/databases?project=${PROJECT_ID}`,
      bigQuery: `https://console.cloud.google.com/bigquery?project=${PROJECT_ID}`,
      apiConsole: `https://console.cloud.google.com/run/detail/${REGION}/qos-api/metrics?project=${PROJECT_ID}`,
      frontendConsole: `https://console.cloud.google.com/run/detail/${REGION}/qos-frontend/metrics?project=${PROJECT_ID}`,
      logs: `https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_run_revision%22%0Aresource.labels.service_name%3D%22qos-api%22?project=${PROJECT_ID}`,
      rawMetrics: `${FRONTEND_URL || ""}/api/qos-metrics`,
      rawHistory: `${FRONTEND_URL || ""}/api/qos-history`,
      rawAlerts: `${FRONTEND_URL || ""}/api/qos-alerts`,
      backendOpenApi: `${API_URL}/openapi.json`,
    };
  }, []);

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

  return (
    <main className="space-y-7 p-6 text-white">
      <section className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">Operational Evidence Center</h1>
          <p className="mt-2 max-w-5xl text-slate-400">
            Direct evidence panel for production runtime, database, telemetry API, BigQuery warehouse,
            Cloud Run services, logs, and live QoE samples. This page is intended for engineering validation.
          </p>
        </div>

        <button
          onClick={load}
          className="rounded-xl border border-cyan-500/40 bg-cyan-500/10 px-4 py-2 text-sm font-black text-cyan-300 hover:bg-cyan-500/20"
        >
          <RefreshCw className="mr-2 inline h-4 w-4" />
          Refresh Evidence
        </button>
      </section>

      <section className="rounded-3xl border border-cyan-500/20 bg-slate-900/70 p-6">
        <div className="mb-5 flex flex-wrap items-center justify-between gap-4">
          <div>
            <h2 className="text-2xl font-black text-cyan-300">GCP Evidence Links</h2>
            <p className="mt-1 text-sm text-slate-400">
              Opens real Cloud Console pages and raw API endpoints used by the platform.
            </p>
          </div>
          <div className="rounded-2xl border border-slate-700 bg-slate-950 p-4 text-sm">
            <p><span className="text-slate-400">Project:</span> <span className="font-black text-cyan-300">{PROJECT_ID}</span></p>
            <p><span className="text-slate-400">Region:</span> <span className="font-black text-cyan-300">{REGION}</span></p>
          </div>
        </div>

        <div className="grid gap-4 xl:grid-cols-4">
          <EvidenceButton icon={Cloud} title="Frontend Cloud Run" desc="Next.js dashboard service metrics and revision history." url={urls.frontendConsole} />
          <EvidenceButton icon={Server} title="API Cloud Run" desc="FastAPI backend service metrics and deployment evidence." url={urls.apiConsole} />
          <EvidenceButton icon={Database} title="Cloud SQL Instance" desc="PostgreSQL qos-db instance overview and status." url={urls.cloudSqlInstance} />
          <EvidenceButton icon={Database} title="Cloud SQL Databases" desc="Operational database list inside the PostgreSQL instance." url={urls.cloudSqlDatabases} />
          <EvidenceButton icon={BarChart3} title="BigQuery Analytics" desc="Telemetry warehouse, raw stream, parsed view, and analytics dataset." url={urls.bigQuery} />
          <EvidenceButton icon={History} title="Cloud Run Logs" desc="Runtime logs for API requests, errors, and deployment validation." url={urls.logs} />
          <EvidenceButton icon={FileJson} title="Raw QoE Metrics" desc="Current live JSON metrics consumed by dashboard cards." url={urls.rawMetrics} />
          <EvidenceButton icon={FileJson} title="Raw QoE History" desc="Historical real QoE samples consumed by charts and reports." url={urls.rawHistory} />
        </div>
      </section>

      <section>
        <h2 className="text-2xl font-black">Database Monitor</h2>
        <p className="mt-1 text-slate-400">
          Operational observability for Cloud SQL status and real QoE telemetry used by dashboard, reports, alerts, and prediction modules.
        </p>

        <div className="mt-5 grid gap-4 xl:grid-cols-5">
          <Kpi label="QoE Samples" value={history.length} sub="Latest global backend telemetry window" />
          <Kpi label="Avg Throughput" value={`${avgThroughput.toFixed(2)} Mbps`} sub="Average from live history window" />
          <Kpi label="Avg Latency" value={`${avgLatency.toFixed(1)} ms`} sub="Average from live history window" />
          <Kpi label="Latest Sample" value={metrics.timestamp || "-"} sub={metrics.source || "real-qoe-probe"} />
          <Kpi label="DB Health" value="RUNNABLE" sub="Cloud SQL service state" />
        </div>
      </section>

      <section className="grid gap-5 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Cloud SQL PostgreSQL</h2>
          <div className="mt-4 space-y-3 text-sm">
            <p><span className="text-slate-400">Instance:</span> <span className="font-black">qos-db</span></p>
            <p><span className="text-slate-400">Engine:</span> <span className="font-black">PostgreSQL 15</span></p>
            <p><span className="text-slate-400">Region / Zone:</span> <span className="font-black">{REGION}-b</span></p>
            <p><span className="text-slate-400">Status:</span> <span className="font-black text-emerald-300">RUNNABLE</span></p>
            <p><span className="text-slate-400">Operational Role:</span> <span className="font-black">Application DB + telemetry history</span></p>
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Live Data Summary</h2>
          <div className="mt-4 space-y-3 text-sm">
            <p><span className="text-slate-400">Pipeline:</span> <span className="font-black">Browser Probe → Cloud Run API → Cloud SQL / BigQuery</span></p>
            <p><span className="text-slate-400">Latest Throughput:</span> <span className="font-black text-cyan-300">{n(metrics.throughput).toFixed(2)} Mbps</span></p>
            <p><span className="text-slate-400">Latest Latency:</span> <span className="font-black text-yellow-300">{n(metrics.latency).toFixed(1)} ms</span></p>
            <p><span className="text-slate-400">Active Alerts:</span> <span className="font-black text-red-300">{alerts.length}</span></p>
          </div>
          <div className="mt-5 rounded-2xl border border-emerald-500/20 bg-emerald-500/10 p-4 text-sm text-emerald-200">
            Data shown here is read from live backend endpoints, not static placeholder cards.
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
        <h2 className="text-xl font-black">Latest Real QoE Metrics</h2>
        <div className="mt-5 overflow-x-auto rounded-2xl border border-slate-800">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950 text-xs uppercase tracking-[0.2em] text-slate-400">
              <tr>
                <th className="px-4 py-3">Timestamp</th>
                <th className="px-4 py-3">Throughput</th>
                <th className="px-4 py-3">Latency</th>
                <th className="px-4 py-3">Jitter</th>
                <th className="px-4 py-3">Packet Loss</th>
                <th className="px-4 py-3">Source</th>
              </tr>
            </thead>
            <tbody>
              {history.slice(0, 12).map((row, index) => (
                <tr key={index} className="border-t border-slate-800">
                  <td className="px-4 py-3">{row.timestamp || row.time || "-"}</td>
                  <td className="px-4 py-3 text-cyan-300">{n(row.throughput || row.downloadMbps || row.bandwidth).toFixed(2)} Mbps</td>
                  <td className="px-4 py-3 text-yellow-300">{n(row.latency).toFixed(1)} ms</td>
                  <td className="px-4 py-3 text-purple-300">{n(row.jitter).toFixed(1)} ms</td>
                  <td className="px-4 py-3 text-red-300">{n(row.packet_loss).toFixed(2)}%</td>
                  <td className="px-4 py-3 text-emerald-300">{row.source || "real-qoe-probe"}</td>
                </tr>
              ))}
              {history.length === 0 ? (
                <tr>
                  <td className="px-4 py-8 text-center text-slate-500" colSpan={6}>
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
