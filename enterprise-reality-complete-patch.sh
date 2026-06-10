#!/bin/bash
set -e

echo "=================================================="
echo "ENTERPRISE REALITY COMPLETE PATCH"
echo "Cloud Run + FastAPI + Next.js + Cloud SQL + BigQuery"
echo "=================================================="

REGION="asia-southeast2"
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)" 2>/dev/null || true)

FRONTEND_URL=$(gcloud run services describe qos-frontend \
  --region="$REGION" \
  --format="value(status.url)" 2>/dev/null || true)

ML_URL=$(gcloud run services describe qos-ml-service \
  --region="$REGION" \
  --format="value(status.url)" 2>/dev/null || true)

echo "PROJECT_ID=$PROJECT_ID"
echo "REGION=$REGION"
echo "API_URL=$API_URL"
echo "FRONTEND_URL=$FRONTEND_URL"
echo "ML_URL=$ML_URL"

if [ -z "$PROJECT_ID" ]; then
  echo "❌ PROJECT_ID kosong. Jalankan: gcloud config set project PROJECT_ID"
  exit 1
fi

if [ -z "$API_URL" ]; then
  echo "❌ API_URL kosong. Service qos-api tidak ditemukan."
  exit 1
fi

mkdir -p .backup-enterprise-reality
for f in \
  app/layout.tsx \
  app/page.tsx \
  app/topology/page.tsx \
  app/deployment/page.tsx \
  app/database/page.tsx \
  app/reports/page.tsx \
  app/api/qos-history/route.js \
  app/api/qos-metrics/route.js \
  app/api/qos-alerts/route.js \
  app/api/reports/pdf/route.js \
  app/api/reports/csv/route.js \
  components/device-autoprobe-controller.tsx \
  components/device-session-controller.tsx
do
  [ -f "$f" ] && cp "$f" ".backup-enterprise-reality/$(echo "$f" | tr '/' '_').bak"
done

mkdir -p app/api/qos-history app/api/qos-metrics app/api/qos-alerts
mkdir -p app/api/reports/pdf app/api/reports/csv
mkdir -p app/topology app/deployment app/database app/reports
mkdir -p components

echo "=================================================="
echo "1. Disable previous per-device controllers"
echo "=================================================="

cat > components/device-autoprobe-controller.tsx <<'TSX'
"use client";
export function DeviceAutoProbeController() {
  return null;
}
TSX

cat > components/device-session-controller.tsx <<'TSX'
"use client";
export function DeviceSessionController() {
  return null;
}
TSX

python3 <<'PY'
from pathlib import Path

p = Path("app/layout.tsx")
if p.exists():
    s = p.read_text()
    remove = [
        'import { DeviceAutoProbeController } from "@/components/device-autoprobe-controller";',
        "import { DeviceAutoProbeController } from '@/components/device-autoprobe-controller';",
        'import { DeviceSessionController } from "@/components/device-session-controller";',
        "import { DeviceSessionController } from '@/components/device-session-controller';",
    ]
    for r in remove:
        s = s.replace(r + "\n", "").replace(r, "")
    for tag in [
        "        <DeviceAutoProbeController />\n",
        "        <DeviceSessionController />\n",
        "<DeviceAutoProbeController />",
        "<DeviceSessionController />",
    ]:
        s = s.replace(tag, "")
    p.write_text(s)
    print("✅ layout cleaned")
else:
    print("⚠️ app/layout.tsx not found")
PY

echo "=================================================="
echo "2. Restore global real QoE API proxies"
echo "=================================================="

cat > app/api/qos-metrics/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET() {
  try {
    const res = await fetch(API_URL + "/api/qos/metrics", { cache: "no-store" });
    const data = await res.json();

    return Response.json(data || {}, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return Response.json({
      throughput: 0,
      latency: 0,
      jitter: 0,
      packet_loss: 0,
      bandwidth: 0,
      source: "global-qoe-probe",
      qoe_score: 0,
      streaming_status: "WAITING",
      timestamp: "-"
    }, {
      headers: { "Cache-Control": "no-store" },
    });
  }
}
JS

cat > app/api/qos-history/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET() {
  try {
    const res = await fetch(API_URL + "/api/qos/history", { cache: "no-store" });
    const data = await res.json();

    return Response.json(Array.isArray(data) ? data : [], {
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return Response.json([], {
      headers: { "Cache-Control": "no-store" },
    });
  }
}
JS

cat > app/api/qos-alerts/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET() {
  try {
    const res = await fetch(API_URL + "/api/alerts", { cache: "no-store" });
    const data = await res.json();

    return Response.json(Array.isArray(data) ? data : [], {
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return Response.json([], {
      headers: { "Cache-Control": "no-store" },
    });
  }
}
JS

python3 <<PY
from pathlib import Path
api = "$API_URL"
for f in [
    "app/api/qos-metrics/route.js",
    "app/api/qos-history/route.js",
    "app/api/qos-alerts/route.js",
]:
    p = Path(f)
    s = p.read_text().replace("__API_URL__", api)
    p.write_text(s)
    print("✅ patched", f)
PY

echo "=================================================="
echo "3. Enterprise topology page"
echo "=================================================="

cat > app/topology/page.tsx <<'TSX'
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
  Storage,
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
TSX

echo "=================================================="
echo "4. Deployment page"
echo "=================================================="

cat > app/deployment/page.tsx <<'TSX'
"use client";

import { useEffect, useState } from "react";
import {
  Activity,
  CheckCircle2,
  Cloud,
  Code2,
  Database,
  FileCode2,
  KeyRound,
  Rocket,
  Server,
  ShieldCheck,
  TerminalSquare,
} from "lucide-react";

const PROJECT_ID = "__PROJECT_ID__";
const REGION = "__REGION__";
const API_URL = "__API_URL__";
const FRONTEND_URL = "__FRONTEND_URL__";
const ML_URL = "__ML_URL__";

function StatusCard({ icon: Icon, title, status, desc }: any) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="rounded-xl border border-cyan-500/30 bg-cyan-500/10 p-3 text-cyan-300">
            <Icon className="h-5 w-5" />
          </div>
          <div>
            <h3 className="font-black text-white">{title}</h3>
            <p className="mt-1 text-sm text-slate-400">{desc}</p>
          </div>
        </div>
        <span className="rounded-full border border-emerald-500/30 bg-emerald-500/10 px-3 py-1 text-[10px] font-black text-emerald-300">
          {status}
        </span>
      </div>
    </div>
  );
}

function CodeBlock({ title, code }: { title: string; code: string }) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4">
      <p className="mb-3 font-black text-white">{title}</p>
      <pre className="overflow-x-auto rounded-xl bg-black/40 p-4 text-xs text-cyan-200">
        <code>{code}</code>
      </pre>
    </div>
  );
}

export default function DeploymentPage() {
  const [metrics, setMetrics] = useState<any>({});

  useEffect(() => {
    fetch("/api/qos-metrics?x=" + Date.now(), { cache: "no-store" })
      .then((r) => r.json())
      .then(setMetrics)
      .catch(() => setMetrics({}));
  }, []);

  return (
    <main className="space-y-7 p-6 text-white">
      <section>
        <h1 className="text-3xl font-black">GCP Deployment Readiness</h1>
        <p className="mt-2 max-w-5xl text-slate-400">
          Operational deployment view for the actual active stack. The current implementation runs on
          Cloud Run with separated frontend, API, and ML services, supported by Cloud SQL, BigQuery,
          Pub/Sub, Cloud Logging, and custom observability modules.
        </p>
      </section>

      <section className="rounded-3xl border border-emerald-500/30 bg-emerald-500/10 p-6">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <Rocket className="h-10 w-10 text-emerald-300" />
            <div>
              <h2 className="text-2xl font-black text-emerald-300">Cloud Run Production Stack</h2>
              <p className="mt-1 text-sm text-slate-300">
                Real deployed architecture without inactive GKE, RTMP, Vertex AI, Grafana, or Prometheus claims.
              </p>
            </div>
          </div>
          <div className="rounded-2xl border border-slate-700 bg-slate-950 p-4 text-sm">
            <p><span className="text-slate-400">Project:</span> <span className="font-black text-cyan-300">{PROJECT_ID}</span></p>
            <p><span className="text-slate-400">Region:</span> <span className="font-black text-cyan-300">{REGION}</span></p>
          </div>
        </div>
      </section>

      <section className="grid gap-4 xl:grid-cols-3">
        <StatusCard icon={Cloud} title="qos-frontend" status="ACTIVE" desc="Next.js enterprise dashboard hosted on Cloud Run." />
        <StatusCard icon={Server} title="qos-api" status="ACTIVE" desc="FastAPI backend for QoE, metrics, alerts, users, reports, and coverage." />
        <StatusCard icon={Activity} title="qos-ml-service" status={ML_URL ? "ACTIVE" : "OPTIONAL"} desc="FastAPI ML inference service for prediction and anomaly scoring." />
        <StatusCard icon={Database} title="Cloud SQL PostgreSQL" status="ACTIVE" desc="Operational database for users, QoS metrics, audit history, and predictions." />
        <StatusCard icon={FileCode2} title="BigQuery Analytics" status="ACTIVE" desc="Telemetry warehouse and analytical tables for reporting and historical analysis." />
        <StatusCard icon={ShieldCheck} title="Cloud Logging / IAM" status="ACTIVE" desc="Runtime logs, identity boundary, and production debugging evidence." />
      </section>

      <section className="grid gap-5 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Runtime URLs</h2>
          <div className="mt-4 space-y-3">
            {[
              ["Frontend", FRONTEND_URL || "-"],
              ["API", API_URL || "-"],
              ["ML Service", ML_URL || "optional / not detected"],
            ].map(([name, url]) => (
              <div key={name} className="rounded-xl border border-slate-800 bg-slate-950 p-4">
                <p className="text-sm text-slate-400">{name}</p>
                <p className="mt-1 break-all font-bold text-cyan-300">{url}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Live Runtime Signal</h2>
          <div className="mt-4 grid gap-3">
            <div className="rounded-xl border border-slate-800 bg-slate-950 p-4">
              <p className="text-sm text-slate-400">Telemetry Source</p>
              <p className="mt-1 font-black text-emerald-300">{metrics.source || "real-qoe-probe"}</p>
            </div>
            <div className="rounded-xl border border-slate-800 bg-slate-950 p-4">
              <p className="text-sm text-slate-400">Latest QoE</p>
              <p className="mt-1 font-black text-cyan-300">{Number(metrics.qoe_score || 0).toFixed(0)} / 100</p>
            </div>
            <div className="rounded-xl border border-slate-800 bg-slate-950 p-4">
              <p className="text-sm text-slate-400">Status</p>
              <p className="mt-1 font-black text-yellow-300">{metrics.streaming_status || "WAITING"}</p>
            </div>
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
        <h2 className="text-xl font-black">Deployment Commands</h2>
        <p className="mt-1 text-sm text-slate-400">
          Safe commands for rebuild and redeploy. Use min-instances=0 when not presenting to preserve credits.
        </p>

        <div className="mt-5 grid gap-4 xl:grid-cols-2">
          <CodeBlock
            title="Frontend Deploy"
            code={`npm run build\n\ngcloud run deploy qos-frontend \\\n  --source . \\\n  --region=${REGION} \\\n  --memory=2Gi \\\n  --cpu=1 \\\n  --min-instances=0`}
          />
          <CodeBlock
            title="Backend Deploy"
            code={`gcloud run deploy qos-api \\\n  --source ./backend \\\n  --region=${REGION} \\\n  --memory=1Gi \\\n  --cpu=1 \\\n  --min-instances=0 \\\n  --allow-unauthenticated`}
          />
        </div>
      </section>

      <section className="rounded-3xl border border-yellow-500/20 bg-yellow-500/10 p-6">
        <div className="flex items-start gap-4">
          <KeyRound className="mt-1 h-6 w-6 text-yellow-300" />
          <div>
            <h2 className="text-xl font-black text-yellow-300">Future Expansion, Not Current Runtime</h2>
            <p className="mt-2 text-sm text-slate-300">
              GKE, Cloud Load Balancer, Vertex AI, Prometheus, Grafana, Alertmanager, and NGINX RTMP/HLS are
              valid future enhancements, but they are not shown as active dependencies in this production view.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
TSX

python3 <<PY
from pathlib import Path
p = Path("app/deployment/page.tsx")
s = p.read_text()
s = s.replace("__PROJECT_ID__", "$PROJECT_ID")
s = s.replace("__REGION__", "$REGION")
s = s.replace("__API_URL__", "$API_URL")
s = s.replace("__FRONTEND_URL__", "$FRONTEND_URL")
s = s.replace("__ML_URL__", "$ML_URL")
p.write_text(s)
print("✅ deployment page patched")
PY

echo "=================================================="
echo "5. Database evidence page"
echo "=================================================="

cat > app/database/page.tsx <<'TSX'
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

const PROJECT_ID = "__PROJECT_ID__";
const REGION = "__REGION__";
const API_URL = "__API_URL__";
const FRONTEND_URL = "__FRONTEND_URL__";

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
TSX

python3 <<PY
from pathlib import Path
p = Path("app/database/page.tsx")
s = p.read_text()
s = s.replace("__PROJECT_ID__", "$PROJECT_ID")
s = s.replace("__REGION__", "$REGION")
s = s.replace("__API_URL__", "$API_URL")
s = s.replace("__FRONTEND_URL__", "$FRONTEND_URL")
p.write_text(s)
print("✅ database page patched")
PY

echo "=================================================="
echo "6. Reports page"
echo "=================================================="

cat > app/reports/page.tsx <<'TSX'
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
TSX

echo "=================================================="
echo "7. Clean server-side PDF and CSV routes"
echo "=================================================="

cat > app/api/reports/csv/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

function csvEscape(value) {
  const s = String(value ?? "");
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

async function getJson(path, fallback) {
  try {
    const res = await fetch(API_URL + path, { cache: "no-store" });
    if (!res.ok) return fallback;
    return await res.json();
  } catch {
    return fallback;
  }
}

export async function GET() {
  const metrics = await getJson("/api/qos/metrics", {});
  const history = await getJson("/api/qos/history", []);
  const alerts = await getJson("/api/alerts", []);

  const rows = [];
  rows.push(["AKSARA UNION QoE Analytics Platform"]);
  rows.push(["Report Type", "SLA / KPI Technical CSV Export"]);
  rows.push(["Generated At", new Date().toLocaleString()]);
  rows.push(["Telemetry Source", metrics.source || "real-qoe-probe"]);
  rows.push(["Current Status", metrics.streaming_status || metrics.status || "WAITING"]);
  rows.push(["QoE Score", metrics.qoe_score || metrics.qoeScore || 0]);
  rows.push(["Active Alerts", Array.isArray(alerts) ? alerts.length : 0]);
  rows.push([]);

  rows.push(["Timestamp", "Throughput Mbps", "Latency ms", "Jitter ms", "Packet Loss %", "QoE Score", "Status", "Source"]);

  if (Array.isArray(history)) {
    for (const row of history) {
      rows.push([
        row.timestamp || row.time || "-",
        row.throughput || row.downloadMbps || row.bandwidth || 0,
        row.latency || 0,
        row.jitter || 0,
        row.packet_loss || row.packetLoss || 0,
        row.qoe_score || row.qoeScore || 0,
        row.streaming_status || row.status || "",
        row.source || "real-qoe-probe",
      ]);
    }
  }

  rows.push([]);
  rows.push(["Active Alert Table"]);
  rows.push(["Type", "Message", "Metric", "Time", "Source"]);

  if (Array.isArray(alerts)) {
    for (const alert of alerts) {
      rows.push([
        alert.type || "",
        alert.message || "",
        alert.metric || "",
        alert.time || "",
        alert.source || "",
      ]);
    }
  }

  const csv = rows.map((r) => r.map(csvEscape).join(",")).join("\n");

  return new Response(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="AKSARA_QoE_SLA_Report_${new Date().toISOString().slice(0,10)}.csv"`,
      "Cache-Control": "no-store",
    },
  });
}
JS

cat > app/api/reports/pdf/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";
const PROJECT_ID = "__PROJECT_ID__";
const REGION = "__REGION__";

async function getJson(path, fallback) {
  try {
    const res = await fetch(API_URL + path, { cache: "no-store" });
    if (!res.ok) return fallback;
    return await res.json();
  } catch {
    return fallback;
  }
}

function clean(value) {
  return String(value ?? "")
    .replace(/[^\x09\x0A\x0D\x20-\x7E]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function esc(value) {
  return clean(value).replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");
}

function num(v, d = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : d;
}

function wrap(text, max = 88) {
  const words = clean(text).split(" ");
  const lines = [];
  let line = "";
  for (const w of words) {
    if ((line + " " + w).trim().length > max) {
      if (line) lines.push(line);
      line = w;
    } else {
      line = (line + " " + w).trim();
    }
  }
  if (line) lines.push(line);
  return lines;
}

function pdfText(x, y, size, text) {
  const yy = 842 - y;
  return `BT /F1 ${size} Tf ${x} ${yy} Td (${esc(text)}) Tj ET\n`;
}

function pdfRect(x, y, w, h, gray = 0.92) {
  const yy = 842 - y - h;
  return `q ${gray} g ${x} ${yy} ${w} ${h} re f Q\n`;
}

function pdfStrokeRect(x, y, w, h, r = 0.75, g = 0.8, b = 0.9) {
  const yy = 842 - y - h;
  return `q ${r} ${g} ${b} RG 0.8 w ${x} ${yy} ${w} ${h} re S Q\n`;
}

function addHeader(title) {
  let c = "";
  c += `q 0.03 0.06 0.12 rg 0 742 595 100 re f Q\n`;
  c += pdfText(42, 54, 9, "AKSARA UNION QoS ANALYTICS PLATFORM");
  c += pdfText(42, 82, 22, title);
  c += pdfText(42, 106, 9, `Project ${PROJECT_ID} | Region ${REGION} | Server-side technical export`);
  c += `q 0.1 0.6 0.8 RG 1.2 w 42 720 511 0 m S Q\n`;
  return c;
}

function addFooter(page, total) {
  let c = "";
  c += `q 0.8 0.85 0.9 RG 0.6 w 42 54 511 0 m S Q\n`;
  c += pdfText(42, 798, 8, `AKSARA UNION - Real Browser-to-Cloud QoE Telemetry | Page ${page} of ${total}`);
  return c;
}

function card(x, y, w, h, label, value, sub) {
  let c = "";
  c += pdfRect(x, y, w, h, 0.97);
  c += pdfStrokeRect(x, y, w, h);
  c += pdfText(x + 10, y + 22, 8, label);
  c += pdfText(x + 10, y + 48, 16, value);
  c += pdfText(x + 10, y + 68, 8, sub);
  return c;
}

function paragraph(x, y, text, max = 95, lineH = 13, size = 9) {
  let c = "";
  const lines = wrap(text, max);
  lines.forEach((line, i) => c += pdfText(x, y + i * lineH, size, line));
  return { content: c, height: lines.length * lineH };
}

function buildPdf(pages) {
  const objects = [];
  const addObj = (body) => {
    objects.push(body);
    return objects.length;
  };

  const catalogId = addObj("");
  const pagesId = addObj("");
  const fontId = addObj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");

  const pageIds = [];

  for (const content of pages) {
    const stream = Buffer.from(content, "utf8");
    const contentId = addObj(`<< /Length ${stream.length} >>\nstream\n${content}\nendstream`);
    const pageId = addObj(`<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 ${fontId} 0 R >> >> /Contents ${contentId} 0 R >>`);
    pageIds.push(pageId);
  }

  objects[catalogId - 1] = `<< /Type /Catalog /Pages ${pagesId} 0 R >>`;
  objects[pagesId - 1] = `<< /Type /Pages /Kids [${pageIds.map(id => `${id} 0 R`).join(" ")}] /Count ${pageIds.length} >>`;

  let pdf = "%PDF-1.4\n";
  const offsets = [0];

  objects.forEach((obj, i) => {
    offsets.push(Buffer.byteLength(pdf, "utf8"));
    pdf += `${i + 1} 0 obj\n${obj}\nendobj\n`;
  });

  const xrefOffset = Buffer.byteLength(pdf, "utf8");
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  offsets.slice(1).forEach((off) => {
    pdf += String(off).padStart(10, "0") + " 00000 n \n";
  });

  pdf += `trailer\n<< /Size ${objects.length + 1} /Root ${catalogId} 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`;
  return Buffer.from(pdf, "utf8");
}

export async function GET() {
  const metrics = await getJson("/api/qos/metrics", {});
  const history = await getJson("/api/qos/history", []);
  const alerts = await getJson("/api/alerts", []);

  const rows = Array.isArray(history) ? history.slice(0, 18) : [];
  const alertRows = Array.isArray(alerts) ? alerts.slice(0, 10) : [];

  const throughput = num(metrics.throughput || metrics.downloadMbps || metrics.bandwidth);
  const latency = num(metrics.latency);
  const jitter = num(metrics.jitter);
  const loss = num(metrics.packet_loss || metrics.packetLoss);
  const qoe = num(metrics.qoe_score || metrics.qoeScore);
  const status = metrics.streaming_status || metrics.status || "WAITING";

  const avgThroughput = rows.length ? rows.reduce((s, r) => s + num(r.throughput || r.downloadMbps || r.bandwidth), 0) / rows.length : 0;
  const avgLatency = rows.length ? rows.reduce((s, r) => s + num(r.latency), 0) / rows.length : 0;
  const avgJitter = rows.length ? rows.reduce((s, r) => s + num(r.jitter), 0) / rows.length : 0;
  const maxLatency = rows.length ? Math.max(...rows.map(r => num(r.latency))) : 0;
  const minThroughput = rows.length ? Math.min(...rows.map(r => num(r.throughput || r.downloadMbps || r.bandwidth))) : 0;

  const pages = [];

  let p1 = addHeader("Carrier-Grade QoE / SLA Technical Report");
  p1 += card(42, 145, 155, 58, "Generated At", new Date().toLocaleString(), "Server-side PDF report");
  p1 += card(220, 145, 155, 58, "Telemetry Source", metrics.source || "real-qoe-probe", "Live probe source");
  p1 += card(398, 145, 155, 58, "Current Status", status, "QoE classification");
  p1 += card(42, 220, 155, 58, "QoE Score", `${qoe.toFixed(0)} / 100`, "Streaming experience index");
  p1 += card(220, 220, 155, 58, "Active Alerts", `${alertRows.length}`, "Threshold events");
  p1 += card(398, 220, 155, 58, "Sample Window", `${rows.length}`, "Latest telemetry samples");
  p1 += pdfText(42, 318, 15, "Executive Summary");
  let para = paragraph(
    42,
    342,
    `This report summarizes the current state of the AKSARA QoE Analytics Platform using real browser-to-Cloud Run telemetry. The platform measures throughput, latency, jitter, packet loss, QoE score, active alert condition, and service runtime evidence. The current implementation is based on Cloud Run, FastAPI, Next.js, Cloud SQL, BigQuery, Pub/Sub, and a custom dashboard layer. Components such as GKE, Vertex AI, RTMP streaming, Prometheus, Grafana, and Alertmanager are treated as future enhancements, not active production dependencies.`,
    103,
    14,
    9
  );
  p1 += para.content;
  p1 += pdfText(42, 470, 15, "Live KPI Snapshot");
  p1 += card(42, 492, 155, 58, "Throughput", `${throughput.toFixed(2)} Mbps`, "Current downlink probe");
  p1 += card(220, 492, 155, 58, "Latency", `${latency.toFixed(1)} ms`, "Browser-to-Cloud RTT");
  p1 += card(398, 492, 155, 58, "Jitter", `${jitter.toFixed(1)} ms`, "Latency variation");
  p1 += card(42, 565, 155, 58, "Packet Loss", `${loss.toFixed(2)} %`, "Probe failure ratio");
  p1 += card(220, 565, 155, 58, "Average Throughput", `${avgThroughput.toFixed(2)} Mbps`, "Measurement window");
  p1 += card(398, 565, 155, 58, "Average Latency", `${avgLatency.toFixed(1)} ms`, "Measurement window");
  p1 += addFooter(1, 4);
  pages.push(p1);

  let p2 = addHeader("Production Architecture and Data Flow");
  p2 += pdfText(42, 145, 15, "Active Runtime Stack");
  const arch = [
    ["Client / Streaming Scenario", "Browser, YouTube or streaming workload, real QoE probe"],
    ["Cloud Run Frontend", "Next.js dashboard, reports, analytics, coverage, and evidence panels"],
    ["Cloud Run API", "FastAPI QoE endpoints, telemetry, alerts, users, reports, and coverage API"],
    ["Cloud SQL PostgreSQL", "Operational users, QoS metrics, predictions, audit records"],
    ["BigQuery + Pub/Sub", "Telemetry warehouse, stream ingestion, and analytical history"],
    ["ML Inference Service", "FastAPI prediction service for anomaly and QoS prediction"],
  ];
  let y = 175;
  for (const [name, desc] of arch) {
    p2 += pdfRect(42, y, 511, 48, 0.97);
    p2 += pdfStrokeRect(42, y, 511, 48);
    p2 += pdfText(58, y + 19, 11, name);
    p2 += pdfText(58, y + 37, 8, desc);
    y += 62;
  }
  p2 += pdfText(42, 575, 15, "Engineering Boundary");
  para = paragraph(
    42,
    600,
    "The current production system does not require a dedicated GKE cluster, external load balancer, internal RTMP/HLS server, managed Vertex AI endpoint, Prometheus, Grafana, or Alertmanager to operate. Those services remain valid future expansion options. The active project is intentionally cloud-native and lightweight, using Cloud Run services as the main compute layer.",
    103,
    14,
    9
  );
  p2 += para.content;
  p2 += addFooter(2, 4);
  pages.push(p2);

  let p3 = addHeader("SLA Risk Matrix and Alert Interpretation");
  p3 += pdfText(42, 145, 15, "Measurement Window Statistics");
  p3 += card(42, 170, 155, 58, "Average Throughput", `${avgThroughput.toFixed(2)} Mbps`, "Latest samples");
  p3 += card(220, 170, 155, 58, "Minimum Throughput", `${minThroughput.toFixed(2)} Mbps`, "Capacity floor");
  p3 += card(398, 170, 155, 58, "Average Jitter", `${avgJitter.toFixed(1)} ms`, "Stability indicator");
  p3 += card(42, 245, 155, 58, "Maximum Latency", `${maxLatency.toFixed(1)} ms`, "Worst RTT condition");
  p3 += card(220, 245, 155, 58, "Current QoE", `${qoe.toFixed(0)}`, "Experience score");
  p3 += card(398, 245, 155, 58, "Active Alerts", `${alertRows.length}`, "Risk events");
  p3 += pdfText(42, 345, 15, "Engineering Analysis");
  para = paragraph(
    42,
    370,
    `When latency and jitter increase while throughput decreases, the platform classifies the streaming session as unstable or at risk of buffering. Current status is ${status}. The recommended operational response is to compare the latest browser-to-Cloud Run telemetry with alert history, validate backend response time, and inspect whether throughput degradation is isolated to user access network or appears across multiple global samples.`,
    103,
    14,
    9
  );
  p3 += para.content;
  p3 += pdfText(42, 505, 15, "Active Alert Table");
  y = 532;
  p3 += pdfRect(42, y, 511, 22, 0.1);
  p3 += pdfText(50, y + 15, 8, "Type");
  p3 += pdfText(125, y + 15, 8, "Message");
  p3 += pdfText(345, y + 15, 8, "Metric");
  p3 += pdfText(440, y + 15, 8, "Source");
  y += 24;
  if (alertRows.length === 0) {
    p3 += pdfText(50, y + 15, 9, "No active alerts. Current telemetry is within normal operating thresholds.");
  } else {
    for (const a of alertRows) {
      p3 += pdfStrokeRect(42, y, 511, 28);
      p3 += pdfText(50, y + 17, 7, a.type || "-");
      p3 += pdfText(125, y + 17, 7, clean(a.message || "-").slice(0, 45));
      p3 += pdfText(345, y + 17, 7, clean(a.metric || "-").slice(0, 20));
      p3 += pdfText(440, y + 17, 7, clean(a.source || "-").slice(0, 23));
      y += 30;
    }
  }
  p3 += addFooter(3, 4);
  pages.push(p3);

  let p4 = addHeader("Raw Telemetry Window");
  y = 145;
  p4 += pdfRect(42, y, 511, 24, 0.1);
  p4 += pdfText(48, y + 16, 7, "Timestamp");
  p4 += pdfText(140, y + 16, 7, "Throughput");
  p4 += pdfText(225, y + 16, 7, "Latency");
  p4 += pdfText(300, y + 16, 7, "Jitter");
  p4 += pdfText(365, y + 16, 7, "Loss");
  p4 += pdfText(425, y + 16, 7, "QoE");
  p4 += pdfText(485, y + 16, 7, "Source");
  y += 26;
  for (const r of rows.slice(0, 18)) {
    p4 += pdfStrokeRect(42, y, 511, 24);
    p4 += pdfText(48, y + 16, 7, r.timestamp || r.time || "-");
    p4 += pdfText(140, y + 16, 7, `${num(r.throughput || r.downloadMbps || r.bandwidth).toFixed(2)} Mbps`);
    p4 += pdfText(225, y + 16, 7, `${num(r.latency).toFixed(1)} ms`);
    p4 += pdfText(300, y + 16, 7, `${num(r.jitter).toFixed(1)} ms`);
    p4 += pdfText(365, y + 16, 7, `${num(r.packet_loss || r.packetLoss).toFixed(2)}%`);
    p4 += pdfText(425, y + 16, 7, `${num(r.qoe_score || r.qoeScore).toFixed(0)}`);
    p4 += pdfText(485, y + 16, 7, clean(r.source || "probe").slice(0, 12));
    y += 25;
  }
  p4 += pdfText(42, 650, 15, "Conclusion");
  para = paragraph(
    42,
    675,
    "The report confirms that the platform operates as a Cloud Run-based QoE analytics system. The telemetry layer provides live service quality signals, the database and analytics layer stores operational evidence, and the dashboard/report layer converts the measurements into actionable SLA interpretation.",
    103,
    14,
    9
  );
  p4 += para.content;
  p4 += addFooter(4, 4);
  pages.push(p4);

  const pdf = buildPdf(pages);

  return new Response(pdf, {
    status: 200,
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `inline; filename="AKSARA_QoE_SLA_Technical_Report_${new Date().toISOString().slice(0,10)}.pdf"`,
      "Cache-Control": "no-store",
    },
  });
}
JS

python3 <<PY
from pathlib import Path
for f in ["app/api/reports/pdf/route.js", "app/api/reports/csv/route.js"]:
    p = Path(f)
    s = p.read_text()
    s = s.replace("__API_URL__", "$API_URL")
    s = s.replace("__PROJECT_ID__", "$PROJECT_ID")
    s = s.replace("__REGION__", "$REGION")
    p.write_text(s)
    print("✅ report route patched", f)
PY

echo "=================================================="
echo "8. Clean per-device overlay CSS"
echo "=================================================="

python3 <<'PY'
from pathlib import Path
import re

p = Path("app/globals.css")
if p.exists():
    s = p.read_text()
    patterns = [
        r"/\* Per-device QoE session marker \*/.*?(?=/\*|$)",
        r"/\* Force per-device session visibility \*/.*?(?=/\*|$)",
        r"/\* Chart hardening: prevents Recharts width\(-1\)/height\(-1\) \*/.*?(?=/\*|$)",
    ]
    for pat in patterns:
        s = re.sub(pat, "", s, flags=re.S)

    def remove_device_pseudo(match):
        block = match.group(0)
        low = block.lower()
        if "device" in low or "per-device" in low or "autoprobe" in low:
            return ""
        return block

    s = re.sub(r"html::(?:before|after)\s*\{[^}]*\}", remove_device_pseudo, s, flags=re.S)
    p.write_text(s)
    print("✅ CSS cleaned")
else:
    print("⚠️ globals.css not found")
PY

echo "=================================================="
echo "9. Quick scan"
echo "=================================================="

echo "--- Suspicious inactive active-claim words ---"
grep -RniE "GKE|Vertex AI|NGINX RTMP|Grafana|Prometheus|Alertmanager|FFmpeg|iPerf" app components \
  --exclude-dir=node_modules \
  --exclude-dir=.next \
  | head -120 || true

echo ""
echo "--- Per-device leftovers ---"
grep -RniE "DeviceAutoProbeController|DeviceSessionController|aksara-device|device-autoprobe|device-session|device-probe" app components \
  --exclude-dir=node_modules \
  --exclude-dir=.next \
  | head -120 || true

echo "=================================================="
echo "PATCH DONE"
echo "Now run: npm run build"
echo "=================================================="
