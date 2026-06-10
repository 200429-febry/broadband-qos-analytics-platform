export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

function csvEscape(value) {
  const s = String(value ?? "");
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

async function getJson(path, fallback) {
  try {
    const res = await fetch(API_URL + path, { cache: "no-store" });
    if (!res.ok) return fallback;
    return await res.json();
  } catch {
    return fallback;
  }
}

export async function GET() {
  const metrics = await getJson("/api/qos/metrics", {});
  const history = await getJson("/api/qos/history", []);
  const alerts = await getJson("/api/alerts", []);

  const rows = [];
  rows.push(["AKSARA UNION QoE Analytics Platform"]);
  rows.push(["Report Type", "SLA / KPI Technical CSV Export"]);
  rows.push(["Generated At", new Date().toLocaleString()]);
  rows.push(["Telemetry Source", metrics.source || "real-qoe-probe"]);
  rows.push(["Current Status", metrics.streaming_status || metrics.status || "WAITING"]);
  rows.push(["QoE Score", metrics.qoe_score || metrics.qoeScore || 0]);
  rows.push(["Active Alerts", Array.isArray(alerts) ? alerts.length : 0]);
  rows.push([]);

  rows.push(["Timestamp", "Throughput Mbps", "Latency ms", "Jitter ms", "Packet Loss %", "QoE Score", "Status", "Source"]);

  if (Array.isArray(history)) {
    for (const row of history) {
      rows.push([
        row.timestamp || row.time || "-",
        row.throughput || row.downloadMbps || row.bandwidth || 0,
        row.latency || 0,
        row.jitter || 0,
        row.packet_loss || row.packetLoss || 0,
        row.qoe_score || row.qoeScore || 0,
        row.streaming_status || row.status || "",
        row.source || "real-qoe-probe",
      ]);
    }
  }

  rows.push([]);
  rows.push(["Active Alert Table"]);
  rows.push(["Type", "Message", "Metric", "Time", "Source"]);

  if (Array.isArray(alerts)) {
    for (const alert of alerts) {
      rows.push([
        alert.type || "",
        alert.message || "",
        alert.metric || "",
        alert.time || "",
        alert.source || "",
      ]);
    }
  }

  const csv = rows.map((r) => r.map(csvEscape).join(",")).join("\n");

  return new Response(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="AKSARA_QoE_SLA_Report_${new Date().toISOString().slice(0,10)}.csv"`,
      "Cache-Control": "no-store",
    },
  });
}
