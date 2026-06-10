#!/bin/bash
set -e

echo "=================================================="
echo "FIX PER-DEVICE QOE SESSION"
echo "=================================================="

REGION="asia-southeast2"
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

echo "API_URL=$API_URL"

mkdir -p .backup-per-device-session-v1
[ -f backend/main.py ] && cp backend/main.py .backup-per-device-session-v1/main.py.bak
[ -f app/layout.tsx ] && cp app/layout.tsx .backup-per-device-session-v1/layout.tsx.bak

mkdir -p components
mkdir -p app/api/qos-history
mkdir -p app/api/qos-metrics
mkdir -p app/api/qos-alerts

echo "=================================================="
echo "1. APPEND BACKEND SESSION-AWARE ENDPOINTS"
echo "=================================================="

cat >> backend/main.py <<'PY'

# ============================================================
# SESSION-AWARE REAL QOE ENDPOINTS
# Each browser/device now has its own telemetry window.
# This prevents laptop WiFi and phone SIM-card charts from
# displaying the same global pattern.
# ============================================================

from fastapi import Query
from collections import deque
import time as _qoe_time

if "qoe_samples" not in globals():
    qoe_samples = deque(maxlen=2000)

def _qoe_sid(sample: dict):
    return (
        sample.get("session_id")
        or sample.get("client_session_id")
        or sample.get("clientSessionId")
        or sample.get("device_id")
        or sample.get("deviceId")
        or "global"
    )

def _qoe_norm(sample: dict):
    throughput = (
        sample.get("downloadMbps")
        or sample.get("download_mbps")
        or sample.get("throughput")
        or sample.get("bandwidth")
        or 0
    )

    qoe_score = (
        sample.get("qoeScore")
        or sample.get("qoe_score")
        or sample.get("score")
        or 0
    )

    packet_loss = (
        sample.get("packet_loss")
        or sample.get("packetLoss")
        or sample.get("loss")
        or 0
    )

    timestamp = (
        sample.get("time")
        or sample.get("timestamp_label")
        or sample.get("timestamp")
        or "-"
    )

    return {
        "throughput": round(float(throughput or 0), 2),
        "latency": round(float(sample.get("latency") or sample.get("backendMs") or 0), 2),
        "jitter": round(float(sample.get("jitter") or 0), 2),
        "packet_loss": round(float(packet_loss or 0), 2),
        "bandwidth": round(float(throughput or 0), 2),
        "qoe_score": round(float(qoe_score or 0), 2),
        "source": sample.get("source") or "real-qoe-probe",
        "timestamp": str(timestamp),
        "session_id": _qoe_sid(sample),
        "device_id": sample.get("device_id") or sample.get("deviceId") or "-",
        "device_name": sample.get("device_name") or sample.get("deviceName") or "-",
        "network_type": sample.get("network_type") or sample.get("networkType") or "-",
        "user_agent": sample.get("user_agent") or sample.get("userAgent") or "-",
    }

def _qoe_session_samples(session_id: str = "", limit: int = 50):
    rows = list(qoe_samples)
    if session_id:
        rows = [s for s in rows if _qoe_sid(s) == session_id]
    return [_qoe_norm(s) for s in rows[:limit]]

def _qoe_status(score: float, latency: float, jitter: float, throughput: float):
    if score >= 90 and latency < 90 and jitter < 30 and throughput >= 10:
        return "EXCELLENT"
    if score >= 75 and latency < 140 and jitter < 50 and throughput >= 5:
        return "STABLE"
    if score >= 60 or latency < 220:
        return "BUFFER RISK"
    return "POOR"

@app.get("/api/qoe/session-history")
def qoe_session_history(
    session_id: str = Query(default=""),
    limit: int = Query(default=50)
):
    limit = max(1, min(int(limit), 200))
    return _qoe_session_samples(session_id=session_id, limit=limit)

@app.get("/api/qoe/session-metrics")
def qoe_session_metrics(session_id: str = Query(default="")):
    rows = _qoe_session_samples(session_id=session_id, limit=50)

    if not rows:
        return {
            "throughput": 0,
            "latency": 0,
            "jitter": 0,
            "packet_loss": 0,
            "bandwidth": 0,
            "source": "waiting-for-device-session",
            "qoe_score": 0,
            "streaming_status": "WAITING",
            "timestamp": "-",
            "session_id": session_id or "global",
        }

    latest = rows[0]
    latest["streaming_status"] = _qoe_status(
        float(latest.get("qoe_score") or 0),
        float(latest.get("latency") or 0),
        float(latest.get("jitter") or 0),
        float(latest.get("throughput") or 0),
    )
    return latest

@app.get("/api/qoe/session-alerts")
def qoe_session_alerts(session_id: str = Query(default="")):
    rows = _qoe_session_samples(session_id=session_id, limit=20)
    alerts = []

    if not rows:
        return alerts

    latest = rows[0]
    latency = float(latest.get("latency") or 0)
    jitter = float(latest.get("jitter") or 0)
    throughput = float(latest.get("throughput") or 0)
    qoe = float(latest.get("qoe_score") or 0)
    loss = float(latest.get("packet_loss") or 0)

    now = latest.get("timestamp") or "-"

    def add_alert(level, message, metric, source):
        alerts.append({
            "id": int(_qoe_time.time() * 1000) + len(alerts),
            "type": level,
            "message": message,
            "metric": metric,
            "time": now,
            "source": source,
            "session_id": latest.get("session_id"),
            "device_name": latest.get("device_name"),
            "network_type": latest.get("network_type"),
        })

    if qoe < 60:
        add_alert("critical", "Poor Device QoE Detected", f"QoE {qoe:.1f}", "Per-Device QoE")
    elif qoe < 75:
        add_alert("warning", "Buffer Risk on Current Device", f"QoE {qoe:.1f}", "Per-Device QoE")

    if latency > 180:
        add_alert("critical", "Critical Device Latency Spike", f"{latency:.1f} ms", "Per-Device Probe")
    elif latency > 100:
        add_alert("warning", "High Device Latency Detected", f"{latency:.1f} ms", "Per-Device Probe")

    if jitter > 80:
        add_alert("critical", "Critical Device Jitter Detected", f"{jitter:.1f} ms", "Per-Device Probe")
    elif jitter > 35:
        add_alert("warning", "High Device Jitter Detected", f"{jitter:.1f} ms", "Per-Device Probe")

    if throughput < 3:
        add_alert("critical", "Very Low Device Download Throughput", f"{throughput:.2f} Mbps", "Per-Device Download Probe")
    elif throughput < 8:
        add_alert("warning", "Low Device Download Throughput", f"{throughput:.2f} Mbps", "Per-Device Download Probe")

    if loss > 1:
        add_alert("critical", "Packet Loss Detected on Current Device", f"{loss:.2f}%", "Per-Device Probe")

    return alerts
PY

echo "=================================================="
echo "2. FRONTEND SESSION CONTROLLER"
echo "=================================================="

cat > components/device-session-controller.tsx <<'TSX'
"use client";

import { useEffect } from "react";

declare global {
  interface Window {
    __AKSARA_DEVICE_SESSION__?: string;
    __AKSARA_DEVICE_INFO__?: Record<string, any>;
  }
}

function uuid() {
  try {
    return crypto.randomUUID();
  } catch {
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }
}

function getDeviceType() {
  const ua = navigator.userAgent || "";
  if (/android/i.test(ua)) return "android-phone";
  if (/iphone/i.test(ua)) return "iphone";
  if (/ipad/i.test(ua)) return "ipad";
  if (/mobile/i.test(ua)) return "mobile";
  return "desktop";
}

function getBrowserName() {
  const ua = navigator.userAgent || "";
  if (ua.includes("Edg/")) return "Edge";
  if (ua.includes("Chrome/")) return "Chrome";
  if (ua.includes("Firefox/")) return "Firefox";
  if (ua.includes("Safari/") && !ua.includes("Chrome/")) return "Safari";
  return "Browser";
}

function getConnectionInfo() {
  const c =
    (navigator as any).connection ||
    (navigator as any).mozConnection ||
    (navigator as any).webkitConnection;

  return {
    effectiveType: c?.effectiveType || "unknown",
    downlink: c?.downlink || 0,
    rtt: c?.rtt || 0,
    saveData: Boolean(c?.saveData),
  };
}

function ensureSession() {
  let sid = localStorage.getItem("aksara-device-session-id");

  if (!sid) {
    sid = `${getDeviceType()}-${uuid()}`;
    localStorage.setItem("aksara-device-session-id", sid);
  }

  const connection = getConnectionInfo();

  const info = {
    session_id: sid,
    device_id: sid,
    device_name: `${getDeviceType()}-${getBrowserName()}`,
    device_type: getDeviceType(),
    browser: getBrowserName(),
    platform: navigator.platform || "unknown",
    network_type: connection.effectiveType,
    browser_downlink_mbps: connection.downlink,
    browser_rtt_ms: connection.rtt,
    save_data: connection.saveData,
    user_agent: navigator.userAgent || "unknown",
  };

  window.__AKSARA_DEVICE_SESSION__ = sid;
  window.__AKSARA_DEVICE_INFO__ = info;

  return info;
}

function appendSessionToUrl(input: RequestInfo | URL) {
  const info = ensureSession();

  if (typeof input !== "string") return input;

  const targets = [
    "/api/qos-history",
    "/api/qos-metrics",
    "/api/qos-alerts",
    "/api/reports/pdf",
    "/api/reports/csv",
  ];

  if (!targets.some((t) => input.includes(t))) return input;
  if (input.includes("session_id=")) return input;

  const join = input.includes("?") ? "&" : "?";
  return `${input}${join}session_id=${encodeURIComponent(info.session_id)}`;
}

function patchFetch() {
  if ((window as any).__AKSARA_FETCH_PATCHED__) return;
  (window as any).__AKSARA_FETCH_PATCHED__ = true;

  const originalFetch = window.fetch.bind(window);

  window.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const info = ensureSession();

    let nextInput = appendSessionToUrl(input);
    let nextInit = init ? { ...init } : undefined;

    const urlText =
      typeof nextInput === "string"
        ? nextInput
        : nextInput instanceof URL
          ? nextInput.toString()
          : "";

    const isSamplePost = urlText.includes("/api/qoe/sample");

    if (isSamplePost && nextInit?.body && typeof nextInit.body === "string") {
      try {
        const body = JSON.parse(nextInit.body);

        nextInit.body = JSON.stringify({
          ...body,
          ...info,
          client_timestamp: Date.now(),
          source: "per-device-real-qoe-probe",
        });

        nextInit.headers = {
          ...(nextInit.headers || {}),
          "Content-Type": "application/json",
        };
      } catch {
        // keep original body
      }
    }

    return originalFetch(nextInput, nextInit);
  };
}

export function DeviceSessionController() {
  useEffect(() => {
    ensureSession();
    patchFetch();

    const refresh = () => ensureSession();

    window.addEventListener("online", refresh);
    window.addEventListener("offline", refresh);

    const interval = setInterval(() => {
      const info = ensureSession();
      window.dispatchEvent(
        new CustomEvent("aksara-device-session-refresh", {
          detail: info,
        })
      );
    }, 5000);

    return () => {
      clearInterval(interval);
      window.removeEventListener("online", refresh);
      window.removeEventListener("offline", refresh);
    };
  }, []);

  return null;
}
TSX

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
    if "</body>" in s:
        s = s.replace("</body>", "        <DeviceSessionController />\n      </body>", 1)

p.write_text(s)
print("✅ DeviceSessionController injected")
PY

echo "=================================================="
echo "3. FRONTEND API PROXIES FILTER BY SESSION"
echo "=================================================="

cat > app/api/qos-history/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

export async function GET(req) {
  const url = new URL(req.url);
  const sessionId = url.searchParams.get("session_id") || "";
  const limit = url.searchParams.get("limit") || "80";

  const endpoint = sessionId
    ? `${API_URL}/api/qoe/session-history?session_id=${encodeURIComponent(sessionId)}&limit=${encodeURIComponent(limit)}`
    : `${API_URL}/api/qos/history`;

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

  const endpoint = sessionId
    ? `${API_URL}/api/qoe/session-metrics?session_id=${encodeURIComponent(sessionId)}`
    : `${API_URL}/api/qos/metrics`;

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

  const endpoint = sessionId
    ? `${API_URL}/api/qoe/session-alerts?session_id=${encodeURIComponent(sessionId)}`
    : `${API_URL}/api/alerts`;

  const res = await fetch(endpoint, { cache: "no-store" });
  const data = await res.json();

  return Response.json(Array.isArray(data) ? data : [], {
    headers: { "Cache-Control": "no-store" },
  });
}
JS

python3 <<PY
from pathlib import Path
for f in [
    "app/api/qos-history/route.js",
    "app/api/qos-metrics/route.js",
    "app/api/qos-alerts/route.js",
]:
    p = Path(f)
    s = p.read_text().replace("__API_URL__", "$API_URL")
    p.write_text(s)
    print("patched", f)
PY

echo "=================================================="
echo "4. ADD SESSION BADGE CSS"
echo "=================================================="

cat >> app/globals.css <<'CSS'

/* Per-device QoE session marker */
html::before {
  content: "Per-device QoE session active";
  position: fixed;
  right: 18px;
  bottom: 72px;
  z-index: 9998;
  padding: 7px 11px;
  border-radius: 999px;
  background: rgba(2, 6, 23, 0.85);
  border: 1px solid rgba(34, 211, 238, 0.35);
  color: #67e8f9;
  font-size: 11px;
  font-weight: 800;
  pointer-events: none;
}

@media (max-width: 768px) {
  html::before {
    right: 12px;
    bottom: 58px;
    font-size: 10px;
  }
}
CSS

echo "=================================================="
echo "DONE"
echo "=================================================="
