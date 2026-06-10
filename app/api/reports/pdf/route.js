export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";
const PROJECT_ID = "gen-lang-client-0341860128";
const REGION = "asia-southeast2";

async function getJson(path, fallback) {
  try {
    const res = await fetch(API_URL + path, { cache: "no-store" });
    if (!res.ok) return fallback;
    return await res.json();
  } catch {
    return fallback;
  }
}

function clean(value) {
  return String(value ?? "")
    .replace(/[^\x09\x0A\x0D\x20-\x7E]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function esc(value) {
  return clean(value).replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");
}

function num(v, d = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : d;
}

function wrap(text, max = 88) {
  const words = clean(text).split(" ");
  const lines = [];
  let line = "";
  for (const w of words) {
    if ((line + " " + w).trim().length > max) {
      if (line) lines.push(line);
      line = w;
    } else {
      line = (line + " " + w).trim();
    }
  }
  if (line) lines.push(line);
  return lines;
}

function pdfText(x, y, size, text) {
  const yy = 842 - y;
  return `BT /F1 ${size} Tf ${x} ${yy} Td (${esc(text)}) Tj ET\n`;
}

function pdfRect(x, y, w, h, gray = 0.92) {
  const yy = 842 - y - h;
  return `q ${gray} g ${x} ${yy} ${w} ${h} re f Q\n`;
}

function pdfStrokeRect(x, y, w, h, r = 0.75, g = 0.8, b = 0.9) {
  const yy = 842 - y - h;
  return `q ${r} ${g} ${b} RG 0.8 w ${x} ${yy} ${w} ${h} re S Q\n`;
}

function addHeader(title) {
  let c = "";
  c += `q 0.03 0.06 0.12 rg 0 742 595 100 re f Q\n`;
  c += pdfText(42, 54, 9, "AKSARA UNION QoS ANALYTICS PLATFORM");
  c += pdfText(42, 82, 22, title);
  c += pdfText(42, 106, 9, `Project ${PROJECT_ID} | Region ${REGION} | Server-side technical export`);
  c += `q 0.1 0.6 0.8 RG 1.2 w 42 720 511 0 m S Q\n`;
  return c;
}

function addFooter(page, total) {
  let c = "";
  c += `q 0.8 0.85 0.9 RG 0.6 w 42 54 511 0 m S Q\n`;
  c += pdfText(42, 798, 8, `AKSARA UNION - Real Browser-to-Cloud QoE Telemetry | Page ${page} of ${total}`);
  return c;
}

function card(x, y, w, h, label, value, sub) {
  let c = "";
  c += pdfRect(x, y, w, h, 0.97);
  c += pdfStrokeRect(x, y, w, h);
  c += pdfText(x + 10, y + 22, 8, label);
  c += pdfText(x + 10, y + 48, 16, value);
  c += pdfText(x + 10, y + 68, 8, sub);
  return c;
}

function paragraph(x, y, text, max = 95, lineH = 13, size = 9) {
  let c = "";
  const lines = wrap(text, max);
  lines.forEach((line, i) => c += pdfText(x, y + i * lineH, size, line));
  return { content: c, height: lines.length * lineH };
}

function buildPdf(pages) {
  const objects = [];
  const addObj = (body) => {
    objects.push(body);
    return objects.length;
  };

  const catalogId = addObj("");
  const pagesId = addObj("");
  const fontId = addObj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");

  const pageIds = [];

  for (const content of pages) {
    const stream = Buffer.from(content, "utf8");
    const contentId = addObj(`<< /Length ${stream.length} >>\nstream\n${content}\nendstream`);
    const pageId = addObj(`<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 ${fontId} 0 R >> >> /Contents ${contentId} 0 R >>`);
    pageIds.push(pageId);
  }

  objects[catalogId - 1] = `<< /Type /Catalog /Pages ${pagesId} 0 R >>`;
  objects[pagesId - 1] = `<< /Type /Pages /Kids [${pageIds.map(id => `${id} 0 R`).join(" ")}] /Count ${pageIds.length} >>`;

  let pdf = "%PDF-1.4\n";
  const offsets = [0];

  objects.forEach((obj, i) => {
    offsets.push(Buffer.byteLength(pdf, "utf8"));
    pdf += `${i + 1} 0 obj\n${obj}\nendobj\n`;
  });

  const xrefOffset = Buffer.byteLength(pdf, "utf8");
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  offsets.slice(1).forEach((off) => {
    pdf += String(off).padStart(10, "0") + " 00000 n \n";
  });

  pdf += `trailer\n<< /Size ${objects.length + 1} /Root ${catalogId} 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`;
  return Buffer.from(pdf, "utf8");
}

export async function GET() {
  const metrics = await getJson("/api/qos/metrics", {});
  const history = await getJson("/api/qos/history", []);
  const alerts = await getJson("/api/alerts", []);

  const rows = Array.isArray(history) ? history.slice(0, 18) : [];
  const alertRows = Array.isArray(alerts) ? alerts.slice(0, 10) : [];

  const throughput = num(metrics.throughput || metrics.downloadMbps || metrics.bandwidth);
  const latency = num(metrics.latency);
  const jitter = num(metrics.jitter);
  const loss = num(metrics.packet_loss || metrics.packetLoss);
  const qoe = num(metrics.qoe_score || metrics.qoeScore);
  const status = metrics.streaming_status || metrics.status || "WAITING";

  const avgThroughput = rows.length ? rows.reduce((s, r) => s + num(r.throughput || r.downloadMbps || r.bandwidth), 0) / rows.length : 0;
  const avgLatency = rows.length ? rows.reduce((s, r) => s + num(r.latency), 0) / rows.length : 0;
  const avgJitter = rows.length ? rows.reduce((s, r) => s + num(r.jitter), 0) / rows.length : 0;
  const maxLatency = rows.length ? Math.max(...rows.map(r => num(r.latency))) : 0;
  const minThroughput = rows.length ? Math.min(...rows.map(r => num(r.throughput || r.downloadMbps || r.bandwidth))) : 0;

  const pages = [];

  let p1 = addHeader("Carrier-Grade QoE / SLA Technical Report");
  p1 += card(42, 145, 155, 58, "Generated At", new Date().toLocaleString(), "Server-side PDF report");
  p1 += card(220, 145, 155, 58, "Telemetry Source", metrics.source || "real-qoe-probe", "Live probe source");
  p1 += card(398, 145, 155, 58, "Current Status", status, "QoE classification");
  p1 += card(42, 220, 155, 58, "QoE Score", `${qoe.toFixed(0)} / 100`, "Streaming experience index");
  p1 += card(220, 220, 155, 58, "Active Alerts", `${alertRows.length}`, "Threshold events");
  p1 += card(398, 220, 155, 58, "Sample Window", `${rows.length}`, "Latest telemetry samples");
  p1 += pdfText(42, 318, 15, "Executive Summary");
  let para = paragraph(
    42,
    342,
    `This report summarizes the current state of the AKSARA QoE Analytics Platform using real browser-to-Cloud Run telemetry. The platform measures throughput, latency, jitter, packet loss, QoE score, active alert condition, and service runtime evidence. The current implementation is based on Cloud Run, FastAPI, Next.js, Cloud SQL, BigQuery, Pub/Sub, and a custom dashboard layer. Components such as GKE, Vertex AI, RTMP streaming, Prometheus, Grafana, and Alertmanager are treated as future enhancements, not active production dependencies.`,
    103,
    14,
    9
  );
  p1 += para.content;
  p1 += pdfText(42, 470, 15, "Live KPI Snapshot");
  p1 += card(42, 492, 155, 58, "Throughput", `${throughput.toFixed(2)} Mbps`, "Current downlink probe");
  p1 += card(220, 492, 155, 58, "Latency", `${latency.toFixed(1)} ms`, "Browser-to-Cloud RTT");
  p1 += card(398, 492, 155, 58, "Jitter", `${jitter.toFixed(1)} ms`, "Latency variation");
  p1 += card(42, 565, 155, 58, "Packet Loss", `${loss.toFixed(2)} %`, "Probe failure ratio");
  p1 += card(220, 565, 155, 58, "Average Throughput", `${avgThroughput.toFixed(2)} Mbps`, "Measurement window");
  p1 += card(398, 565, 155, 58, "Average Latency", `${avgLatency.toFixed(1)} ms`, "Measurement window");
  p1 += addFooter(1, 4);
  pages.push(p1);

  let p2 = addHeader("Production Architecture and Data Flow");
  p2 += pdfText(42, 145, 15, "Active Runtime Stack");
  const arch = [
    ["Client / Streaming Scenario", "Browser, YouTube or streaming workload, real QoE probe"],
    ["Cloud Run Frontend", "Next.js dashboard, reports, analytics, coverage, and evidence panels"],
    ["Cloud Run API", "FastAPI QoE endpoints, telemetry, alerts, users, reports, and coverage API"],
    ["Cloud SQL PostgreSQL", "Operational users, QoS metrics, predictions, audit records"],
    ["BigQuery + Pub/Sub", "Telemetry warehouse, stream ingestion, and analytical history"],
    ["ML Inference Service", "FastAPI prediction service for anomaly and QoS prediction"],
  ];
  let y = 175;
  for (const [name, desc] of arch) {
    p2 += pdfRect(42, y, 511, 48, 0.97);
    p2 += pdfStrokeRect(42, y, 511, 48);
    p2 += pdfText(58, y + 19, 11, name);
    p2 += pdfText(58, y + 37, 8, desc);
    y += 62;
  }
  p2 += pdfText(42, 575, 15, "Engineering Boundary");
  para = paragraph(
    42,
    600,
    "The current production system does not require a dedicated GKE cluster, external load balancer, internal RTMP/HLS server, managed Vertex AI endpoint, Prometheus, Grafana, or Alertmanager to operate. Those services remain valid future expansion options. The active project is intentionally cloud-native and lightweight, using Cloud Run services as the main compute layer.",
    103,
    14,
    9
  );
  p2 += para.content;
  p2 += addFooter(2, 4);
  pages.push(p2);

  let p3 = addHeader("SLA Risk Matrix and Alert Interpretation");
  p3 += pdfText(42, 145, 15, "Measurement Window Statistics");
  p3 += card(42, 170, 155, 58, "Average Throughput", `${avgThroughput.toFixed(2)} Mbps`, "Latest samples");
  p3 += card(220, 170, 155, 58, "Minimum Throughput", `${minThroughput.toFixed(2)} Mbps`, "Capacity floor");
  p3 += card(398, 170, 155, 58, "Average Jitter", `${avgJitter.toFixed(1)} ms`, "Stability indicator");
  p3 += card(42, 245, 155, 58, "Maximum Latency", `${maxLatency.toFixed(1)} ms`, "Worst RTT condition");
  p3 += card(220, 245, 155, 58, "Current QoE", `${qoe.toFixed(0)}`, "Experience score");
  p3 += card(398, 245, 155, 58, "Active Alerts", `${alertRows.length}`, "Risk events");
  p3 += pdfText(42, 345, 15, "Engineering Analysis");
  para = paragraph(
    42,
    370,
    `When latency and jitter increase while throughput decreases, the platform classifies the streaming session as unstable or at risk of buffering. Current status is ${status}. The recommended operational response is to compare the latest browser-to-Cloud Run telemetry with alert history, validate backend response time, and inspect whether throughput degradation is isolated to user access network or appears across multiple global samples.`,
    103,
    14,
    9
  );
  p3 += para.content;
  p3 += pdfText(42, 505, 15, "Active Alert Table");
  y = 532;
  p3 += pdfRect(42, y, 511, 22, 0.1);
  p3 += pdfText(50, y + 15, 8, "Type");
  p3 += pdfText(125, y + 15, 8, "Message");
  p3 += pdfText(345, y + 15, 8, "Metric");
  p3 += pdfText(440, y + 15, 8, "Source");
  y += 24;
  if (alertRows.length === 0) {
    p3 += pdfText(50, y + 15, 9, "No active alerts. Current telemetry is within normal operating thresholds.");
  } else {
    for (const a of alertRows) {
      p3 += pdfStrokeRect(42, y, 511, 28);
      p3 += pdfText(50, y + 17, 7, a.type || "-");
      p3 += pdfText(125, y + 17, 7, clean(a.message || "-").slice(0, 45));
      p3 += pdfText(345, y + 17, 7, clean(a.metric || "-").slice(0, 20));
      p3 += pdfText(440, y + 17, 7, clean(a.source || "-").slice(0, 23));
      y += 30;
    }
  }
  p3 += addFooter(3, 4);
  pages.push(p3);

  let p4 = addHeader("Raw Telemetry Window");
  y = 145;
  p4 += pdfRect(42, y, 511, 24, 0.1);
  p4 += pdfText(48, y + 16, 7, "Timestamp");
  p4 += pdfText(140, y + 16, 7, "Throughput");
  p4 += pdfText(225, y + 16, 7, "Latency");
  p4 += pdfText(300, y + 16, 7, "Jitter");
  p4 += pdfText(365, y + 16, 7, "Loss");
  p4 += pdfText(425, y + 16, 7, "QoE");
  p4 += pdfText(485, y + 16, 7, "Source");
  y += 26;
  for (const r of rows.slice(0, 18)) {
    p4 += pdfStrokeRect(42, y, 511, 24);
    p4 += pdfText(48, y + 16, 7, r.timestamp || r.time || "-");
    p4 += pdfText(140, y + 16, 7, `${num(r.throughput || r.downloadMbps || r.bandwidth).toFixed(2)} Mbps`);
    p4 += pdfText(225, y + 16, 7, `${num(r.latency).toFixed(1)} ms`);
    p4 += pdfText(300, y + 16, 7, `${num(r.jitter).toFixed(1)} ms`);
    p4 += pdfText(365, y + 16, 7, `${num(r.packet_loss || r.packetLoss).toFixed(2)}%`);
    p4 += pdfText(425, y + 16, 7, `${num(r.qoe_score || r.qoeScore).toFixed(0)}`);
    p4 += pdfText(485, y + 16, 7, clean(r.source || "probe").slice(0, 12));
    y += 25;
  }
  p4 += pdfText(42, 650, 15, "Conclusion");
  para = paragraph(
    42,
    675,
    "The report confirms that the platform operates as a Cloud Run-based QoE analytics system. The telemetry layer provides live service quality signals, the database and analytics layer stores operational evidence, and the dashboard/report layer converts the measurements into actionable SLA interpretation.",
    103,
    14,
    9
  );
  p4 += para.content;
  p4 += addFooter(4, 4);
  pages.push(p4);

  const pdf = buildPdf(pages);

  return new Response(pdf, {
    status: 200,
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `inline; filename="AKSARA_QoE_SLA_Technical_Report_${new Date().toISOString().slice(0,10)}.pdf"`,
      "Cache-Control": "no-store",
    },
  });
}
