export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

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
