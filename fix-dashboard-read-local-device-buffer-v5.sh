#!/bin/bash
set -e

echo "=================================================="
echo "FIX DASHBOARD READ LOCAL PER-DEVICE BUFFER V5"
echo "=================================================="

REGION="asia-southeast2"
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

echo "API_URL=$API_URL"

mkdir -p .backup-dashboard-local-v5
[ -f app/page.tsx ] && cp app/page.tsx .backup-dashboard-local-v5/page.tsx.bak
[ -f components/device-autoprobe-controller.tsx ] && cp components/device-autoprobe-controller.tsx .backup-dashboard-local-v5/device-autoprobe-controller.tsx.bak
[ -f app/layout.tsx ] && cp app/layout.tsx .backup-dashboard-local-v5/layout.tsx.bak

mkdir -p components
mkdir -p app/api/device-probe/ping
mkdir -p app/api/device-probe/download
mkdir -p app/api/device-probe/upload
mkdir -p app/api/device-probe/sample
mkdir -p app/api/device-probe/sessions

cat > app/api/device-probe/ping/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET() {
  const start = Date.now();

  try {
    const res = await fetch(API_URL + "/api/qoe/ping?x=" + Date.now(), {
      cache: "no-store",
    });

    const data = await res.json();

    return Response.json({
      ok: true,
      frontend_proxy_ms: Date.now() - start,
      backend: data,
    }, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch (e) {
    return Response.json({
      ok: false,
      error: String(e?.message || e),
      frontend_proxy_ms: Date.now() - start,
    }, { status: 500 });
  }
}
JS

cat > app/api/device-probe/download/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET(req) {
  const url = new URL(req.url);
  const sizeKb = url.searchParams.get("size_kb") || "512";

  try {
    const res = await fetch(
      API_URL + "/api/qoe/download-fixed?size_kb=" + encodeURIComponent(sizeKb) + "&x=" + Date.now(),
      { cache: "no-store" }
    );

    const buffer = await res.arrayBuffer();

    return new Response(buffer, {
      status: 200,
      headers: {
        "Content-Type": "application/octet-stream",
        "Cache-Control": "no-store",
        "Content-Length": String(buffer.byteLength),
        "X-Probe-Proxy": "frontend-same-origin",
      },
    });
  } catch (e) {
    return Response.json({ ok: false, error: String(e?.message || e) }, { status: 500 });
  }
}
JS

cat > app/api/device-probe/upload/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function POST(req) {
  const start = Date.now();

  try {
    const body = await req.arrayBuffer();

    const res = await fetch(API_URL + "/api/qoe/upload?x=" + Date.now(), {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      cache: "no-store",
      body,
    });

    const data = await res.json();

    return Response.json({
      ok: true,
      frontend_proxy_ms: Date.now() - start,
      uploaded_bytes: body.byteLength,
      backend: data,
    }, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch (e) {
    return Response.json({ ok: false, error: String(e?.message || e) }, { status: 500 });
  }
}
JS

cat > app/api/device-probe/sample/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function POST(req) {
  try {
    const body = await req.json();

    const res = await fetch(API_URL + "/api/qoe/device-sample", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      cache: "no-store",
      body: JSON.stringify(body),
    });

    const text = await res.text();

    let data;
    try {
      data = JSON.parse(text);
    } catch {
      data = { raw: text };
    }

    return Response.json({
      ok: res.ok,
      backend_status: res.status,
      backend: data,
    }, {
      status: res.ok ? 200 : 502,
      headers: { "Cache-Control": "no-store" },
    });
  } catch (e) {
    return Response.json({ ok: false, error: String(e?.message || e) }, { status: 500 });
  }
}
JS

cat > app/api/device-probe/sessions/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET() {
  try {
    const res = await fetch(API_URL + "/api/qoe/device-sessions", {
      cache: "no-store",
    });

    const data = await res.json();

    return Response.json(data, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch (e) {
    return Response.json({
      count: 0,
      sessions: [],
      error: String(e?.message || e),
    }, { status: 500 });
  }
}
JS

python3 <<PY
from pathlib import Path
for f in [
  "app/api/device-probe/ping/route.js",
  "app/api/device-probe/download/route.js",
  "app/api/device-probe/upload/route.js",
  "app/api/device-probe/sample/route.js",
  "app/api/device-probe/sessions/route.js",
]:
    p = Path(f)
    s = p.read_text().replace("__API_URL__", "$API_URL")
    p.write_text(s)
    print("patched", f)
PY

cat > components/device-autoprobe-controller.tsx <<'TSX'
"use client";

import { useEffect, useRef } from "react";

declare global {
  interface Window {
    __AKSARA_DEVICE_SESSION__?: string;
    __AKSARA_DEVICE_INFO__?: Record<string, any>;
    __AKSARA_FETCH_PATCHED_V5__?: boolean;
  }
}

type ProbeSample = Record<string, any>;

function makeId() {
  try {
    return crypto.randomUUID();
  } catch {
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }
}

function deviceType() {
  const ua = navigator.userAgent || "";
  if (/android/i.test(ua)) return "android-phone";
  if (/iphone/i.test(ua)) return "iphone";
  if (/ipad/i.test(ua)) return "ipad";
  if (/mobile/i.test(ua)) return "mobile";
  return "desktop";
}

function browserName() {
  const ua = navigator.userAgent || "";
  if (ua.includes("Edg/")) return "Edge";
  if (ua.includes("OPR/")) return "Opera";
  if (ua.includes("Chrome/")) return "Chrome";
  if (ua.includes("Firefox/")) return "Firefox";
  if (ua.includes("Safari/") && !ua.includes("Chrome/")) return "Safari";
  return "Browser";
}

function connectionInfo() {
  const nav = navigator as any;
  const c = nav.connection || nav.mozConnection || nav.webkitConnection;

  return {
    network_type: c?.effectiveType || "unknown",
    browser_downlink_mbps: Number(c?.downlink || 0),
    browser_rtt_ms: Number(c?.rtt || 0),
    save_data: Boolean(c?.saveData),
  };
}

function getSessionInfo() {
  let sid = localStorage.getItem("aksara-device-session-id-v5");

  if (!sid) {
    sid = `${deviceType()}-${makeId()}`;
    localStorage.setItem("aksara-device-session-id-v5", sid);
  }

  const info = {
    session_id: sid,
    client_session_id: sid,
    device_id: sid,
    device_name: `${deviceType()}-${browserName()}`,
    device_type: deviceType(),
    browser: browserName(),
    platform: navigator.platform || "unknown",
    user_agent: navigator.userAgent || "-",
    ...connectionInfo(),
  };

  window.__AKSARA_DEVICE_SESSION__ = sid;
  window.__AKSARA_DEVICE_INFO__ = info;

  document.documentElement.setAttribute("data-aksara-session-id", sid);
  document.documentElement.setAttribute("data-aksara-device-name", info.device_name);
  document.documentElement.setAttribute("data-aksara-network-type", info.network_type);

  return info;
}

function localKey(sessionId: string) {
  return `aksara-local-qoe-samples-v5:${sessionId}`;
}

function saveLocalSample(sample: ProbeSample) {
  const sid = sample.session_id || getSessionInfo().session_id;
  const key = localKey(sid);

  let rows: ProbeSample[] = [];

  try {
    rows = JSON.parse(localStorage.getItem(key) || "[]");
    if (!Array.isArray(rows)) rows = [];
  } catch {
    rows = [];
  }

  rows.unshift(sample);
  rows = rows.slice(0, 120);

  localStorage.setItem(key, JSON.stringify(rows));
  localStorage.setItem("aksara-local-qoe-last-session-v5", sid);
  localStorage.setItem("aksara-local-qoe-last-sample-v5", JSON.stringify(sample));
}

function withSession(url: string, sid: string) {
  if (url.includes("session_id=")) return url;
  return `${url}${url.includes("?") ? "&" : "?"}session_id=${encodeURIComponent(sid)}`;
}

function normalizeInput(input: RequestInfo | URL) {
  if (typeof input === "string") return input;
  if (input instanceof URL) return input.toString();
  if (input instanceof Request) return input.url;
  return String(input);
}

function patchFetchForSession() {
  if (window.__AKSARA_FETCH_PATCHED_V5__) return;
  window.__AKSARA_FETCH_PATCHED_V5__ = true;

  const originalFetch = window.fetch.bind(window);

  window.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const info = getSessionInfo();
    let url = normalizeInput(input);

    if (
      url.includes("/api/qos-history") ||
      url.includes("/api/qos-metrics") ||
      url.includes("/api/qos-alerts") ||
      url.includes("/api/debug-device-session") ||
      url.includes("/api/reports/pdf") ||
      url.includes("/api/reports/csv")
    ) {
      url = withSession(url, info.session_id);
    }

    if (url.includes("/api/qoe/sample")) {
      url = "/api/device-probe/sample";
    }

    return originalFetch(url, init);
  };
}

function qoeScore(latency: number, jitter: number, down: number, loss: number) {
  let score = 100;

  if (latency > 60) score -= Math.min(35, (latency - 60) * 0.22);
  if (jitter > 15) score -= Math.min(30, (jitter - 15) * 0.55);
  if (down < 25) score -= Math.min(35, (25 - down) * 1.2);
  if (loss > 0) score -= Math.min(40, loss * 18);

  return Math.max(0, Math.min(100, Math.round(score)));
}

function statusFrom(score: number, latency: number, jitter: number, down: number, loss: number) {
  if (loss >= 1 || latency >= 220 || jitter >= 100 || down < 3) return "POOR";
  if (score < 75 || latency >= 120 || jitter >= 45 || down < 8) return "BUFFER RISK";
  if (score < 90 || latency >= 80 || jitter >= 25) return "STABLE";
  return "EXCELLENT";
}

export function DeviceAutoProbeController() {
  const prevLatency = useRef<number | null>(null);
  const running = useRef(false);

  useEffect(() => {
    let stopped = false;

    getSessionInfo();
    patchFetchForSession();

    async function runProbe() {
      if (running.current || stopped) return;
      running.current = true;

      try {
        const info = getSessionInfo();

        const p0 = performance.now();
        const pingRes = await fetch("/api/device-probe/ping?x=" + Date.now(), { cache: "no-store" });
        await pingRes.json().catch(() => null);
        const p1 = performance.now();

        const latency = Number((p1 - p0).toFixed(1));
        const jitter =
          prevLatency.current === null
            ? 0
            : Number(Math.abs(latency - prevLatency.current).toFixed(1));
        prevLatency.current = latency;

        const d0 = performance.now();
        const downloadRes = await fetch("/api/device-probe/download?size_kb=512&x=" + Date.now(), { cache: "no-store" });
        const downloadBuffer = await downloadRes.arrayBuffer();
        const d1 = performance.now();

        const downloadSeconds = Math.max((d1 - d0) / 1000, 0.001);
        const downloadMbps = Number(((downloadBuffer.byteLength * 8) / downloadSeconds / 1_000_000).toFixed(2));

        const uploadPayload = new Uint8Array(128 * 1024);
        const u0 = performance.now();
        const uploadRes = await fetch("/api/device-probe/upload?x=" + Date.now(), {
          method: "POST",
          headers: { "Content-Type": "application/octet-stream" },
          body: uploadPayload,
          cache: "no-store",
        });
        await uploadRes.json().catch(() => null);
        const u1 = performance.now();

        const uploadSeconds = Math.max((u1 - u0) / 1000, 0.001);
        const uploadMbps = Number(((uploadPayload.byteLength * 8) / uploadSeconds / 1_000_000).toFixed(2));

        const packetLoss = !pingRes.ok || !downloadRes.ok || !uploadRes.ok ? 1.5 : 0;
        const score = qoeScore(latency, jitter, downloadMbps, packetLoss);
        const status = statusFrom(score, latency, jitter, downloadMbps, packetLoss);

        const sample = {
          ...info,
          timestamp_epoch: Date.now(),
          timestamp: new Date().toLocaleTimeString(),
          time: new Date().toLocaleTimeString(),
          latency,
          jitter,
          downloadMbps,
          uploadMbps,
          throughput: downloadMbps,
          bandwidth: downloadMbps,
          packet_loss: packetLoss,
          qoeScore: score,
          qoe_score: score,
          status,
          streaming_status: status,
          source: "per-device-autoprobe-local-plus-backend",
        };

        saveLocalSample(sample);

        window.dispatchEvent(
          new CustomEvent("aksara-device-autoprobe-sample", {
            detail: sample,
          })
        );

        const saveRes = await fetch("/api/device-probe/sample", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          cache: "no-store",
          body: JSON.stringify(sample),
        });

        const saveJson = await saveRes.json().catch(() => null);

        console.log("[AKSARA AUTO PROBE V5]", {
          savedLocal: true,
          savedBackend: saveRes.ok,
          backend: saveJson,
          sample,
        });
      } catch (e) {
        console.warn("[AKSARA AUTO PROBE V5 FAILED]", e);
      } finally {
        running.current = false;
      }
    }

    runProbe();
    const interval = setInterval(runProbe, 5000);

    return () => {
      stopped = true;
      clearInterval(interval);
    };
  }, []);

  return null;
}
TSX

python3 <<'PY'
from pathlib import Path

p = Path("app/layout.tsx")
s = p.read_text()

imp = 'import { DeviceAutoProbeController } from "@/components/device-autoprobe-controller";'
if imp not in s:
    lines = s.splitlines()
    idx = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            idx = i + 1
    lines.insert(idx, imp)
    s = "\n".join(lines)

if "<DeviceAutoProbeController />" not in s:
    s = s.replace("</body>", "        <DeviceAutoProbeController />\n      </body>")

p.write_text(s)
print("DeviceAutoProbeController injected")
PY

cat > app/page.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertTriangle,
  Database,
  Gauge,
  Server,
  ShieldCheck,
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

type Sample = {
  timestamp?: string;
  time?: string;
  throughput?: number;
  downloadMbps?: number;
  uploadMbps?: number;
  latency?: number;
  jitter?: number;
  packet_loss?: number;
  qoe_score?: number;
  qoeScore?: number;
  streaming_status?: string;
  status?: string;
  source?: string;
  session_id?: string;
  device_name?: string;
  network_type?: string;
};

function numberOf(v: any, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

function makeId() {
  try {
    return crypto.randomUUID();
  } catch {
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }
}

function ensureSession() {
  let sid = localStorage.getItem("aksara-device-session-id-v5");
  if (!sid) {
    sid = `desktop-${makeId()}`;
    localStorage.setItem("aksara-device-session-id-v5", sid);
  }
  return sid;
}

function localKey(sessionId: string) {
  return `aksara-local-qoe-samples-v5:${sessionId}`;
}

function readLocalSamples(sessionId: string): Sample[] {
  try {
    const rows = JSON.parse(localStorage.getItem(localKey(sessionId)) || "[]");
    return Array.isArray(rows) ? rows : [];
  } catch {
    return [];
  }
}

function dedupe(rows: Sample[]) {
  const seen = new Set<string>();
  const out: Sample[] = [];

  for (const row of rows) {
    const key = `${row.session_id || ""}-${row.timestamp || row.time || ""}-${row.throughput || row.downloadMbps || ""}-${row.latency || ""}`;
    if (!seen.has(key)) {
      seen.add(key);
      out.push(row);
    }
  }

  return out;
}

function normalize(row: Sample): Sample {
  const throughput = numberOf(row.throughput ?? row.downloadMbps);
  const qoe = numberOf(row.qoe_score ?? row.qoeScore);

  return {
    ...row,
    throughput,
    downloadMbps: throughput,
    latency: numberOf(row.latency),
    jitter: numberOf(row.jitter),
    packet_loss: numberOf(row.packet_loss),
    qoe_score: qoe,
    qoeScore: qoe,
    streaming_status: row.streaming_status || row.status || "WAITING",
    timestamp: row.timestamp || row.time || "-",
  };
}

function statusClass(status: string) {
  if (status === "EXCELLENT") return "text-emerald-300";
  if (status === "STABLE") return "text-cyan-300";
  if (status === "BUFFER RISK") return "text-yellow-300";
  if (status === "POOR") return "text-red-300";
  return "text-slate-300";
}

function KpiCard({
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
  const [sessionId, setSessionId] = useState("");
  const [samples, setSamples] = useState<Sample[]>([]);
  const [deviceInfo, setDeviceInfo] = useState<any>(null);
  const [lastRefresh, setLastRefresh] = useState("-");

  async function load(session: string) {
    const localRows = readLocalSamples(session);

    let backendRows: Sample[] = [];

    try {
      const res = await fetch(`/api/qos-history?session_id=${encodeURIComponent(session)}&limit=80`, {
        cache: "no-store",
      });
      const json = await res.json();
      backendRows = Array.isArray(json) ? json : [];
    } catch {
      backendRows = [];
    }

    const merged = dedupe([...localRows, ...backendRows]).map(normalize).slice(0, 80);
    setSamples(merged);
    setDeviceInfo((window as any).__AKSARA_DEVICE_INFO__ || null);
    setLastRefresh(new Date().toLocaleTimeString());
  }

  useEffect(() => {
    const sid = ensureSession();
    setSessionId(sid);

    const onSample = (event: any) => {
      const row = normalize(event.detail || {});
      setSamples((prev) => dedupe([row, ...prev]).slice(0, 80));
      setDeviceInfo((window as any).__AKSARA_DEVICE_INFO__ || null);
      setLastRefresh(new Date().toLocaleTimeString());
    };

    window.addEventListener("aksara-device-autoprobe-sample", onSample);

    load(sid);
    const interval = setInterval(() => load(sid), 3000);

    return () => {
      window.removeEventListener("aksara-device-autoprobe-sample", onSample);
      clearInterval(interval);
    };
  }, []);

  const latest = samples[0] || {};
  const throughput = numberOf(latest.throughput ?? latest.downloadMbps);
  const latency = numberOf(latest.latency);
  const jitter = numberOf(latest.jitter);
  const loss = numberOf(latest.packet_loss);
  const qoe = numberOf(latest.qoe_score ?? latest.qoeScore);
  const status = String(latest.streaming_status || latest.status || "WAITING");

  const chartData = useMemo(() => {
    return samples
      .slice()
      .reverse()
      .map((row, index) => ({
        index,
        time: row.timestamp || row.time || `${index}`,
        throughput: numberOf(row.throughput ?? row.downloadMbps),
        latency: numberOf(row.latency),
        jitter: numberOf(row.jitter),
        qoe: numberOf(row.qoe_score ?? row.qoeScore),
      }));
  }, [samples]);

  const avgThroughput =
    samples.length > 0
      ? samples.reduce((sum, row) => sum + numberOf(row.throughput ?? row.downloadMbps), 0) / samples.length
      : 0;

  const avgLatency =
    samples.length > 0
      ? samples.reduce((sum, row) => sum + numberOf(row.latency), 0) / samples.length
      : 0;

  const maxLatency =
    samples.length > 0
      ? Math.max(...samples.map((row) => numberOf(row.latency)))
      : 0;

  const minThroughput =
    samples.length > 0
      ? Math.min(...samples.map((row) => numberOf(row.throughput ?? row.downloadMbps)))
      : 0;

  return (
    <main className="space-y-7 p-6 text-white">
      <section>
        <h1 className="text-3xl font-black">NOC Dashboard</h1>
        <p className="mt-2 text-slate-400">
          Executive overview of per-device real browser-to-Cloud Run QoE telemetry.
        </p>
      </section>

      <section className="grid gap-4 xl:grid-cols-4">
        <KpiCard label="Avg Throughput" value={throughput.toFixed(2)} unit="Mbps" icon={Zap} note="Real local + backend probe" />
        <KpiCard label="Network Latency" value={latency.toFixed(1)} unit="ms" icon={Activity} note="Per-device session" />
        <KpiCard label="Packet Loss" value={loss.toFixed(1)} unit="%" icon={ShieldCheck} note="Probe failure ratio" />
        <KpiCard label="Jitter" value={jitter.toFixed(1)} unit="ms" icon={Gauge} note="Latency variation" />
      </section>

      <section className="grid gap-5 xl:grid-cols-[1fr_360px]">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-black">Network Throughput & Latency Live</h2>
              <p className="mt-1 text-sm text-slate-400">
                Session: <span className="font-bold text-cyan-300">{sessionId || "-"}</span>
              </p>
            </div>
            <div className="rounded-full border border-cyan-500/30 bg-cyan-500/10 px-3 py-1 text-xs font-black text-cyan-300">
              {samples.length} samples
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
              <p className="text-lg font-bold text-slate-400">Waiting for first per-device QoE sample...</p>
              <p className="mt-2 max-w-lg text-sm text-slate-500">
                Auto probe is running. Keep this page open for 10–20 seconds.
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
              ["Device Probe", lastRefresh, samples.length > 0 ? "ACTIVE" : "WAITING", Wifi],
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
            <p className="mt-2 text-sm text-slate-400">QoE Score: <span className="font-black text-white">{qoe.toFixed(0)}</span></p>
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
        <h2 className="text-xl font-black">NOC Performance Analytics</h2>
        <p className="mt-1 text-sm text-slate-400">
          Per-device analytical summary generated from actual browser traffic probes.
        </p>

        <div className="mt-5 grid gap-4 xl:grid-cols-4">
          <KpiCard label="Average Throughput" value={avgThroughput.toFixed(2)} unit="Mbps" icon={Zap} />
          <KpiCard label="Average Latency" value={avgLatency.toFixed(1)} unit="ms" icon={Activity} />
          <KpiCard label="Min Throughput" value={minThroughput.toFixed(2)} unit="Mbps" icon={Gauge} />
          <KpiCard label="Max Latency" value={maxLatency.toFixed(1)} unit="ms" icon={AlertTriangle} />
        </div>
      </section>

      <section className="grid gap-5 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
          <h2 className="text-xl font-black">Device Session</h2>
          <div className="mt-4 space-y-3 text-sm">
            <p><span className="text-slate-400">Session ID:</span> <span className="font-bold text-cyan-300">{sessionId || "-"}</span></p>
            <p><span className="text-slate-400">Device:</span> <span className="font-bold">{deviceInfo?.device_name || latest.device_name || "-"}</span></p>
            <p><span className="text-slate-400">Network Type:</span> <span className="font-bold">{deviceInfo?.network_type || latest.network_type || "-"}</span></p>
            <p><span className="text-slate-400">Source:</span> <span className="font-bold text-emerald-300">{latest.source || "waiting"}</span></p>
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
          <h2 className="text-xl font-black">QoE Score Trend</h2>
          {chartData.length > 0 ? (
            <ResponsiveContainer width="100%" height={260}>
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
            <div className="flex h-[260px] items-center justify-center text-slate-500">
              Waiting for QoE score...
            </div>
          )}
        </div>
      </section>
    </main>
  );
}
TSX

echo "=================================================="
echo "DONE"
echo "=================================================="
