"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertTriangle,
  BarChart3,
  BrainCircuit,
  Cloud,
  Database,
  FileText,
  GitBranch,
  Radio,
  Server,
  ShieldCheck,
  Zap,
} from "lucide-react";

type Metrics = {
  throughput?: number;
  latency?: number;
  jitter?: number;
  packet_loss?: number;
  qoe_score?: number;
  streaming_status?: string;
  source?: string;
  timestamp?: string;
};

function n(v: any) {
  const x = Number(v);
  return Number.isFinite(x) ? x : 0;
}

function statusTone(status: string) {
  if (status === "EXCELLENT") return "border-emerald-500/40 bg-emerald-500/10 text-emerald-300";
  if (status === "STABLE") return "border-cyan-500/40 bg-cyan-500/10 text-cyan-300";
  if (status === "BUFFER RISK") return "border-yellow-500/40 bg-yellow-500/10 text-yellow-300";
  if (status === "POOR") return "border-red-500/40 bg-red-500/10 text-red-300";
  return "border-slate-700 bg-slate-900 text-slate-300";
}

function NodeCard({
  icon: Icon,
  title,
  subtitle,
  status,
  items,
  tone = "cyan",
}: {
  icon: any;
  title: string;
  subtitle: string;
  status: string;
  items: string[];
  tone?: "cyan" | "green" | "blue" | "yellow" | "purple" | "red";
}) {
  const color =
    tone === "green" ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-300" :
    tone === "blue" ? "border-blue-500/30 bg-blue-500/10 text-blue-300" :
    tone === "yellow" ? "border-yellow-500/30 bg-yellow-500/10 text-yellow-300" :
    tone === "purple" ? "border-purple-500/30 bg-purple-500/10 text-purple-300" :
    tone === "red" ? "border-red-500/30 bg-red-500/10 text-red-300" :
    "border-cyan-500/30 bg-cyan-500/10 text-cyan-300";

  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5 shadow-xl">
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className={`rounded-xl border p-3 ${color}`}>
            <Icon className="h-5 w-5" />
          </div>
          <div>
            <h3 className="font-black text-white">{title}</h3>
            <p className="text-xs text-slate-400">{subtitle}</p>
          </div>
        </div>
        <span className={`rounded-full border px-3 py-1 text-[10px] font-black ${color}`}>
          {status}
        </span>
      </div>

      <div className="mt-4 space-y-2">
        {items.map((item) => (
          <div key={item} className="flex items-start gap-2 text-sm text-slate-300">
            <span className="mt-2 h-1.5 w-1.5 rounded-full bg-cyan-300" />
            <span>{item}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function FlowArrow({ label }: { label: string }) {
  return (
    <div className="hidden items-center justify-center xl:flex">
      <div className="text-center">
        <div className="text-3xl font-black text-cyan-300">→</div>
        <div className="text-[10px] font-bold uppercase tracking-[0.2em] text-slate-500">{label}</div>
      </div>
    </div>
  );
}

export default function TopologyPage() {
  const [metrics, setMetrics] = useState<Metrics>({});
  const [history, setHistory] = useState<any[]>([]);
  const [alerts, setAlerts] = useState<any[]>([]);

  async function load() {
    const [m, h, a] = await Promise.all([
      fetch("/api/qos-metrics?x=" + Date.now(), { cache: "no-store" }).then(r => r.json()).catch(() => ({})),
      fetch("/api/qos-history?x=" + Date.now(), { cache: "no-store" }).then(r => r.json()).catch(() => []),
      fetch("/api/qos-alerts?x=" + Date.now(), { cache: "no-store" }).then(r => r.json()).catch(() => []),
    ]);
    setMetrics(m || {});
    setHistory(Array.isArray(h) ? h : []);
    setAlerts(Array.isArray(a) ? a : []);
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 5000);
    return () => clearInterval(interval);
  }, []);

  const status = String(metrics.streaming_status || "WAITING");
  const activeNodes = useMemo(() => [
    "Next.js Frontend on Cloud Run",
    "FastAPI QoE API on Cloud Run",
    "FastAPI ML Inference on Cloud Run",
    "Cloud SQL PostgreSQL",
    "BigQuery Analytics Dataset",
    "Pub/Sub Telemetry Topic",
    "Cloud Logging / Monitoring",
    "OpenCellID-based Coverage Dataset",
  ], []);

  return (
    <main className="space-y-7 p-6 text-white">
      <section className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">Network Service Topology</h1>
          <p className="mt-2 max-w-5xl text-slate-400">
            Production architecture view aligned with the actual deployed project: Cloud Run services,
            FastAPI backend, browser-side QoE probe, Cloud SQL, BigQuery, Pub/Sub, custom dashboard,
            report engine, and ML inference service.
          </p>
        </div>

        <button
          onClick={load}
          className="rounded-xl border border-cyan-500/40 bg-cyan-500/10 px-4 py-2 text-sm font-black text-cyan-300 hover:bg-cyan-500/20"
        >
          Refresh Topology
        </button>
      </section>

      <section className="grid gap-4 xl:grid-cols-4">
        <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
          <p className="text-sm text-slate-400">Current QoE Status</p>
          <p className={`mt-3 text-3xl font-black ${status === "POOR" ? "text-red-300" : status === "BUFFER RISK" ? "text-yellow-300" : "text-emerald-300"}`}>{status}</p>
        </div>
        <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
          <p className="text-sm text-slate-400">Throughput</p>
          <p className="mt-3 text-3xl font-black text-cyan-300">{n(metrics.throughput).toFixed(2)} Mbps</p>
        </div>
        <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
          <p className="text-sm text-slate-400">Latency</p>
          <p className="mt-3 text-3xl font-black text-yellow-300">{n(metrics.latency).toFixed(1)} ms</p>
        </div>
        <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
          <p className="text-sm text-slate-400">Active Alerts</p>
          <p className="mt-3 text-3xl font-black text-red-300">{alerts.length}</p>
        </div>
      </section>

      <section className="rounded-3xl border border-cyan-500/20 bg-slate-900/70 p-6">
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-2xl font-black">Active Production Flow</h2>
            <p className="mt-1 text-sm text-slate-400">
              This is the realistic flow used by the current deployed system.
            </p>
          </div>
          <span className={`rounded-full border px-4 py-2 text-xs font-black ${statusTone(status)}`}>
            GLOBAL REAL QOE MODE
          </span>
        </div>

        <div className="grid gap-4 xl:grid-cols-[1fr_80px_1fr_80px_1fr]">
          <NodeCard
            icon={Radio}
            title="Client / Streaming Scenario"
            subtitle="Browser, YouTube, user network"
            status="ACTIVE"
            tone="cyan"
            items={[
              "User opens dashboard and streaming workload side by side",
              "Browser generates real latency, jitter, upload, and download probes",
              "QoE changes when network path becomes unstable",
            ]}
          />
          <FlowArrow label="Probe" />
          <NodeCard
            icon={Cloud}
            title="Cloud Run Service Layer"
            subtitle="Next.js + FastAPI microservices"
            status="ACTIVE"
            tone="green"
            items={[
              "qos-frontend: enterprise dashboard and report UI",
              "qos-api: telemetry, QoE, alerts, users, coverage, and reports",
              "qos-ml-service: prediction and anomaly inference endpoint",
            ]}
          />
          <FlowArrow label="Store" />
          <NodeCard
            icon={Database}
            title="Data & Analytics Layer"
            subtitle="Cloud SQL, BigQuery, Pub/Sub"
            status="ACTIVE"
            tone="blue"
            items={[
              "Cloud SQL stores operational users, metrics, predictions, and audit history",
              "BigQuery stores telemetry warehouse and analytical tables",
              "Pub/Sub supports asynchronous telemetry ingestion pipeline",
            ]}
          />
        </div>

        <div className="mt-4 grid gap-4 xl:grid-cols-[1fr_80px_1fr_80px_1fr]">
          <NodeCard
            icon={BrainCircuit}
            title="ML Inference Layer"
            subtitle="FastAPI ML service"
            status="ACTIVE"
            tone="purple"
            items={[
              "Prediction service receives live QoE features",
              "Outputs predicted throughput, latency, anomaly score, and confidence",
              "Used by Prediction Center and recommendation panels",
            ]}
          />
          <FlowArrow label="Analyze" />
          <NodeCard
            icon={Activity}
            title="Observability & Alert Engine"
            subtitle="Custom app logic + Cloud Logging"
            status="ACTIVE"
            tone="yellow"
            items={[
              "Alerts are generated from QoE thresholds and ML risk state",
              "Cloud Run logs provide service-level deployment and runtime evidence",
              "Custom dashboard replaces Grafana for the current release",
            ]}
          />
          <FlowArrow label="Visualize" />
          <NodeCard
            icon={BarChart3}
            title="Dashboard & Report Layer"
            subtitle="Next.js enterprise console"
            status="ACTIVE"
            tone="green"
            items={[
              "Dashboard, streaming QoE, analytics, prediction, database evidence, and audit log",
              "PDF and CSV export generated from live backend telemetry",
              "Coverage map uses local OpenCellID-style BTS dataset",
            ]}
          />
        </div>
      </section>

      <section className="grid gap-5 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Active Components</h2>
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {activeNodes.map((item) => (
              <div key={item} className="rounded-xl border border-emerald-500/20 bg-emerald-500/10 p-4">
                <p className="font-bold text-emerald-300">{item}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Future Enhancement Layer</h2>
          <p className="mt-2 text-sm text-slate-400">
            These components are intentionally presented as expansion options, not active production claims.
          </p>
          <div className="mt-4 space-y-3">
            {[
              ["GKE / Kubernetes", "Optional migration for multi-service orchestration when workload grows."],
              ["Cloud Load Balancer", "Optional custom domain, CDN, WAF, and global HTTP routing layer."],
              ["Vertex AI", "Optional managed training and online prediction pipeline."],
              ["Prometheus + Grafana", "Optional external observability stack. Current release uses custom dashboard + Cloud Logging."],
              ["NGINX RTMP / HLS", "Optional internal video pipeline. Current release monitors external streaming activity."],
            ].map(([name, desc]) => (
              <div key={name} className="rounded-xl border border-yellow-500/20 bg-yellow-500/10 p-4">
                <p className="font-black text-yellow-300">{name}</p>
                <p className="mt-1 text-sm text-slate-300">{desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
        <h2 className="text-xl font-black">Telemetry Window</h2>
        <p className="mt-1 text-sm text-slate-400">
          Latest global backend QoE samples used by dashboard, reports, alerts, and ML features.
        </p>

        <div className="mt-5 overflow-x-auto rounded-2xl border border-slate-800">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950 text-xs uppercase tracking-[0.2em] text-slate-400">
              <tr>
                <th className="px-4 py-3">Time</th>
                <th className="px-4 py-3">Throughput</th>
                <th className="px-4 py-3">Latency</th>
                <th className="px-4 py-3">Jitter</th>
                <th className="px-4 py-3">QoE</th>
                <th className="px-4 py-3">Source</th>
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
                  <td className="px-4 py-3 text-slate-300">{row.source || "real-qoe-probe"}</td>
                </tr>
              ))}
              {history.length === 0 ? (
                <tr>
                  <td className="px-4 py-8 text-center text-slate-500" colSpan={6}>
                    Waiting for QoE telemetry. Open Streaming QoE to generate real browser-to-Cloud Run samples.
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
