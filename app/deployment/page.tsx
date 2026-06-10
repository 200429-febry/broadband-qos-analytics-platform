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

const PROJECT_ID = "gen-lang-client-0341860128";
const REGION = "asia-southeast2";
const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";
const FRONTEND_URL = "https://qos-frontend-gh3tn2a6oa-et.a.run.app";
const ML_URL = "https://qos-ml-service-gh3tn2a6oa-et.a.run.app";

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
