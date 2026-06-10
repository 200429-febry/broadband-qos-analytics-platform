#!/bin/bash
set -e

echo "=================================================="
echo "FIX EMPTY CHART: DEVICE SESSION WITH SAFE FALLBACK"
echo "=================================================="

REGION="asia-southeast2"
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

echo "API_URL=$API_URL"

mkdir -p .backup-chart-empty-fix
[ -f app/api/qos-history/route.js ] && cp app/api/qos-history/route.js .backup-chart-empty-fix/qos-history.route.js.bak
[ -f app/api/qos-metrics/route.js ] && cp app/api/qos-metrics/route.js .backup-chart-empty-fix/qos-metrics.route.js.bak
[ -f app/api/qos-alerts/route.js ] && cp app/api/qos-alerts/route.js .backup-chart-empty-fix/qos-alerts.route.js.bak

mkdir -p app/api/qos-history app/api/qos-metrics app/api/qos-alerts app/api/debug-device-session

cat > app/api/qos-history/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

async function getJson(url, fallback) {
  try {
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) return fallback;
    return await res.json();
  } catch {
    return fallback;
  }
}

export async function GET(req) {
  const url = new URL(req.url);
  const sessionId = url.searchParams.get("session_id") || "";
  const limit = url.searchParams.get("limit") || "80";

  let data = [];

  if (sessionId) {
    data = await getJson(
      API_URL +
        "/api/qoe/device-history?session_id=" +
        encodeURIComponent(sessionId) +
        "&limit=" +
        encodeURIComponent(limit),
      []
    );
  }

  if (!Array.isArray(data) || data.length === 0) {
    data = await getJson(API_URL + "/api/qos/history", []);
    if (Array.isArray(data)) {
      data = data.map((x) => ({
        ...x,
        session_mode: sessionId ? "fallback-global-until-current-device-has-samples" : "global",
      }));
    }
  }

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

async function getJson(url, fallback) {
  try {
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) return fallback;
    return await res.json();
  } catch {
    return fallback;
  }
}

function isEmptyMetric(data) {
  if (!data) return true;
  const source = String(data.source || "");
  const status = String(data.streaming_status || data.status || "");
  const t = Number(data.throughput || data.downloadMbps || 0);
  const l = Number(data.latency || 0);
  return source.includes("waiting") || status === "WAITING" || (t === 0 && l === 0);
}

export async function GET(req) {
  const url = new URL(req.url);
  const sessionId = url.searchParams.get("session_id") || "";

  let data = null;

  if (sessionId) {
    data = await getJson(
      API_URL + "/api/qoe/device-metrics?session_id=" + encodeURIComponent(sessionId),
      null
    );
  }

  if (isEmptyMetric(data)) {
    data = await getJson(API_URL + "/api/qos/metrics", {});
    data = {
      ...data,
      session_mode: sessionId ? "fallback-global-until-current-device-has-samples" : "global",
    };
  }

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

async function getJson(url, fallback) {
  try {
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) return fallback;
    return await res.json();
  } catch {
    return fallback;
  }
}

export async function GET(req) {
  const url = new URL(req.url);
  const sessionId = url.searchParams.get("session_id") || "";

  let data = [];

  if (sessionId) {
    data = await getJson(
      API_URL + "/api/qoe/device-alerts?session_id=" + encodeURIComponent(sessionId),
      []
    );
  }

  if (!Array.isArray(data) || data.length === 0) {
    data = await getJson(API_URL + "/api/alerts", []);
  }

  return Response.json(Array.isArray(data) ? data : [], {
    headers: { "Cache-Control": "no-store" },
  });
}
JS

cat > app/api/debug-device-session/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

async function getJson(url, fallback) {
  try {
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) return fallback;
    return await res.json();
  } catch {
    return fallback;
  }
}

export async function GET(req) {
  const url = new URL(req.url);
  const sessionId = url.searchParams.get("session_id") || "";

  const deviceSessions = await getJson(API_URL + "/api/qoe/device-sessions", {});
  const deviceHistory = sessionId
    ? await getJson(API_URL + "/api/qoe/device-history?session_id=" + encodeURIComponent(sessionId) + "&limit=5", [])
    : [];

  const globalHistory = await getJson(API_URL + "/api/qos/history", []);

  return Response.json({
    session_id: sessionId || null,
    device_sessions: deviceSessions,
    current_device_history_count: Array.isArray(deviceHistory) ? deviceHistory.length : 0,
    current_device_history_preview: deviceHistory,
    global_history_count: Array.isArray(globalHistory) ? globalHistory.length : 0,
    mode_explanation:
      "If current_device_history_count is 0, chart will temporarily use global fallback until this browser sends /api/qoe/device-sample.",
  }, {
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
  "app/api/debug-device-session/route.js",
]:
    p = Path(f)
    s = p.read_text().replace("__API_URL__", "$API_URL")
    p.write_text(s)
    print("patched", f)
PY

echo "=================================================="
echo "DONE"
echo "=================================================="
