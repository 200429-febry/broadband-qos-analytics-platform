#!/bin/bash
set -e

echo "=================================================="
echo "ADD DATABASE PROOF BUTTONS FOR LECTURER"
echo "=================================================="

REGION="asia-southeast2"
PROJECT_ID=$(gcloud config get-value project)
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

FRONTEND_URL=$(gcloud run services describe qos-frontend \
  --region="$REGION" \
  --format="value(status.url)")

echo "PROJECT_ID=$PROJECT_ID"
echo "API_URL=$API_URL"
echo "FRONTEND_URL=$FRONTEND_URL"

mkdir -p .backup-db-proof
[ -f app/database/page.tsx ] && cp app/database/page.tsx .backup-db-proof/database-page.tsx.bak

mkdir -p components

cat > components/gcp-database-proof-buttons.tsx <<TSX
"use client";

import {
  Database,
  ExternalLink,
  FileSearch,
  Server,
  Activity,
  ShieldCheck,
} from "lucide-react";

const GCP_PROJECT_ID = "$PROJECT_ID";
const REGION = "$REGION";
const API_URL = "$API_URL";

function cloudConsole(path: string) {
  const joiner = path.includes("?") ? "&" : "?";
  return \`https://console.cloud.google.com/\${path}\${joiner}project=\${GCP_PROJECT_ID}\`;
}

const proofLinks = [
  {
    title: "Open Cloud SQL Instance",
    desc: "Bukti database PostgreSQL qos-db yang dipakai aplikasi.",
    href: cloudConsole("sql/instances/qos-db/overview"),
    icon: Database,
    color: "text-emerald-300",
  },
  {
    title: "Open Cloud SQL Databases",
    desc: "Melihat daftar database/tabel operasional Cloud SQL.",
    href: cloudConsole("sql/instances/qos-db/databases"),
    icon: Server,
    color: "text-cyan-300",
  },
  {
    title: "Open BigQuery Analytics",
    desc: "Bukti dataset analytics / telemetry warehouse.",
    href: cloudConsole("bigquery?ws=!1m0"),
    icon: FileSearch,
    color: "text-yellow-300",
  },
  {
    title: "Open API Service Console",
    desc: "Bukti backend FastAPI Cloud Run yang membaca data.",
    href: cloudConsole(\`run/detail/\${REGION}/qos-api/metrics\`),
    icon: Activity,
    color: "text-purple-300",
  },
  {
    title: "Open API Logs",
    desc: "Melihat request real-time dari dashboard ke backend.",
    href: cloudConsole(\`run/detail/\${REGION}/qos-api/logs\`),
    icon: ShieldCheck,
    color: "text-red-300",
  },
  {
    title: "Open Raw QoE History",
    desc: "Endpoint JSON real telemetry yang dipakai dashboard.",
    href: \`\${API_URL}/api/qos/history\`,
    icon: Database,
    color: "text-blue-300",
  },
];

export function GcpDatabaseProofButtons() {
  return (
    <section className="mb-6 rounded-3xl border border-cyan-500/30 bg-cyan-500/5 p-6">
      <div className="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-black text-cyan-300">
            Database Proof / Lecturer Evidence
          </h2>
          <p className="mt-2 max-w-4xl text-sm text-slate-400">
            Tombol ini membuka bukti langsung di Google Cloud Console dan endpoint real telemetry.
            Gunakan saat presentasi untuk menunjukkan bahwa dashboard memakai Cloud SQL, BigQuery,
            Cloud Run API, dan data QoE real-time, bukan sekadar tampilan statis.
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

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
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
                    <Icon className={\`h-5 w-5 \${item.color}\`} />
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
        <p className="text-sm font-bold text-white">Command bukti cepat untuk dosen:</p>
        <pre className="mt-3 overflow-x-auto rounded-xl bg-black/40 p-4 text-xs text-cyan-200">
{`curl -s ${API_URL}/api/qos/metrics
curl -s ${API_URL}/api/qos/history | head -c 800
curl -s ${API_URL}/api/qoe/latest | head -c 800`}
        </pre>
      </div>
    </section>
  );
}
TSX

python3 <<'PY'
from pathlib import Path
import re

p = Path("app/database/page.tsx")

if not p.exists():
    raise SystemExit("❌ app/database/page.tsx tidak ditemukan")

s = p.read_text()

import_line = 'import { GcpDatabaseProofButtons } from "@/components/gcp-database-proof-buttons";'

if import_line not in s:
    if '"use client";' in s:
        s = s.replace('"use client";', '"use client";\n\n' + import_line, 1)
    else:
        lines = s.splitlines()
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith("import "):
                insert_at = i + 1
        lines.insert(insert_at, import_line)
        s = "\n".join(lines)

if "<GcpDatabaseProofButtons />" not in s:
    s, count = re.subn(
        r'(<main[^>]*>)',
        r'\1\n      <GcpDatabaseProofButtons />',
        s,
        count=1,
        flags=re.S
    )

    if count == 0:
        raise SystemExit("❌ Tidak menemukan tag <main>. Patch manual dibutuhkan.")

p.write_text(s)

print("✅ Database proof buttons injected into app/database/page.tsx")
PY

echo "=================================================="
echo "PATCH DONE"
echo "=================================================="
