#!/bin/bash
set -e

echo "=================================================="
echo "PATCH 1 — GLOBAL REAL QOE PROBE ANTI-FREEZE"
echo "=================================================="

cat > components/global-qoe-probe.tsx <<'TSX'
"use client";

import { useEffect, useRef } from "react";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function calculateQoe(latency: number, jitter: number, downloadMbps: number, uploadMbps: number) {
  const latencyPenalty = latency > 80 ? (latency - 80) * 0.18 : 0;
  const jitterPenalty = jitter > 20 ? (jitter - 20) * 0.7 : 0;
  const downloadPenalty = downloadMbps < 8 ? (8 - downloadMbps) * 6 : 0;
  const uploadPenalty = uploadMbps < 2 ? (2 - uploadMbps) * 5 : 0;

  return Math.round(
    clamp(100 - latencyPenalty - jitterPenalty - downloadPenalty - uploadPenalty, 0, 100)
  );
}

function getStatus(score: number) {
  if (score >= 90) return "EXCELLENT";
  if (score >= 75) return "STABLE";
  if (score >= 60) return "BUFFER RISK";
  return "POOR";
}

export function GlobalQoeProbe() {
  const lastLatencyRef = useRef<number | null>(null);
  const runningRef = useRef(false);

  async function measureLatency() {
    const t0 = performance.now();

    await fetch(`${API_URL}/api/qoe/ping?x=${Date.now()}`, {
      cache: "no-store",
    });

    const latency = performance.now() - t0;
    const previous = lastLatencyRef.current;
    const jitter = previous === null ? 0 : Math.abs(latency - previous);
    lastLatencyRef.current = latency;

    return { latency, jitter };
  }

  async function measureDownload() {
    const sizeKb = 512;
    const t0 = performance.now();

    const response = await fetch(
      `${API_URL}/api/qoe/download-fixed?size_kb=${sizeKb}&x=${Date.now()}`,
      { cache: "no-store" }
    );

    const buffer = await response.arrayBuffer();
    const t1 = performance.now();

    const durationS = Math.max((t1 - t0) / 1000, 0.001);
    return (buffer.byteLength * 8) / durationS / 1_000_000;
  }

  async function measureUpload() {
    const size = 128 * 1024;
    const payload = new Uint8Array(size);

    for (let i = 0; i < payload.length; i += 65536) {
      crypto.getRandomValues(payload.subarray(i, Math.min(i + 65536, payload.length)));
    }

    const t0 = performance.now();

    await fetch(`${API_URL}/api/qoe/upload?x=${Date.now()}`, {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      body: payload,
      cache: "no-store",
    });

    const t1 = performance.now();
    const durationS = Math.max((t1 - t0) / 1000, 0.001);

    return (payload.byteLength * 8) / durationS / 1_000_000;
  }

  async function runProbe() {
    if (runningRef.current) return;
    if (document.visibilityState !== "visible") return;

    runningRef.current = true;

    try {
      const latencyResult = await measureLatency();
      const downloadMbps = await measureDownload();
      const uploadMbps = await measureUpload();

      const latency = +latencyResult.latency.toFixed(1);
      const jitter = +latencyResult.jitter.toFixed(1);
      const down = +downloadMbps.toFixed(2);
      const up = +uploadMbps.toFixed(2);
      const qoeScore = calculateQoe(latency, jitter, down, up);
      const status = getStatus(qoeScore);

      const sample = {
        time: new Date().toLocaleTimeString(),
        latency,
        jitter,
        downloadMbps: down,
        uploadMbps: up,
        backendMs: latency,
        qoeScore,
        status,
        source: "global-real-qoe-probe",
      };

      await fetch(`${API_URL}/api/qoe/sample`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(sample),
        cache: "no-store",
      });

      window.dispatchEvent(new CustomEvent("real-qoe-updated", { detail: sample }));
    } catch (error) {
      console.warn("Global QoE probe failed:", error);
    } finally {
      runningRef.current = false;
    }
  }

  useEffect(() => {
    runProbe();

    const interval = setInterval(runProbe, 5000);

    const onVisible = () => {
      if (document.visibilityState === "visible") runProbe();
    };

    window.addEventListener("focus", runProbe);
    document.addEventListener("visibilitychange", onVisible);

    return () => {
      clearInterval(interval);
      window.removeEventListener("focus", runProbe);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, []);

  return null;
}
TSX

python3 <<'PY'
from pathlib import Path

p = Path("app/layout.tsx")
s = p.read_text()

if 'components/global-qoe-probe' not in s:
    lines = s.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, 'import { GlobalQoeProbe } from "@/components/global-qoe-probe";')
    s = "\n".join(lines)

if "<GlobalQoeProbe />" not in s:
    if "</body>" not in s:
        raise SystemExit("❌ </body> tidak ketemu di app/layout.tsx")
    s = s.replace("</body>", "        <GlobalQoeProbe />\n      </body>")

p.write_text(s)
print("✅ GlobalQoeProbe injected into app/layout.tsx")
PY

echo "=================================================="
echo "PATCH 2 — FIND / RESTORE COVERAGE DATASET"
echo "=================================================="

mkdir -p public/data

LOCAL_COVERAGE=$(find . \
  -path "./node_modules" -prune -o \
  -path "./.next" -prune -o \
  -path "./backend/venv" -prune -o \
  -type f \( \
    -iname "510.csv.gz" -o \
    -iname "*opencell*.csv.gz" -o \
    -iname "*opencell*.csv" -o \
    -iname "*cell*.csv.gz" -o \
    -iname "*coverage*.csv.gz" -o \
    -iname "*coverage*.csv" \
  \) -print | head -1)

if [ -n "$LOCAL_COVERAGE" ]; then
  echo "✅ Local coverage dataset found: $LOCAL_COVERAGE"
  cp "$LOCAL_COVERAGE" public/data/510.csv.gz 2>/dev/null || cp "$LOCAL_COVERAGE" public/data/coverage.csv
else
  echo "⚠️ Local coverage dataset not found. Searching Cloud Storage buckets..."
  MATCH=$(
    for b in $(gcloud storage buckets list --format="value(name)" 2>/dev/null); do
      gcloud storage ls -r "gs://$b/**" 2>/dev/null | grep -Ei "510\.csv\.gz|opencell.*\.csv|cell.*\.csv\.gz|coverage.*\.csv" | head -1
    done | head -1
  )

  if [ -n "$MATCH" ]; then
    echo "✅ Cloud Storage coverage dataset found: $MATCH"
    gcloud storage cp "$MATCH" public/data/510.csv.gz
  else
    echo "⚠️ No coverage dataset found in local files or Cloud Storage."
    echo "Coverage route will stay honest and report dataset_not_loaded until dataset is provided."
  fi
fi

echo "=================================================="
echo "PATCH 3 — ROBUST COVERAGE API ROUTE"
echo "=================================================="

mkdir -p app/api/coverage-live

cat > app/api/coverage-live/route.ts <<'TS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

import fs from "fs";
import path from "path";
import zlib from "zlib";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

type Tower = {
  radio: string;
  mcc: number;
  mnc: number;
  provider: string;
  lac: number;
  cellid: number;
  lon: number;
  lat: number;
  range: number;
  samples: number;
  average_signal: number;
};

const PROVIDERS: Record<number, string> = {
  1: "Indosat Ooredoo Hutchison",
  10: "Telkomsel",
  11: "XL Axiata",
  21: "Indosat Ooredoo Hutchison",
  89: "Tri Indonesia",
  99: "Esia / Legacy",
};

function splitCsvLine(line: string) {
  const result: string[] = [];
  let current = "";
  let inQuotes = false;

  for (const char of line) {
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      result.push(current);
      current = "";
    } else {
      current += char;
    }
  }

  result.push(current);
  return result.map((item) => item.trim().replace(/^"|"$/g, ""));
}

function toNumber(value: unknown, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function parseOpenCellCsv(text: string) {
  const lines = text.split(/\r?\n/).filter(Boolean);
  if (!lines.length) return [];

  const first = splitCsvLine(lines[0]).map((v) => v.toLowerCase());
  const hasHeader = first.includes("radio") || first.includes("mcc") || first.includes("lon");

  const start = hasHeader ? 1 : 0;
  const idx = (name: string, fallback: number) => {
    if (!hasHeader) return fallback;
    const i = first.indexOf(name);
    return i >= 0 ? i : fallback;
  };

  const radioIdx = idx("radio", 0);
  const mccIdx = idx("mcc", 1);
  const mncIdx = idx("net", 2);
  const areaIdx = idx("area", 3);
  const cellIdx = idx("cell", 4);
  const lonIdx = idx("lon", 6);
  const latIdx = idx("lat", 7);
  const rangeIdx = idx("range", 8);
  const samplesIdx = idx("samples", 9);
  const signalIdx = idx("averageSignal".toLowerCase(), 13);

  const towers: Tower[] = [];

  for (let i = start; i < lines.length && towers.length < 8000; i++) {
    const cols = splitCsvLine(lines[i]);
    if (cols.length < 8) continue;

    const mcc = toNumber(cols[mccIdx]);
    const mnc = toNumber(cols[mncIdx]);
    const lon = toNumber(cols[lonIdx]);
    const lat = toNumber(cols[latIdx]);

    if (mcc !== 510) continue;
    if (lon < 94 || lon > 142 || lat < -12 || lat > 8) continue;

    towers.push({
      radio: cols[radioIdx] || "LTE",
      mcc,
      mnc,
      provider: PROVIDERS[mnc] || "Other / Unknown",
      lac: toNumber(cols[areaIdx]),
      cellid: toNumber(cols[cellIdx]),
      lon,
      lat,
      range: toNumber(cols[rangeIdx], 1000),
      samples: toNumber(cols[samplesIdx], 1),
      average_signal: toNumber(cols[signalIdx], -90),
    });
  }

  return towers;
}

function readLocalCoverage() {
  const candidates = [
    path.join(process.cwd(), "public", "data", "510.csv.gz"),
    path.join(process.cwd(), "public", "data", "coverage.csv.gz"),
    path.join(process.cwd(), "public", "data", "coverage.csv"),
    path.join(process.cwd(), "public", "510.csv.gz"),
    path.join(process.cwd(), "510.csv.gz"),
  ];

  for (const file of candidates) {
    if (!fs.existsSync(file)) continue;

    const buffer = fs.readFileSync(file);
    const text = file.endsWith(".gz")
      ? zlib.gunzipSync(buffer).toString("utf-8")
      : buffer.toString("utf-8");

    const towers = parseOpenCellCsv(text);

    return {
      found: true,
      file,
      towers,
    };
  }

  return {
    found: false,
    file: null,
    towers: [] as Tower[],
  };
}

export async function GET() {
  try {
    const backendResponse = await fetch(`${API_URL}/api/coverage?x=${Date.now()}`, {
      cache: "no-store",
    });

    if (backendResponse.ok) {
      const backendData = await backendResponse.json();
      const backendTowers = Array.isArray(backendData?.towers) ? backendData.towers : [];
      const backendCount = Number(backendData?.count ?? backendTowers.length ?? 0);

      if (backendCount > 0 || backendTowers.length > 0) {
        return Response.json({
          ...backendData,
          count: backendCount || backendTowers.length,
          source: backendData.source || "backend-coverage-api",
          dataset_status: "loaded_from_backend",
        });
      }
    }
  } catch {
    // fallback to local dataset
  }

  const local = readLocalCoverage();

  if (local.found && local.towers.length > 0) {
    const providers = Array.from(new Set(local.towers.map((tower) => tower.provider)));

    return Response.json({
      count: local.towers.length,
      towers: local.towers,
      providers,
      source: "local-opencellid-dataset",
      dataset_status: "loaded_from_local_file",
      dataset_file: local.file,
    });
  }

  return Response.json({
    count: 0,
    towers: [],
    providers: [],
    source: "coverage-dataset-not-loaded",
    dataset_status: "dataset_not_loaded",
    message:
      "No OpenCellID/coverage CSV dataset was found. Upload 510.csv.gz or coverage.csv to public/data/ to enable real BTS coverage.",
  });
}
TS

echo "=================================================="
echo "PATCH 4 — COVERAGE PAGE HONEST DATA DISPLAY"
echo "=================================================="

cat > app/coverage/page.tsx <<'TSX'
"use client";

import dynamic from "next/dynamic";

const CoverageMapClient = dynamic(
  () => import("@/components/coverage-map-client").then((mod) => mod.CoverageMapClient),
  { ssr: false }
);

export default function CoveragePage() {
  return <CoverageMapClient />;
}
TSX

cat > components/coverage-map-client.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";
import { MapContainer, Marker, Popup, TileLayer, CircleMarker } from "react-leaflet";
import "leaflet/dist/leaflet.css";

type Tower = {
  radio: string;
  mcc: number;
  mnc: number;
  provider: string;
  lac: number;
  cellid: number;
  lon: number;
  lat: number;
  range: number;
  samples: number;
  average_signal: number;
};

type CoverageResponse = {
  count: number;
  towers: Tower[];
  providers: string[];
  source?: string;
  dataset_status?: string;
  message?: string;
};

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-slate-700 bg-slate-900/80 p-3">
      <p className="text-xs text-slate-400">{label}</p>
      <p className="mt-1 text-2xl font-black text-white">{value}</p>
    </div>
  );
}

export function CoverageMapClient() {
  const [data, setData] = useState<CoverageResponse>({
    count: 0,
    towers: [],
    providers: [],
  });
  const [loading, setLoading] = useState(true);

  const fetchCoverage = async () => {
    try {
      const res = await fetch(`/api/coverage-live?x=${Date.now()}`, {
        cache: "no-store",
      });

      const json = await res.json();
      setData({
        count: Number(json.count ?? json.towers?.length ?? 0),
        towers: Array.isArray(json.towers) ? json.towers : [],
        providers: Array.isArray(json.providers) ? json.providers : [],
        source: json.source,
        dataset_status: json.dataset_status,
        message: json.message,
      });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCoverage();
    const interval = setInterval(fetchCoverage, 15000);
    return () => clearInterval(interval);
  }, []);

  const stats = useMemo(() => {
    const towers = data.towers || [];

    return {
      total: data.count || towers.length,
      providers: new Set(towers.map((tower) => tower.provider)).size,
      lte: towers.filter((tower) => tower.radio?.toUpperCase() === "LTE").length,
      gsm: towers.filter((tower) => tower.radio?.toUpperCase() === "GSM").length,
      nr: towers.filter((tower) => tower.radio?.toUpperCase().includes("NR")).length,
      umts: towers.filter((tower) => tower.radio?.toUpperCase() === "UMTS").length,
    };
  }, [data]);

  const center: [number, number] = [-2.5, 118.0];

  return (
    <main className="space-y-6 p-6 text-white">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-3xl font-black">Cellular Coverage Intelligence</h1>
          <p className="mt-2 text-slate-400">
            Real BTS infrastructure and provider coverage map powered by backend coverage API or OpenCellID CSV dataset.
          </p>
        </div>

        <button
          onClick={fetchCoverage}
          className="rounded-xl border border-emerald-500/30 px-5 py-3 text-sm font-bold text-emerald-300 hover:bg-emerald-500/10"
        >
          Refresh Coverage
        </button>
      </div>

      {loading ? (
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-10 text-center text-slate-400">
          Loading coverage dataset...
        </div>
      ) : null}

      {!loading && stats.total === 0 ? (
        <div className="rounded-3xl border border-yellow-500/30 bg-yellow-500/10 p-6">
          <h2 className="text-xl font-black text-yellow-300">Coverage Dataset Not Loaded</h2>
          <p className="mt-2 text-sm text-slate-300">
            {data.message ||
              "No BTS dataset was found. Upload 510.csv.gz or coverage.csv to public/data/ to enable real coverage visualization."}
          </p>
          <p className="mt-2 text-xs text-slate-500">Source: {data.source || "unknown"}</p>
        </div>
      ) : null}

      <section className="relative overflow-hidden rounded-3xl border border-slate-800 bg-slate-900/70">
        <div className="absolute left-5 top-5 z-[1000] w-[330px] rounded-2xl border border-slate-700 bg-slate-950/90 p-5 shadow-2xl backdrop-blur-xl">
          <div className="mb-4 flex items-start justify-between">
            <div>
              <h2 className="font-black">Dynamic Coverage Intelligence</h2>
              <p className="text-xs text-slate-400">Viewport-based BTS loading</p>
            </div>
            <span className="rounded-full bg-emerald-500/10 px-3 py-1 text-xs font-bold text-emerald-300">
              Live
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <Stat label="Visible BTS" value={stats.total} />
            <Stat label="Providers" value={stats.providers} />
            <Stat label="LTE" value={stats.lte} />
            <Stat label="GSM" value={stats.gsm} />
            <Stat label="NR/5G" value={stats.nr} />
            <Stat label="UMTS" value={stats.umts} />
          </div>

          <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/70 p-3">
            <p className="text-xs font-bold text-slate-300">Dataset Source</p>
            <p className="mt-1 break-words text-xs text-cyan-300">{data.source || "unknown"}</p>
            <p className="mt-1 text-xs text-slate-500">{data.dataset_status || "-"}</p>
          </div>
        </div>

        <div className="h-[680px]">
          <MapContainer center={center} zoom={5} scrollWheelZoom className="h-full w-full">
            <TileLayer
              attribution='&copy; OpenStreetMap contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />

            {data.towers.slice(0, 3000).map((tower, index) => (
              <CircleMarker
                key={`${tower.mcc}-${tower.mnc}-${tower.cellid}-${index}`}
                center={[tower.lat, tower.lon]}
                radius={5}
                pathOptions={{
                  color:
                    tower.provider.includes("Telkomsel")
                      ? "#ef4444"
                      : tower.provider.includes("XL")
                      ? "#3b82f6"
                      : tower.provider.includes("Indosat")
                      ? "#facc15"
                      : tower.provider.includes("Tri")
                      ? "#a855f7"
                      : "#22c55e",
                  fillOpacity: 0.75,
                  weight: 2,
                }}
              >
                <Popup>
                  <div>
                    <b>{tower.provider}</b>
                    <br />
                    Radio: {tower.radio}
                    <br />
                    MCC/MNC: {tower.mcc}/{tower.mnc}
                    <br />
                    Cell ID: {tower.cellid}
                    <br />
                    Samples: {tower.samples}
                    <br />
                    Avg Signal: {tower.average_signal}
                  </div>
                </Popup>
              </CircleMarker>
            ))}
          </MapContainer>
        </div>
      </section>
    </main>
  );
}
TSX

echo "=================================================="
echo "PATCH 5 — KEEP API SINGLE INSTANCE FOR IN-MEMORY QOE"
echo "=================================================="

gcloud run services update qos-api \
  --region=asia-southeast2 \
  --min-instances=1 \
  --max-instances=1 \
  --memory=1Gi \
  --cpu=1 || true

echo "=================================================="
echo "PATCH FINISHED"
echo "=================================================="
