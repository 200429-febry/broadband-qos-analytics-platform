#!/bin/bash
set -e

echo "=================================================="
echo "RESTORE OLD UI + KEEP REAL QOE DATA"
echo "=================================================="

if [ ! -d ".backup-real-qoe-all" ]; then
  echo "❌ Folder .backup-real-qoe-all tidak ketemu."
  echo "Backup lama tidak tersedia. Jangan lanjut dulu."
  exit 1
fi

restore_file() {
  target="$1"
  backup=".backup-real-qoe-all/$(echo "$target" | tr '/' '_').bak"

  if [ -f "$backup" ]; then
    cp "$backup" "$target"
    echo "✅ Restored old UI: $target"
  else
    echo "⚠️ Backup not found, skipped: $target"
  fi
}

echo "=== Restore old page UI from backup ==="

restore_file "app/page.tsx"
restore_file "app/monitoring/page.tsx"
restore_file "app/analytics/page.tsx"
restore_file "app/alerts/page.tsx"
restore_file "app/incidents/page.tsx"
restore_file "app/reports/page.tsx"
restore_file "app/predictions/page.tsx"
restore_file "app/stream/page.tsx"
restore_file "app/observability/page.tsx"
restore_file "app/database/page.tsx"
restore_file "components/header.tsx"

echo "=== Keep same-origin proxy API routes ==="

mkdir -p app/api/qos-metrics
mkdir -p app/api/qos-history
mkdir -p app/api/qos-alerts
mkdir -p app/api/qoe-latest
mkdir -p app/api/health-live
mkdir -p app/api/database-live
mkdir -p app/api/ml-predict
mkdir -p app/api/coverage-live

cat > app/api/qos-metrics/route.ts <<'TS'
export const dynamic = "force-dynamic";
export const revalidate = 0;

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET() {
  const response = await fetch(`${API_URL}/api/qos/metrics?x=${Date.now()}`, {
    cache: "no-store",
  });

  const data = await response.text();

  return new Response(data, {
    status: response.status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
TS

cat > app/api/qos-history/route.ts <<'TS'
export const dynamic = "force-dynamic";
export const revalidate = 0;

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET() {
  const response = await fetch(`${API_URL}/api/qos/history?x=${Date.now()}`, {
    cache: "no-store",
  });

  const data = await response.text();

  return new Response(data, {
    status: response.status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
TS

cat > app/api/qos-alerts/route.ts <<'TS'
export const dynamic = "force-dynamic";
export const revalidate = 0;

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET() {
  const response = await fetch(`${API_URL}/api/alerts?x=${Date.now()}`, {
    cache: "no-store",
  });

  const data = await response.text();

  return new Response(data, {
    status: response.status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
TS

cat > app/api/qoe-latest/route.ts <<'TS'
export const dynamic = "force-dynamic";
export const revalidate = 0;

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET() {
  const response = await fetch(`${API_URL}/api/qoe/latest?x=${Date.now()}`, {
    cache: "no-store",
  });

  const data = await response.text();

  return new Response(data, {
    status: response.status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
TS

cat > app/api/health-live/route.ts <<'TS'
export const dynamic = "force-dynamic";
export const revalidate = 0;

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET() {
  const response = await fetch(`${API_URL}/api/health?x=${Date.now()}`, {
    cache: "no-store",
  });

  const data = await response.text();

  return new Response(data, {
    status: response.status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
TS

cat > app/api/database-live/route.ts <<'TS'
export const dynamic = "force-dynamic";
export const revalidate = 0;

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET() {
  const response = await fetch(`${API_URL}/api/admin/database/status?x=${Date.now()}`, {
    cache: "no-store",
  });

  const data = await response.text();

  return new Response(data, {
    status: response.status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
TS

cat > app/api/ml-predict/route.ts <<'TS'
export const dynamic = "force-dynamic";
export const revalidate = 0;

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function POST(request: Request) {
  const body = await request.text();

  const response = await fetch(`${API_URL}/api/ml/predict?x=${Date.now()}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
    cache: "no-store",
  });

  const data = await response.text();

  return new Response(data, {
    status: response.status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
TS

echo "=== Re-inject Global QoE Probe anti-freeze ==="

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
    s = s.replace("</body>", "        <GlobalQoeProbe />\n      </body>")

p.write_text(s)
print("✅ GlobalQoeProbe active in app/layout.tsx")
PY

echo "=== Restore richer Coverage Map UI ==="

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
import {
  CircleMarker,
  MapContainer,
  Popup,
  TileLayer,
  useMap,
} from "react-leaflet";
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

const providerColors: Record<string, string> = {
  Telkomsel: "#ef4444",
  "XL Axiata": "#3b82f6",
  "Indosat Ooredoo Hutchison": "#facc15",
  Smartfren: "#ec4899",
  "Tri Indonesia": "#a855f7",
  "Other / Unknown": "#22c55e",
};

function getColor(provider: string) {
  if (provider.includes("Telkomsel")) return providerColors.Telkomsel;
  if (provider.includes("XL")) return providerColors["XL Axiata"];
  if (provider.includes("Indosat")) return providerColors["Indosat Ooredoo Hutchison"];
  if (provider.includes("Smartfren")) return providerColors.Smartfren;
  if (provider.includes("Tri")) return providerColors["Tri Indonesia"];
  return providerColors["Other / Unknown"];
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-slate-700 bg-slate-900/80 p-3">
      <p className="text-xs text-slate-400">{label}</p>
      <p className="mt-1 text-2xl font-black text-white">{value}</p>
    </div>
  );
}

function FlyToLocation({ position }: { position: [number, number] | null }) {
  const map = useMap();

  useEffect(() => {
    if (position) {
      map.flyTo(position, 11, { duration: 1.2 });
    }
  }, [position, map]);

  return null;
}

export function CoverageMapClient() {
  const [data, setData] = useState<CoverageResponse>({
    count: 0,
    towers: [],
    providers: [],
  });

  const [providerFilter, setProviderFilter] = useState("ALL");
  const [radioFilter, setRadioFilter] = useState("ALL");
  const [showRadius, setShowRadius] = useState(false);
  const [limit, setLimit] = useState(3000);
  const [userLocation, setUserLocation] = useState<[number, number] | null>(null);
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

  const filteredTowers = useMemo(() => {
    return (data.towers || [])
      .filter((tower) => providerFilter === "ALL" || tower.provider === providerFilter)
      .filter((tower) => radioFilter === "ALL" || tower.radio?.toUpperCase() === radioFilter)
      .slice(0, limit);
  }, [data.towers, providerFilter, radioFilter, limit]);

  const stats = useMemo(() => {
    const towers = filteredTowers;

    return {
      total: towers.length,
      providers: new Set(towers.map((tower) => tower.provider)).size,
      lte: towers.filter((tower) => tower.radio?.toUpperCase() === "LTE").length,
      gsm: towers.filter((tower) => tower.radio?.toUpperCase() === "GSM").length,
      nr: towers.filter((tower) => tower.radio?.toUpperCase().includes("NR")).length,
      umts: towers.filter((tower) => tower.radio?.toUpperCase() === "UMTS").length,
    };
  }, [filteredTowers]);

  const providers = useMemo(() => {
    return Array.from(new Set((data.towers || []).map((tower) => tower.provider))).sort();
  }, [data.towers]);

  const radios = useMemo(() => {
    return Array.from(
      new Set((data.towers || []).map((tower) => tower.radio?.toUpperCase()).filter(Boolean))
    ).sort();
  }, [data.towers]);

  const locateMe = () => {
    if (!navigator.geolocation) return;

    navigator.geolocation.getCurrentPosition((pos) => {
      setUserLocation([pos.coords.latitude, pos.coords.longitude]);
    });
  };

  const center: [number, number] = [-2.5, 118.0];

  return (
    <main className="space-y-6 p-6 text-white">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">Cellular Coverage Intelligence</h1>
          <p className="mt-2 text-slate-400">
            Real BTS infrastructure, provider distribution, radio layer, and coverage intelligence powered by OpenCellID dataset.
          </p>
        </div>

        <div className="flex flex-wrap gap-3">
          <button
            onClick={locateMe}
            className="rounded-xl border border-cyan-500/30 px-5 py-3 text-sm font-bold text-cyan-300 hover:bg-cyan-500/10"
          >
            Locate Me via GPS
          </button>

          <button
            onClick={fetchCoverage}
            className="rounded-xl border border-emerald-500/30 px-5 py-3 text-sm font-bold text-emerald-300 hover:bg-emerald-500/10"
          >
            Refresh Coverage
          </button>
        </div>
      </div>

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
        <div className="absolute left-5 top-5 z-[1000] w-[360px] rounded-2xl border border-slate-700 bg-slate-950/90 p-5 shadow-2xl backdrop-blur-xl">
          <div className="mb-4 flex items-start justify-between">
            <div>
              <h2 className="font-black">Dynamic Coverage Intelligence</h2>
              <p className="text-xs text-slate-400">Viewport-based OpenCellID BTS loading</p>
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

          <div className="mt-4 grid grid-cols-2 gap-3">
            <select
              value={providerFilter}
              onChange={(e) => setProviderFilter(e.target.value)}
              className="rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-xs text-white"
            >
              <option value="ALL">All Providers</option>
              {providers.map((provider) => (
                <option key={provider} value={provider}>
                  {provider}
                </option>
              ))}
            </select>

            <select
              value={radioFilter}
              onChange={(e) => setRadioFilter(e.target.value)}
              className="rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-xs text-white"
            >
              <option value="ALL">All Radio</option>
              {radios.map((radio) => (
                <option key={radio} value={radio}>
                  {radio}
                </option>
              ))}
            </select>

            <select
              value={limit}
              onChange={(e) => setLimit(Number(e.target.value))}
              className="rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-xs text-white"
            >
              <option value={1000}>1000 BTS</option>
              <option value={3000}>3000 BTS</option>
              <option value={5000}>5000 BTS</option>
              <option value={8000}>8000 BTS</option>
            </select>

            <button
              onClick={() => setShowRadius((prev) => !prev)}
              className="rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-xs font-bold text-cyan-300"
            >
              {showRadius ? "Hide Radius" : "Show Radius"}
            </button>
          </div>

          <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/70 p-3">
            <p className="mb-2 text-xs font-bold text-slate-300">Provider Legend</p>

            <div className="grid grid-cols-2 gap-2 text-xs text-slate-300">
              {Object.entries(providerColors).map(([provider, color]) => (
                <div key={provider} className="flex items-center gap-2">
                  <span className="h-3 w-3 rounded-full" style={{ backgroundColor: color }} />
                  <span>{provider}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/70 p-3">
            <p className="text-xs font-bold text-slate-300">Dataset Source</p>
            <p className="mt-1 break-words text-xs text-cyan-300">{data.source || "unknown"}</p>
            <p className="mt-1 text-xs text-slate-500">{data.dataset_status || "-"}</p>
          </div>
        </div>

        <div className="h-[720px]">
          <MapContainer center={center} zoom={5} scrollWheelZoom className="h-full w-full">
            <FlyToLocation position={userLocation} />

            <TileLayer
              attribution='&copy; OpenStreetMap contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />

            {userLocation ? (
              <CircleMarker
                center={userLocation}
                radius={10}
                pathOptions={{
                  color: "#00e5ff",
                  fillColor: "#00e5ff",
                  fillOpacity: 0.7,
                  weight: 3,
                }}
              >
                <Popup>Your current GPS position</Popup>
              </CircleMarker>
            ) : null}

            {filteredTowers.map((tower, index) => {
              const color = getColor(tower.provider);
              const radius = showRadius
                ? Math.max(5, Math.min(18, tower.range / 800))
                : 5;

              return (
                <CircleMarker
                  key={`${tower.mcc}-${tower.mnc}-${tower.cellid}-${index}`}
                  center={[tower.lat, tower.lon]}
                  radius={radius}
                  pathOptions={{
                    color,
                    fillColor: color,
                    fillOpacity: 0.7,
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
                      LAC: {tower.lac}
                      <br />
                      Cell ID: {tower.cellid}
                      <br />
                      Range: {tower.range} m
                      <br />
                      Samples: {tower.samples}
                      <br />
                      Avg Signal: {tower.average_signal}
                    </div>
                  </Popup>
                </CircleMarker>
              );
            })}
          </MapContainer>
        </div>
      </section>
    </main>
  );
}
TSX

echo "=== Keep qos-api single instance for in-memory real QoE continuity ==="

gcloud run services update qos-api \
  --region=asia-southeast2 \
  --min-instances=1 \
  --max-instances=1 \
  --memory=1Gi \
  --cpu=1 || true

echo "=================================================="
echo "DONE: old UI restored, real QoE source preserved"
echo "=================================================="
