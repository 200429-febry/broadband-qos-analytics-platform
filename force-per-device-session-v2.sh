#!/bin/bash
set -e

echo "=================================================="
echo "FORCE PER-DEVICE TELEMETRY SESSION V2"
echo "=================================================="

REGION="asia-southeast2"
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

echo "API_URL=$API_URL"

if [ -z "$API_URL" ]; then
  echo "❌ API_URL kosong. Service qos-api tidak ketemu."
  exit 1
fi

mkdir -p .backup-force-session-v2
[ -f backend/main.py ] && cp backend/main.py .backup-force-session-v2/main.py.bak
[ -f app/layout.tsx ] && cp app/layout.tsx .backup-force-session-v2/layout.tsx.bak
[ -f components/device-session-controller.tsx ] && cp components/device-session-controller.tsx .backup-force-session-v2/device-session-controller.tsx.bak

echo "python-3.12" > backend/runtime.txt

cat > backend/.gcloudignore <<'IGN'
venv/
__pycache__/
*.pyc
.env
.git/
.next/
node_modules/
IGN

cat >> backend/main.py <<'PY'

# ============================================================
# FORCE PER-DEVICE QOE TELEMETRY V2
# Dedicated device-session storage. This avoids global history
# being shared by laptop WiFi, phone SIM, and other browsers.
# ============================================================

from fastapi import Query as _QoeQuery
from collections import deque as _QoeDeque
import time as _qoe_time
import uuid as _qoe_uuid

if "qoe_device_samples_v2" not in globals():
    qoe_device_samples_v2 = _QoeDeque(maxlen=5000)

def _v2_float(v, default=0):
    try:
        if v is None or v == "":
            return default
        return float(v)
    except Exception:
        return default

def _v2_session_id(payload: dict):
    return (
        payload.get("session_id")
        or payload.get("client_session_id")
        or payload.get("clientSessionId")
        or payload.get("device_id")
        or payload.get("deviceId")
        or "unknown-session"
    )

def _v2_status(qoe, latency, jitter, throughput, loss):
    qoe = _v2_float(qoe)
    latency = _v2_float(latency)
    jitter = _v2_float(jitter)
    throughput = _v2_float(throughput)
    loss = _v2_float(loss)

    if loss >= 1.0 or latency >= 220 or jitter >= 100 or throughput < 3:
        return "POOR"
    if qoe < 75 or latency >= 120 or jitter >= 45 or throughput < 8:
        return "BUFFER RISK"
    if qoe < 90 or latency >= 80 or jitter >= 25:
        return "STABLE"
    return "EXCELLENT"

def _v2_normalize(payload: dict):
    throughput = (
        payload.get("downloadMbps")
        or payload.get("download_mbps")
        or payload.get("throughput")
        or payload.get("bandwidth")
        or 0
    )

    qoe = (
        payload.get("qoeScore")
        or payload.get("qoe_score")
        or payload.get("score")
        or 0
    )

    latency = (
        payload.get("latency")
        or payload.get("backendMs")
        or payload.get("backend_ms")
        or 0
    )

    jitter = payload.get("jitter") or 0
    loss = payload.get("packet_loss") or payload.get("packetLoss") or payload.get("loss") or 0

    status = (
        payload.get("status")
        or payload.get("streaming_status")
        or _v2_status(qoe, latency, jitter, throughput, loss)
    )

    now_label = payload.get("time") or payload.get("timestamp_label")
    if not now_label:
        try:
            now_label = _qoe_time.strftime("%I:%M:%S %p")
        except Exception:
            now_label = "-"

    return {
        "id": payload.get("id") or str(_qoe_uuid.uuid4()),
        "timestamp_epoch": _v2_float(payload.get("timestamp_epoch") or payload.get("client_timestamp") or _qoe_time.time()),
        "timestamp": str(now_label),
        "time": str(now_label),

        "throughput": round(_v2_float(throughput), 2),
        "downloadMbps": round(_v2_float(throughput), 2),
        "latency": round(_v2_float(latency), 2),
        "jitter": round(_v2_float(jitter), 2),
        "packet_loss": round(_v2_float(loss), 2),
        "bandwidth": round(_v2_float(throughput), 2),
        "qoe_score": round(_v2_float(qoe), 2),
        "qoeScore": round(_v2_float(qoe), 2),
        "streaming_status": status,
        "status": status,

        "source": payload.get("source") or "per-device-real-qoe-probe",
        "session_id": _v2_session_id(payload),
        "device_id": payload.get("device_id") or payload.get("deviceId") or _v2_session_id(payload),
        "device_name": payload.get("device_name") or payload.get("deviceName") or "unknown-device",
        "device_type": payload.get("device_type") or payload.get("deviceType") or "unknown",
        "browser": payload.get("browser") or "unknown",
        "platform": payload.get("platform") or "unknown",
        "network_type": payload.get("network_type") or payload.get("networkType") or "unknown",
        "browser_downlink_mbps": _v2_float(payload.get("browser_downlink_mbps") or payload.get("downlink")),
        "browser_rtt_ms": _v2_float(payload.get("browser_rtt_ms") or payload.get("rtt")),
        "user_agent": payload.get("user_agent") or payload.get("userAgent") or "-",
    }

@app.post("/api/qoe/device-sample")
async def qoe_device_sample_v2(payload: dict):
    sample = _v2_normalize(payload)
    qoe_device_samples_v2.appendleft(sample)

    return {
        "status": "saved",
        "message": "Per-device QoE sample saved",
        "session_id": sample["session_id"],
        "device_name": sample["device_name"],
        "network_type": sample["network_type"],
        "sample": sample,
    }

@app.get("/api/qoe/device-history")
def qoe_device_history_v2(
    session_id: str = _QoeQuery(default=""),
    limit: int = _QoeQuery(default=80)
):
    limit = max(1, min(int(limit), 300))
    rows = list(qoe_device_samples_v2)

    if session_id:
        rows = [r for r in rows if r.get("session_id") == session_id]

    return rows[:limit]

@app.get("/api/qoe/device-metrics")
def qoe_device_metrics_v2(session_id: str = _QoeQuery(default="")):
    rows = list(qoe_device_samples_v2)

    if session_id:
        rows = [r for r in rows if r.get("session_id") == session_id]

    if not rows:
        return {
            "throughput": 0,
            "latency": 0,
            "jitter": 0,
            "packet_loss": 0,
            "bandwidth": 0,
            "qoe_score": 0,
            "streaming_status": "WAITING",
            "status": "WAITING",
            "source": "waiting-for-current-device-session",
            "timestamp": "-",
            "session_id": session_id or "unknown-session",
        }

    latest = rows[0]
    return latest

@app.get("/api/qoe/device-alerts")
def qoe_device_alerts_v2(session_id: str = _QoeQuery(default="")):
    rows = list(qoe_device_samples_v2)

    if session_id:
        rows = [r for r in rows if r.get("session_id") == session_id]

    if not rows:
        return []

    latest = rows[0]
    alerts = []

    qoe = _v2_float(latest.get("qoe_score"))
    latency = _v2_float(latest.get("latency"))
    jitter = _v2_float(latest.get("jitter"))
    throughput = _v2_float(latest.get("throughput"))
    loss = _v2_float(latest.get("packet_loss"))
    t = latest.get("timestamp") or "-"

    def add(level, message, metric, source):
        alerts.append({
            "id": int(_qoe_time.time() * 1000) + len(alerts),
            "type": level,
            "message": message,
            "metric": metric,
            "time": t,
            "source": source,
            "session_id": latest.get("session_id"),
            "device_name": latest.get("device_name"),
            "network_type": latest.get("network_type"),
        })

    if qoe < 60:
        add("critical", "Poor QoE on Current Device", f"QoE {qoe:.1f}", "Per-Device QoE")
    elif qoe < 75:
        add("warning", "Buffer Risk on Current Device", f"QoE {qoe:.1f}", "Per-Device QoE")

    if latency > 180:
        add("critical", "Critical Latency on Current Device", f"{latency:.1f} ms", "Per-Device Probe")
    elif latency > 100:
        add("warning", "High Latency on Current Device", f"{latency:.1f} ms", "Per-Device Probe")

    if jitter > 80:
        add("critical", "Critical Jitter on Current Device", f"{jitter:.1f} ms", "Per-Device Probe")
    elif jitter > 35:
        add("warning", "High Jitter on Current Device", f"{jitter:.1f} ms", "Per-Device Probe")

    if throughput < 3:
        add("critical", "Very Low Throughput on Current Device", f"{throughput:.2f} Mbps", "Per-Device Download Probe")
    elif throughput < 8:
        add("warning", "Low Throughput on Current Device", f"{throughput:.2f} Mbps", "Per-Device Download Probe")

    if loss >= 1:
        add("critical", "Packet Loss on Current Device", f"{loss:.2f}%", "Per-Device Probe")

    return alerts

@app.get("/api/qoe/device-sessions")
def qoe_device_sessions_v2():
    sessions = {}

    for row in list(qoe_device_samples_v2):
        sid = row.get("session_id") or "unknown-session"
        if sid not in sessions:
            sessions[sid] = {
                "session_id": sid,
                "device_name": row.get("device_name"),
                "device_type": row.get("device_type"),
                "browser": row.get("browser"),
                "platform": row.get("platform"),
                "network_type": row.get("network_type"),
                "latest_timestamp": row.get("timestamp"),
                "sample_count": 0,
            }
        sessions[sid]["sample_count"] += 1

    return {
        "count": len(sessions),
        "sessions": list(sessions.values()),
    }
PY

mkdir -p components
cat > components/device-session-controller.tsx <<'TSX'
"use client";

import { useEffect } from "react";

const API_URL = "__API_URL__";

declare global {
  interface Window {
    __AKSARA_DEVICE_SESSION__?: string;
    __AKSARA_DEVICE_INFO__?: Record<string, any>;
    __AKSARA_FETCH_PATCHED_V2__?: boolean;
  }
}

function makeId() {
  try {
    return crypto.randomUUID();
  } catch {
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }
}

function detectDeviceType() {
  const ua = navigator.userAgent || "";
  if (/android/i.test(ua)) return "android-phone";
  if (/iphone/i.test(ua)) return "iphone";
  if (/ipad/i.test(ua)) return "ipad";
  if (/mobile/i.test(ua)) return "mobile";
  return "desktop";
}

function detectBrowser() {
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

function ensureDeviceSession() {
  let sid = localStorage.getItem("aksara-device-session-id-v2");

  if (!sid) {
    sid = `${detectDeviceType()}-${makeId()}`;
    localStorage.setItem("aksara-device-session-id-v2", sid);
  }

  const conn = connectionInfo();

  const info = {
    session_id: sid,
    client_session_id: sid,
    device_id: sid,
    device_name: `${detectDeviceType()}-${detectBrowser()}`,
    device_type: detectDeviceType(),
    browser: detectBrowser(),
    platform: navigator.platform || "unknown",
    user_agent: navigator.userAgent || "-",
    ...conn,
  };

  window.__AKSARA_DEVICE_SESSION__ = sid;
  window.__AKSARA_DEVICE_INFO__ = info;

  document.documentElement.setAttribute("data-aksara-session-id", sid);
  document.documentElement.setAttribute("data-aksara-device-name", info.device_name);
  document.documentElement.setAttribute("data-aksara-network-type", info.network_type);

  return info;
}

function withSession(url: string, sessionId: string) {
  if (url.includes("session_id=")) return url;
  return `${url}${url.includes("?") ? "&" : "?"}session_id=${encodeURIComponent(sessionId)}`;
}

function normalizeUrl(input: RequestInfo | URL) {
  if (typeof input === "string") return input;
  if (input instanceof URL) return input.toString();
  if (input instanceof Request) return input.url;
  return String(input);
}

function rerouteTelemetryUrl(inputUrl: string, sessionId: string) {
  let url = inputUrl;

  if (url.includes("/api/qoe/sample")) {
    if (url.startsWith("http")) {
      return url.replace("/api/qoe/sample", "/api/qoe/device-sample");
    }
    return `${API_URL}/api/qoe/device-sample`;
  }

  if (url.includes("/api/qos/history")) {
    return withSession(`${window.location.origin}/api/qos-history`, sessionId);
  }

  if (url.includes("/api/qos/metrics")) {
    return withSession(`${window.location.origin}/api/qos-metrics`, sessionId);
  }

  if (url.includes("/api/alerts")) {
    return withSession(`${window.location.origin}/api/qos-alerts`, sessionId);
  }

  if (url.includes("/api/qoe/latest")) {
    return withSession(`${window.location.origin}/api/qos-history`, sessionId);
  }

  if (url.includes("/api/qos-history") || url.includes("/api/qos-metrics") || url.includes("/api/qos-alerts")) {
    return withSession(url, sessionId);
  }

  return url;
}

function patchFetch() {
  if (window.__AKSARA_FETCH_PATCHED_V2__) return;
  window.__AKSARA_FETCH_PATCHED_V2__ = true;

  const originalFetch = window.fetch.bind(window);

  window.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const info = ensureDeviceSession();
    const originalUrl = normalizeUrl(input);
    const nextUrl = rerouteTelemetryUrl(originalUrl, info.session_id);

    let nextInit: RequestInit = init ? { ...init } : {};

    const headers = new Headers(nextInit.headers || {});
    headers.set("x-aksara-session-id", info.session_id);
    headers.set("x-aksara-device-name", info.device_name);
    nextInit.headers = headers;

    const isSamplePost = nextUrl.includes("/api/qoe/device-sample");

    if (isSamplePost) {
      let bodyObject: any = {};

      if (nextInit.body && typeof nextInit.body === "string") {
        try {
          bodyObject = JSON.parse(nextInit.body);
        } catch {
          bodyObject = {};
        }
      }

      const now = new Date();

      nextInit.method = "POST";
      headers.set("Content-Type", "application/json");
      nextInit.headers = headers;

      nextInit.body = JSON.stringify({
        ...bodyObject,
        ...info,
        timestamp_epoch: Date.now(),
        time: now.toLocaleTimeString(),
        source: "per-device-real-qoe-probe",
      });
    }

    return originalFetch(nextUrl, nextInit);
  };
}

export function DeviceSessionController() {
  useEffect(() => {
    ensureDeviceSession();
    patchFetch();

    const interval = setInterval(() => {
      const info = ensureDeviceSession();
      window.dispatchEvent(
        new CustomEvent("aksara-device-session-refresh", {
          detail: info,
        })
      );
    }, 3000);

    return () => clearInterval(interval);
  }, []);

  return null;
}
TSX

python3 <<PY
from pathlib import Path
p = Path("components/device-session-controller.tsx")
s = p.read_text().replace("__API_URL__", "$API_URL")
p.write_text(s)
print("✅ device-session-controller patched with API_URL")
PY

python3 <<'PY'
from pathlib import Path

p = Path("app/layout.tsx")
s = p.read_text()

imp = 'import { DeviceSessionController } from "@/components/device-session-controller";'
if imp not in s:
    lines = s.splitlines()
    idx = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            idx = i + 1
    lines.insert(idx, imp)
    s = "\n".join(lines)

if "<DeviceSessionController />" not in s:
    s = s.replace("</body>", "        <DeviceSessionController />\n      </body>")

p.write_text(s)
print("✅ DeviceSessionController injected into layout")
PY

mkdir -p app/api/qos-history app/api/qos-metrics app/api/qos-alerts

cat > app/api/qos-history/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET(req) {
  const url = new URL(req.url);
  const sessionId = url.searchParams.get("session_id") || "";
  const limit = url.searchParams.get("limit") || "80";

  if (!sessionId) {
    return Response.json([], {
      headers: { "Cache-Control": "no-store" },
    });
  }

  const endpoint =
    API_URL +
    "/api/qoe/device-history?session_id=" +
    encodeURIComponent(sessionId) +
    "&limit=" +
    encodeURIComponent(limit);

  const res = await fetch(endpoint, { cache: "no-store" });
  const data = await res.json();

  return Response.json(Array.isArray(data) ? data : [], {
    headers: { "Cache-Control": "no-store" },
  });
}
JS

cat > app/api/qos-metrics/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET(req) {
  const url = new URL(req.url);
  const sessionId = url.searchParams.get("session_id") || "";

  if (!sessionId) {
    return Response.json({
      throughput: 0,
      latency: 0,
      jitter: 0,
      packet_loss: 0,
      qoe_score: 0,
      streaming_status: "WAITING",
      source: "no-device-session",
      timestamp: "-",
    }, {
      headers: { "Cache-Control": "no-store" },
    });
  }

  const endpoint =
    API_URL +
    "/api/qoe/device-metrics?session_id=" +
    encodeURIComponent(sessionId);

  const res = await fetch(endpoint, { cache: "no-store" });
  const data = await res.json();

  return Response.json(data || {}, {
    headers: { "Cache-Control": "no-store" },
  });
}
JS

cat > app/api/qos-alerts/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET(req) {
  const url = new URL(req.url);
  const sessionId = url.searchParams.get("session_id") || "";

  if (!sessionId) {
    return Response.json([], {
      headers: { "Cache-Control": "no-store" },
    });
  }

  const endpoint =
    API_URL +
    "/api/qoe/device-alerts?session_id=" +
    encodeURIComponent(sessionId);

  const res = await fetch(endpoint, { cache: "no-store" });
  const data = await res.json();

  return Response.json(Array.isArray(data) ? data : [], {
    headers: { "Cache-Control": "no-store" },
  });
}
JS

python3 <<PY
from pathlib import Path
for f in ["app/api/qos-history/route.js", "app/api/qos-metrics/route.js", "app/api/qos-alerts/route.js"]:
    p = Path(f)
    s = p.read_text().replace("__API_URL__", "$API_URL")
    p.write_text(s)
    print("✅ patched", f)
PY

cat >> app/globals.css <<'CSS'

/* Force per-device session visibility */
html::after {
  content: "Device session isolated";
  position: fixed;
  right: 18px;
  bottom: 72px;
  z-index: 9998;
  padding: 7px 12px;
  border-radius: 999px;
  background: rgba(2, 6, 23, 0.88);
  border: 1px solid rgba(34, 211, 238, 0.35);
  color: #67e8f9;
  font-size: 11px;
  font-weight: 900;
  pointer-events: none;
}

@media (max-width: 768px) {
  html::after {
    right: 12px;
    bottom: 58px;
    font-size: 10px;
  }
}
CSS

echo "=================================================="
echo "CHECK DIRECT GLOBAL API CALLS"
echo "=================================================="
grep -RniE "api/qos/history|api/qos/metrics|api/alerts|api/qoe/latest|api/qoe/sample" app components \
  --exclude-dir=node_modules \
  --exclude-dir=.next \
  | head -100 || true

echo "=================================================="
echo "DONE"
echo "=================================================="
