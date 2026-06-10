#!/bin/bash
set -e

echo "=================================================="
echo "FIX EMPTY CHART + REAL PER-DEVICE AUTO PROBE V3"
echo "=================================================="

REGION="asia-southeast2"
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

echo "API_URL=$API_URL"

if [ -z "$API_URL" ]; then
  echo "❌ API_URL kosong"
  exit 1
fi

mkdir -p .backup-chart-autoprobe-v3
[ -f app/layout.tsx ] && cp app/layout.tsx .backup-chart-autoprobe-v3/layout.tsx.bak
[ -f app/globals.css ] && cp app/globals.css .backup-chart-autoprobe-v3/globals.css.bak
[ -f components/device-autoprobe-controller.tsx ] && cp components/device-autoprobe-controller.tsx .backup-chart-autoprobe-v3/device-autoprobe-controller.tsx.bak

echo "=================================================="
echo "1. ENSURE BACKEND DEVICE ENDPOINT EXISTS"
echo "=================================================="

if grep -q '@app.post("/api/qoe/device-sample")' backend/main.py; then
  echo "✅ backend device-sample endpoint already exists"
else
cat >> backend/main.py <<'PY'

# ============================================================
# DEVICE AUTO PROBE ENDPOINTS
# Real per-device telemetry storage for laptop WiFi, phone SIM,
# and other browser sessions.
# ============================================================

from fastapi import Query as _DeviceQuery
from collections import deque as _DeviceDeque
import time as _device_time
import uuid as _device_uuid

if "qoe_device_samples_v3" not in globals():
    qoe_device_samples_v3 = _DeviceDeque(maxlen=8000)

def _device_float(v, default=0.0):
    try:
        if v is None or v == "":
            return default
        return float(v)
    except Exception:
        return default

def _device_status(qoe, latency, jitter, throughput, loss):
    qoe = _device_float(qoe)
    latency = _device_float(latency)
    jitter = _device_float(jitter)
    throughput = _device_float(throughput)
    loss = _device_float(loss)

    if loss >= 1 or latency >= 220 or jitter >= 100 or throughput < 3:
        return "POOR"
    if qoe < 75 or latency >= 120 or jitter >= 45 or throughput < 8:
        return "BUFFER RISK"
    if qoe < 90 or latency >= 80 or jitter >= 25:
        return "STABLE"
    return "EXCELLENT"

def _device_norm(payload: dict):
    throughput = (
        payload.get("downloadMbps")
        or payload.get("download_mbps")
        or payload.get("throughput")
        or payload.get("bandwidth")
        or 0
    )
    upload = payload.get("uploadMbps") or payload.get("upload_mbps") or 0
    latency = payload.get("latency") or payload.get("backendMs") or payload.get("backend_ms") or 0
    jitter = payload.get("jitter") or 0
    loss = payload.get("packet_loss") or payload.get("packetLoss") or 0
    qoe = payload.get("qoeScore") or payload.get("qoe_score") or payload.get("score") or 0

    sid = (
        payload.get("session_id")
        or payload.get("client_session_id")
        or payload.get("device_id")
        or "unknown-session"
    )

    now_label = payload.get("time") or _device_time.strftime("%I:%M:%S %p")

    status = payload.get("status") or payload.get("streaming_status") or _device_status(qoe, latency, jitter, throughput, loss)

    return {
        "id": payload.get("id") or str(_device_uuid.uuid4()),
        "timestamp_epoch": _device_float(payload.get("timestamp_epoch") or _device_time.time()),
        "timestamp": str(now_label),
        "time": str(now_label),

        "throughput": round(_device_float(throughput), 2),
        "downloadMbps": round(_device_float(throughput), 2),
        "uploadMbps": round(_device_float(upload), 2),
        "latency": round(_device_float(latency), 2),
        "jitter": round(_device_float(jitter), 2),
        "packet_loss": round(_device_float(loss), 2),
        "bandwidth": round(_device_float(throughput), 2),
        "qoe_score": round(_device_float(qoe), 2),
        "qoeScore": round(_device_float(qoe), 2),
        "streaming_status": status,
        "status": status,

        "source": payload.get("source") or "per-device-autoprobe-real-traffic",
        "session_id": sid,
        "device_id": payload.get("device_id") or sid,
        "device_name": payload.get("device_name") or "unknown-device",
        "device_type": payload.get("device_type") or "unknown",
        "browser": payload.get("browser") or "unknown",
        "platform": payload.get("platform") or "unknown",
        "network_type": payload.get("network_type") or "unknown",
        "browser_downlink_mbps": _device_float(payload.get("browser_downlink_mbps")),
        "browser_rtt_ms": _device_float(payload.get("browser_rtt_ms")),
        "user_agent": payload.get("user_agent") or "-",
    }

@app.post("/api/qoe/device-sample")
async def qoe_device_sample(payload: dict):
    sample = _device_norm(payload)

    if "qoe_device_samples_v2" in globals():
        qoe_device_samples_v2.appendleft(sample)

    qoe_device_samples_v3.appendleft(sample)

    return {
        "status": "saved",
        "message": "Per-device real QoE sample saved",
        "session_id": sample["session_id"],
        "device_name": sample["device_name"],
        "sample": sample,
    }

@app.get("/api/qoe/device-history")
def qoe_device_history(session_id: str = _DeviceQuery(default=""), limit: int = _DeviceQuery(default=80)):
    limit = max(1, min(int(limit), 300))

    rows = []
    if "qoe_device_samples_v2" in globals():
        rows.extend(list(qoe_device_samples_v2))
    rows.extend(list(qoe_device_samples_v3))

    if session_id:
        rows = [r for r in rows if r.get("session_id") == session_id]

    unique = []
    seen = set()
    for r in rows:
        key = r.get("id") or f'{r.get("session_id")}-{r.get("timestamp_epoch")}'
        if key not in seen:
            seen.add(key)
            unique.append(r)

    return unique[:limit]

@app.get("/api/qoe/device-metrics")
def qoe_device_metrics(session_id: str = _DeviceQuery(default="")):
    rows = qoe_device_history(session_id=session_id, limit=1)
    if not rows:
        return {
            "throughput": 0,
            "latency": 0,
            "jitter": 0,
            "packet_loss": 0,
            "qoe_score": 0,
            "streaming_status": "WAITING",
            "source": "waiting-for-current-device-session",
            "timestamp": "-",
            "session_id": session_id or "unknown-session",
        }
    return rows[0]

@app.get("/api/qoe/device-alerts")
def qoe_device_alerts(session_id: str = _DeviceQuery(default="")):
    latest = qoe_device_metrics(session_id=session_id)
    if latest.get("streaming_status") == "WAITING":
        return []

    alerts = []
    latency = _device_float(latest.get("latency"))
    jitter = _device_float(latest.get("jitter"))
    throughput = _device_float(latest.get("throughput"))
    qoe = _device_float(latest.get("qoe_score"))
    loss = _device_float(latest.get("packet_loss"))
    t = latest.get("timestamp") or "-"

    def add(level, message, metric, source):
        alerts.append({
            "id": int(_device_time.time() * 1000) + len(alerts),
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
def qoe_device_sessions():
    rows = []
    if "qoe_device_samples_v2" in globals():
        rows.extend(list(qoe_device_samples_v2))
    rows.extend(list(qoe_device_samples_v3))

    sessions = {}
    for row in rows:
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

    return {"count": len(sessions), "sessions": list(sessions.values())}
PY
fi

echo "=================================================="
echo "2. DEVICE AUTO PROBE CONTROLLER"
echo "=================================================="

cat > components/device-autoprobe-controller.tsx <<'TSX'
"use client";

import { useEffect, useRef } from "react";

const API_URL = "__API_URL__";

declare global {
  interface Window {
    __AKSARA_DEVICE_SESSION__?: string;
    __AKSARA_DEVICE_INFO__?: Record<string, any>;
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

function conn() {
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
  let sid = localStorage.getItem("aksara-device-session-id-v3");

  if (!sid) {
    sid = `${deviceType()}-${makeId()}`;
    localStorage.setItem("aksara-device-session-id-v3", sid);
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
    ...conn(),
  };

  window.__AKSARA_DEVICE_SESSION__ = sid;
  window.__AKSARA_DEVICE_INFO__ = info;

  return info;
}

function scoreFrom(latency: number, jitter: number, down: number, loss: number) {
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

async function timedFetch(url: string, init?: RequestInit) {
  const start = performance.now();
  const res = await fetch(url, {
    ...init,
    cache: "no-store",
  });
  const end = performance.now();
  return { res, ms: end - start };
}

export function DeviceAutoProbeController() {
  const prevLatency = useRef<number | null>(null);
  const running = useRef(false);

  useEffect(() => {
    let stopped = false;

    const runProbe = async () => {
      if (running.current || stopped) return;
      running.current = true;

      try {
        const info = getSessionInfo();

        const ping = await timedFetch(`${API_URL}/api/qoe/ping?x=${Date.now()}`);
        const latency = Number(ping.ms.toFixed(1));

        const jitter =
          prevLatency.current === null
            ? 0
            : Number(Math.abs(latency - prevLatency.current).toFixed(1));
        prevLatency.current = latency;

        const d0 = performance.now();
        const downloadRes = await fetch(`${API_URL}/api/qoe/download-fixed?size_kb=384&x=${Date.now()}`, {
          cache: "no-store",
        });
        const downloadBuffer = await downloadRes.arrayBuffer();
        const d1 = performance.now();
        const downloadSeconds = Math.max((d1 - d0) / 1000, 0.001);
        const downloadMbps = Number(((downloadBuffer.byteLength * 8) / downloadSeconds / 1_000_000).toFixed(2));

        const uploadPayload = new Uint8Array(96 * 1024);
        const u0 = performance.now();
        await fetch(`${API_URL}/api/qoe/upload?x=${Date.now()}`, {
          method: "POST",
          headers: { "Content-Type": "application/octet-stream" },
          body: uploadPayload,
          cache: "no-store",
        });
        const u1 = performance.now();
        const uploadSeconds = Math.max((u1 - u0) / 1000, 0.001);
        const uploadMbps = Number(((uploadPayload.byteLength * 8) / uploadSeconds / 1_000_000).toFixed(2));

        const packetLoss = !ping.res.ok || !downloadRes.ok ? 1.5 : 0;
        const qoeScore = scoreFrom(latency, jitter, downloadMbps, packetLoss);
        const status = statusFrom(qoeScore, latency, jitter, downloadMbps, packetLoss);
        const now = new Date();

        await fetch(`${API_URL}/api/qoe/device-sample`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          cache: "no-store",
          body: JSON.stringify({
            ...info,
            timestamp_epoch: Date.now(),
            time: now.toLocaleTimeString(),
            latency,
            jitter,
            downloadMbps,
            uploadMbps,
            throughput: downloadMbps,
            bandwidth: downloadMbps,
            packet_loss: packetLoss,
            qoeScore,
            qoe_score: qoeScore,
            status,
            streaming_status: status,
            source: "per-device-autoprobe-real-traffic",
          }),
        });

        window.dispatchEvent(
          new CustomEvent("aksara-device-autoprobe-sample", {
            detail: {
              ...info,
              latency,
              jitter,
              downloadMbps,
              uploadMbps,
              qoeScore,
              status,
            },
          })
        );
      } catch (err) {
        console.warn("AKSARA device autoprobe failed", err);
      } finally {
        running.current = false;
      }
    };

    runProbe();
    const interval = setInterval(runProbe, 4500);

    return () => {
      stopped = true;
      clearInterval(interval);
    };
  }, []);

  return null;
}
TSX

python3 <<PY
from pathlib import Path
p = Path("components/device-autoprobe-controller.tsx")
s = p.read_text().replace("__API_URL__", "$API_URL")
p.write_text(s)
print("✅ DeviceAutoProbeController patched")
PY

echo "=================================================="
echo "3. INJECT AUTO PROBE INTO LAYOUT"
echo "=================================================="

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
print("✅ auto probe injected")
PY

echo "=================================================="
echo "4. FORCE RECHARTS HEIGHT FIX"
echo "=================================================="

python3 <<'PY'
from pathlib import Path
import re

targets = list(Path("app").rglob("*.tsx")) + list(Path("components").rglob("*.tsx"))
changed = 0

for p in targets:
    if "node_modules" in str(p) or ".next" in str(p):
        continue

    s = p.read_text()
    old = s

    s = s.replace(
        '<ResponsiveContainer width="100%" height="100%">',
        '<ResponsiveContainer width="100%" height={360}>'
    )
    s = s.replace(
        "<ResponsiveContainer width='100%' height='100%'>",
        "<ResponsiveContainer width='100%' height={360}>"
    )

    s = re.sub(
        r'(<ResponsiveContainer\b[^>]*?)height=["\']100%["\']([^>]*>)',
        r'\1height={360}\2',
        s
    )

    s = re.sub(
        r'(<ResponsiveContainer\b(?![^>]*height=)[^>]*width=["\']100%["\'][^>]*>)',
        lambda m: m.group(1).replace(">", " height={360}>"),
        s
    )

    if s != old:
        p.write_text(s)
        changed += 1
        print("patched", p)

print("changed files:", changed)
PY

cat >> app/globals.css <<'CSS'

/* Chart hardening: prevents Recharts width(-1)/height(-1) */
.recharts-responsive-container {
  min-width: 280px !important;
  min-height: 320px !important;
}

.recharts-wrapper {
  min-width: 280px !important;
  min-height: 320px !important;
}

.recharts-surface {
  overflow: visible;
}

[data-chart-frame],
.aksara-chart-frame,
.chart-frame {
  min-height: 360px !important;
  height: auto !important;
}

html::after {
  content: "Device auto probe active";
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
CSS

echo "=================================================="
echo "DONE"
echo "=================================================="
