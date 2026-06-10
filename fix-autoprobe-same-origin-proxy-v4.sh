#!/bin/bash
set -e

echo "=================================================="
echo "FIX AUTOPROBE VIA SAME-ORIGIN FRONTEND PROXY V4"
echo "=================================================="

REGION="asia-southeast2"
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

echo "API_URL=$API_URL"

if [ -z "$API_URL" ]; then
  echo "API_URL kosong"
  exit 1
fi

mkdir -p .backup-autoprobe-proxy-v4
[ -f components/device-autoprobe-controller.tsx ] && cp components/device-autoprobe-controller.tsx .backup-autoprobe-proxy-v4/device-autoprobe-controller.tsx.bak
[ -f app/layout.tsx ] && cp app/layout.tsx .backup-autoprobe-proxy-v4/layout.tsx.bak

mkdir -p app/api/device-probe/ping
mkdir -p app/api/device-probe/download
mkdir -p app/api/device-probe/upload
mkdir -p app/api/device-probe/sample
mkdir -p app/api/device-probe/sessions
mkdir -p components

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
  const sizeKb = url.searchParams.get("size_kb") || "384";

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
        "X-Probe-Proxy": "frontend-same-origin",
        "Content-Length": String(buffer.byteLength),
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
    return Response.json({ count: 0, sessions: [], error: String(e?.message || e) }, { status: 500 });
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
    __AKSARA_FETCH_PATCHED_V4__?: boolean;
  }
}

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
  let sid = localStorage.getItem("aksara-device-session-id-v4");

  if (!sid) {
    sid = `${deviceType()}-${makeId()}`;
    localStorage.setItem("aksara-device-session-id-v4", sid);
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
  if (window.__AKSARA_FETCH_PATCHED_V4__) return;
  window.__AKSARA_FETCH_PATCHED_V4__ = true;

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

    const nextInit = init ? { ...init } : undefined;

    return originalFetch(url, nextInit);
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
        const pingRes = await fetch("/api/device-probe/ping?x=" + Date.now(), {
          cache: "no-store",
        });
        await pingRes.json().catch(() => null);
        const p1 = performance.now();

        const latency = Number((p1 - p0).toFixed(1));
        const jitter =
          prevLatency.current === null
            ? 0
            : Number(Math.abs(latency - prevLatency.current).toFixed(1));
        prevLatency.current = latency;

        const d0 = performance.now();
        const downloadRes = await fetch("/api/device-probe/download?size_kb=512&x=" + Date.now(), {
          cache: "no-store",
        });
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
          source: "per-device-autoprobe-same-origin",
        };

        const saveRes = await fetch("/api/device-probe/sample", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          cache: "no-store",
          body: JSON.stringify(sample),
        });

        const saveJson = await saveRes.json().catch(() => null);

        console.log("[AKSARA AUTO PROBE]", {
          saved: saveRes.ok,
          backend: saveJson,
          sample,
        });

        window.dispatchEvent(new CustomEvent("aksara-device-autoprobe-sample", { detail: sample }));
      } catch (e) {
        console.warn("[AKSARA AUTO PROBE FAILED]", e);
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

echo "=================================================="
echo "DONE"
echo "=================================================="
