"use client";

import {
  Activity,
  Database,
  ExternalLink,
  FileSearch,
  Server,
  ShieldCheck,
  TerminalSquare,
} from "lucide-react";

const GCP_PROJECT_ID = "gen-lang-client-0341860128";
const REGION = "asia-southeast2";
const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

function cloudConsole(path: string) {
  const joiner = path.includes("?") ? "&" : "?";
  return `https://console.cloud.google.com/${path}${joiner}project=${GCP_PROJECT_ID}`;
}

const proofLinks = [
  {
    title: "Open Cloud SQL Instance",
    desc: "Operational PostgreSQL instance used by the platform.",
    href: cloudConsole("sql/instances/qos-db/overview"),
    icon: Database,
    color: "text-emerald-300",
  },
  {
    title: "Open Cloud SQL Databases",
    desc: "Database inventory and operational schema visibility.",
    href: cloudConsole("sql/instances/qos-db/databases"),
    icon: Server,
    color: "text-cyan-300",
  },
  {
    title: "Open BigQuery Analytics",
    desc: "Telemetry warehouse and analytical dataset evidence.",
    href: cloudConsole("bigquery"),
    icon: FileSearch,
    color: "text-yellow-300",
  },
  {
    title: "Open API Service Console",
    desc: "FastAPI Cloud Run service handling QoS endpoints.",
    href: cloudConsole(`run/detail/${REGION}/qos-api/metrics`),
    icon: Activity,
    color: "text-purple-300",
  },
  {
    title: "Open API Logs",
    desc: "Runtime request logs from dashboard, reports, and telemetry probes.",
    href: cloudConsole(`run/detail/${REGION}/qos-api/logs`),
    icon: ShieldCheck,
    color: "text-red-300",
  },
  {
    title: "Open Raw QoS Metrics",
    desc: "Current JSON telemetry consumed by the dashboard.",
    href: `${API_URL}/api/qos/metrics`,
    icon: TerminalSquare,
    color: "text-blue-300",
  },
  {
    title: "Open Raw QoS History",
    desc: "Real browser-to-cloud telemetry history window.",
    href: `${API_URL}/api/qos/history`,
    icon: Database,
    color: "text-emerald-300",
  },
  {
    title: "Open Raw QoE Latest",
    desc: "Latest QoE probe buffer from active browser sessions.",
    href: `${API_URL}/api/qoe/latest`,
    icon: Activity,
    color: "text-cyan-300",
  },
];

export function GcpDatabaseProofButtons() {
  const commandText =
    `curl -s ${API_URL}/api/qos/metrics\n` +
    `curl -s ${API_URL}/api/qos/history | head -c 800\n` +
    `curl -s ${API_URL}/api/qoe/latest | head -c 800`;

  return (
    <section className="mb-6 rounded-3xl border border-cyan-500/30 bg-cyan-500/5 p-6">
      <div className="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-black text-cyan-300">
            System Evidence Center
          </h2>
          <p className="mt-2 max-w-4xl text-sm leading-relaxed text-slate-400">
            Direct engineering links to Google Cloud Console and live telemetry endpoints.
            Use this panel to verify Cloud SQL, BigQuery, Cloud Run API, service logs,
            and raw QoE data flowing into the platform.
          </p>
        </div>

        <div className="rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-xs text-slate-300">
          <p>
            Project: <span className="font-bold text-cyan-300">{GCP_PROJECT_ID}</span>
          </p>
          <p>
            Region: <span className="font-bold text-emerald-300">{REGION}</span>
          </p>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {proofLinks.map((item) => {
          const Icon = item.icon;

          return (
            <a
              key={item.title}
              href={item.href}
              target="_blank"
              rel="noopener noreferrer"
              className="group rounded-2xl border border-slate-800 bg-slate-900/80 p-5 transition hover:border-cyan-500/60 hover:bg-slate-900"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex gap-4">
                  <div className="rounded-xl border border-slate-700 bg-slate-950 p-3">
                    <Icon className={`h-5 w-5 ${item.color}`} />
                  </div>

                  <div>
                    <h3 className="font-black text-white group-hover:text-cyan-300">
                      {item.title}
                    </h3>
                    <p className="mt-2 text-sm leading-relaxed text-slate-400">
                      {item.desc}
                    </p>
                  </div>
                </div>

                <ExternalLink className="h-4 w-4 shrink-0 text-slate-500 group-hover:text-cyan-300" />
              </div>
            </a>
          );
        })}
      </div>

      <div className="mt-5 rounded-2xl border border-slate-800 bg-slate-950/80 p-4">
        <p className="text-sm font-bold text-white">Quick verification commands:</p>
        <pre className="mt-3 overflow-x-auto rounded-xl bg-black/40 p-4 text-xs text-cyan-200">
          {commandText}
        </pre>
      </div>
    </section>
  );
}
