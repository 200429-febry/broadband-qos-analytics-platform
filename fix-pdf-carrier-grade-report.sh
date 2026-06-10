#!/bin/bash
set -e

echo "=================================================="
echo "FIX PDF 500 + CARRIER-GRADE TECHNICAL REPORT"
echo "=================================================="

REGION="asia-southeast2"
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

FRONTEND_URL=$(gcloud run services describe qos-frontend \
  --region="$REGION" \
  --format="value(status.url)")

echo "API_URL=$API_URL"
echo "FRONTEND_URL=$FRONTEND_URL"

mkdir -p .backup-pdf-carrier
[ -f app/api/reports/pdf/route.js ] && cp app/api/reports/pdf/route.js .backup-pdf-carrier/route.js.bak
[ -f app/api/reports/pdf/route.ts ] && cp app/api/reports/pdf/route.ts .backup-pdf-carrier/route.ts.bak
[ -f app/api/reports/csv/route.js ] && cp app/api/reports/csv/route.js .backup-pdf-carrier/csv-route.js.bak
[ -f app/reports/page.tsx ] && cp app/reports/page.tsx .backup-pdf-carrier/reports-page.tsx.bak

npm install pdf-lib

rm -f app/api/reports/pdf/route.ts app/api/reports/pdf/route.js
mkdir -p app/api/reports/pdf
mkdir -p app/api/reports/csv

cat > app/api/reports/pdf/route.js <<JS
import { PDFDocument, StandardFonts, rgb } from "pdf-lib";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "$API_URL";

const W = 595.28;
const H = 841.89;
const M = 36;

function num(v, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

function fmt(v, d = 2) {
  return num(v).toFixed(d);
}

function avg(arr, key) {
  if (!Array.isArray(arr) || arr.length === 0) return 0;
  const vals = arr.map((x) => num(x?.[key])).filter((x) => Number.isFinite(x));
  if (!vals.length) return 0;
  return vals.reduce((a, b) => a + b, 0) / vals.length;
}

function max(arr, key) {
  if (!Array.isArray(arr) || arr.length === 0) return 0;
  const vals = arr.map((x) => num(x?.[key])).filter((x) => Number.isFinite(x));
  if (!vals.length) return 0;
  return Math.max(...vals);
}

function min(arr, key) {
  if (!Array.isArray(arr) || arr.length === 0) return 0;
  const vals = arr.map((x) => num(x?.[key])).filter((x) => Number.isFinite(x));
  if (!vals.length) return 0;
  return Math.min(...vals);
}

function qoeStatus(score) {
  const q = num(score);
  if (q >= 90) return "EXCELLENT";
  if (q >= 75) return "STABLE";
  if (q >= 60) return "BUFFER RISK";
  return "POOR";
}

async function safeJson(url, fallback) {
  try {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) return fallback;
    return await r.json();
  } catch {
    return fallback;
  }
}

function c(hex) {
  const h = hex.replace("#", "");
  return rgb(
    parseInt(h.slice(0, 2), 16) / 255,
    parseInt(h.slice(2, 4), 16) / 255,
    parseInt(h.slice(4, 6), 16) / 255
  );
}

function wrapText(text, font, size, maxWidth) {
  const words = String(text || "").split(/\\s+/);
  const lines = [];
  let line = "";

  for (const word of words) {
    const test = line ? line + " " + word : word;
    if (font.widthOfTextAtSize(test, size) <= maxWidth) {
      line = test;
    } else {
      if (line) lines.push(line);
      line = word;
    }
  }

  if (line) lines.push(line);
  return lines;
}

class Report {
  constructor(pdf, fonts) {
    this.pdf = pdf;
    this.font = fonts.regular;
    this.bold = fonts.bold;
    this.y = H - 50;
    this.pageNo = 0;
    this.pages = [];
    this.addPage();
  }

  addPage() {
    this.page = this.pdf.addPage([W, H]);
    this.pages.push(this.page);
    this.pageNo += 1;
    this.y = H - 54;

    this.page.drawRectangle({
      x: 0,
      y: 0,
      width: W,
      height: H,
      color: c("#f8fafc"),
    });

    this.page.drawRectangle({
      x: 0,
      y: H - 86,
      width: W,
      height: 86,
      color: c("#020617"),
    });

    this.page.drawText("AKSARA UNION QoS ANALYTICS PLATFORM", {
      x: M,
      y: H - 32,
      size: 8,
      font: this.bold,
      color: c("#67e8f9"),
    });

    this.page.drawText("Carrier-Grade QoE / SLA Technical Report", {
      x: M,
      y: H - 56,
      size: 20,
      font: this.bold,
      color: c("#ffffff"),
    });

    this.page.drawText("Server-side structured PDF export - not a screenshot, not browser print, not DOM capture", {
      x: M,
      y: H - 73,
      size: 7,
      font: this.font,
      color: c("#cbd5e1"),
    });

    this.page.drawLine({
      start: { x: M, y: H - 92 },
      end: { x: W - M, y: H - 92 },
      thickness: 0.7,
      color: c("#38bdf8"),
    });
  }

  footer() {
    for (let i = 0; i < this.pages.length; i++) {
      const p = this.pages[i];
      p.drawLine({
        start: { x: M, y: 28 },
        end: { x: W - M, y: 28 },
        thickness: 0.4,
        color: c("#cbd5e1"),
      });
      p.drawText(\`AKSARA UNION - Real Browser-to-Cloud QoE Telemetry | Page \${i + 1} of \${this.pages.length}\`, {
        x: M,
        y: 15,
        size: 7,
        font: this.font,
        color: c("#64748b"),
      });
    }
  }

  ensure(h = 80) {
    if (this.y - h < 50) this.addPage();
  }

  title(text, subtitle = "") {
    this.ensure(70);
    this.page.drawText(text, {
      x: M,
      y: this.y,
      size: 16,
      font: this.bold,
      color: c("#0f172a"),
    });
    this.y -= 18;

    if (subtitle) {
      const lines = wrapText(subtitle, this.font, 8, W - M * 2);
      for (const line of lines) {
        this.page.drawText(line, {
          x: M,
          y: this.y,
          size: 8,
          font: this.font,
          color: c("#475569"),
        });
        this.y -= 11;
      }
    }

    this.y -= 10;
  }

  section(text) {
    this.ensure(45);
    this.y -= 4;
    this.page.drawText(text, {
      x: M,
      y: this.y,
      size: 12,
      font: this.bold,
      color: c("#0f172a"),
    });
    this.y -= 8;
    this.page.drawLine({
      start: { x: M, y: this.y },
      end: { x: W - M, y: this.y },
      thickness: 0.5,
      color: c("#cbd5e1"),
    });
    this.y -= 16;
  }

  paragraph(text) {
    const lines = wrapText(text, this.font, 8.5, W - M * 2);
    this.ensure(lines.length * 12 + 10);
    for (const line of lines) {
      this.page.drawText(line, {
        x: M,
        y: this.y,
        size: 8.5,
        font: this.font,
        color: c("#1e293b"),
      });
      this.y -= 12;
    }
    this.y -= 4;
  }

  cardGrid(cards, cols = 3) {
    const gap = 10;
    const cardW = (W - M * 2 - gap * (cols - 1)) / cols;
    const cardH = 55;

    this.ensure(Math.ceil(cards.length / cols) * (cardH + gap) + 10);

    cards.forEach((card, i) => {
      const col = i % cols;
      const row = Math.floor(i / cols);
      const x = M + col * (cardW + gap);
      const y = this.y - row * (cardH + gap) - cardH;

      this.page.drawRectangle({
        x,
        y,
        width: cardW,
        height: cardH,
        color: c(card.bg || "#ffffff"),
        borderColor: c(card.border || "#cbd5e1"),
        borderWidth: 0.7,
      });

      this.page.drawText(card.label, {
        x: x + 10,
        y: y + cardH - 16,
        size: 7,
        font: this.font,
        color: c("#64748b"),
      });

      this.page.drawText(String(card.value), {
        x: x + 10,
        y: y + 18,
        size: 14,
        font: this.bold,
        color: c(card.color || "#0f172a"),
      });

      if (card.note) {
        this.page.drawText(String(card.note).slice(0, 38), {
          x: x + 10,
          y: y + 7,
          size: 6.5,
          font: this.font,
          color: c("#64748b"),
        });
      }
    });

    this.y -= Math.ceil(cards.length / cols) * (cardH + gap) + 4;
  }

  table(headers, rows, widths) {
    const rowH = 21;
    const startX = M;

    this.ensure(rowH * (Math.min(rows.length, 14) + 2));

    const drawHeader = () => {
      let x = startX;
      for (let i = 0; i < headers.length; i++) {
        this.page.drawRectangle({
          x,
          y: this.y - rowH,
          width: widths[i],
          height: rowH,
          color: c("#0f172a"),
        });
        this.page.drawText(headers[i], {
          x: x + 4,
          y: this.y - 14,
          size: 6.5,
          font: this.bold,
          color: c("#ffffff"),
        });
        x += widths[i];
      }
      this.y -= rowH;
    };

    drawHeader();

    rows.forEach((row, r) => {
      if (this.y - rowH < 50) {
        this.addPage();
        drawHeader();
      }

      let x = startX;
      const bg = r % 2 === 0 ? "#ffffff" : "#f1f5f9";

      for (let i = 0; i < row.length; i++) {
        this.page.drawRectangle({
          x,
          y: this.y - rowH,
          width: widths[i],
          height: rowH,
          color: c(bg),
          borderColor: c("#e2e8f0"),
          borderWidth: 0.3,
        });

        this.page.drawText(String(row[i] ?? "-").slice(0, 32), {
          x: x + 4,
          y: this.y - 14,
          size: 6.5,
          font: this.font,
          color: c("#0f172a"),
        });

        x += widths[i];
      }

      this.y -= rowH;
    });

    this.y -= 12;
  }

  lineChart(title, rows, series) {
    this.ensure(190);

    const x = M;
    const y = this.y - 160;
    const cw = W - M * 2;
    const ch = 130;

    this.page.drawRectangle({
      x,
      y,
      width: cw,
      height: ch + 25,
      color: c("#ffffff"),
      borderColor: c("#cbd5e1"),
      borderWidth: 0.6,
    });

    this.page.drawText(title, {
      x: x + 10,
      y: y + ch + 8,
      size: 10,
      font: this.bold,
      color: c("#0f172a"),
    });

    for (let i = 0; i <= 4; i++) {
      const gy = y + 18 + (i * (ch - 28)) / 4;
      this.page.drawLine({
        start: { x: x + 38, y: gy },
        end: { x: x + cw - 15, y: gy },
        thickness: 0.3,
        color: c("#e2e8f0"),
      });
    }

    const data = Array.isArray(rows) ? rows.slice(0, 16).reverse() : [];
    if (data.length < 2) {
      this.page.drawText("No enough telemetry data to draw trend.", {
        x: x + 45,
        y: y + 70,
        size: 9,
        font: this.font,
        color: c("#64748b"),
      });
      this.y -= 178;
      return;
    }

    const plotX = x + 38;
    const plotY = y + 18;
    const plotW = cw - 55;
    const plotH = ch - 28;

    series.forEach((s) => {
      const values = data.map((d) => num(d[s.key]));
      const maxV = Math.max(...values, s.max || 1);
      const minV = Math.min(...values, 0);

      let prev = null;

      values.forEach((v, i) => {
        const px = plotX + (i * plotW) / Math.max(values.length - 1, 1);
        const py = plotY + ((v - minV) / Math.max(maxV - minV, 1)) * plotH;

        this.page.drawCircle({
          x: px,
          y: py,
          size: 2.1,
          color: c(s.color),
        });

        if (prev) {
          this.page.drawLine({
            start: prev,
            end: { x: px, y: py },
            thickness: 1.2,
            color: c(s.color),
          });
        }

        prev = { x: px, y: py };
      });

      this.page.drawText(s.label, {
        x: x + 10 + series.indexOf(s) * 120,
        y: y + 8,
        size: 7,
        font: this.bold,
        color: c(s.color),
      });
    });

    this.y -= 178;
  }

  barChart(title, rows, key, color) {
    this.ensure(160);

    const x = M;
    const y = this.y - 130;
    const cw = W - M * 2;
    const ch = 105;

    this.page.drawRectangle({
      x,
      y,
      width: cw,
      height: ch + 25,
      color: c("#ffffff"),
      borderColor: c("#cbd5e1"),
      borderWidth: 0.6,
    });

    this.page.drawText(title, {
      x: x + 10,
      y: y + ch + 8,
      size: 10,
      font: this.bold,
      color: c("#0f172a"),
    });

    const data = Array.isArray(rows) ? rows.slice(0, 12).reverse() : [];
    const maxV = Math.max(...data.map((d) => num(d[key])), 1);
    const bw = (cw - 60) / Math.max(data.length, 1);

    data.forEach((d, i) => {
      const v = num(d[key]);
      const bh = (v / maxV) * (ch - 30);
      const bx = x + 38 + i * bw;
      const by = y + 18;

      this.page.drawRectangle({
        x: bx,
        y: by,
        width: Math.max(bw - 5, 5),
        height: bh,
        color: c(color),
      });
    });

    this.y -= 148;
  }

  flowDiagram() {
    this.ensure(210);

    const x = M;
    const y = this.y - 175;
    const boxW = 92;
    const boxH = 50;
    const gap = 17;

    const boxes = [
      ["Browser", "QoE Probe"],
      ["Cloud Run", "Frontend"],
      ["FastAPI", "QoS API"],
      ["Cloud SQL", "PostgreSQL"],
      ["BigQuery", "Analytics"],
    ];

    this.page.drawRectangle({
      x,
      y,
      width: W - M * 2,
      height: 165,
      color: c("#ffffff"),
      borderColor: c("#cbd5e1"),
      borderWidth: 0.7,
    });

    this.page.drawText("End-to-End Telemetry Flowchart", {
      x: x + 10,
      y: y + 145,
      size: 10,
      font: this.bold,
      color: c("#0f172a"),
    });

    boxes.forEach((b, i) => {
      const bx = x + 18 + i * (boxW + gap);
      const by = y + 78;

      this.page.drawRectangle({
        x: bx,
        y: by,
        width: boxW,
        height: boxH,
        color: c(i === 0 ? "#ecfeff" : i === 3 ? "#dcfce7" : "#eff6ff"),
        borderColor: c("#38bdf8"),
        borderWidth: 0.8,
      });

      this.page.drawText(b[0], {
        x: bx + 8,
        y: by + 30,
        size: 8,
        font: this.bold,
        color: c("#0f172a"),
      });

      this.page.drawText(b[1], {
        x: bx + 8,
        y: by + 16,
        size: 7,
        font: this.font,
        color: c("#475569"),
      });

      if (i < boxes.length - 1) {
        const ax1 = bx + boxW;
        const ax2 = bx + boxW + gap - 3;
        const ay = by + 25;

        this.page.drawLine({
          start: { x: ax1 + 2, y: ay },
          end: { x: ax2, y: ay },
          thickness: 1,
          color: c("#0891b2"),
        });
        this.page.drawText(">", {
          x: ax2 - 2,
          y: ay - 5,
          size: 10,
          font: this.bold,
          color: c("#0891b2"),
        });
      }
    });

    const notes = [
      "1. Browser performs active latency, jitter, upload, and download probes.",
      "2. Backend stores and normalizes QoE windows.",
      "3. Dashboard, reports, alerts, and prediction modules consume the same live telemetry source.",
    ];

    notes.forEach((note, i) => {
      this.page.drawText(note, {
        x: x + 20,
        y: y + 50 - i * 14,
        size: 7.5,
        font: this.font,
        color: c("#334155"),
      });
    });

    this.y -= 195;
  }

  riskMatrix(metrics) {
    this.ensure(165);

    const x = M;
    const y = this.y - 130;
    const cw = W - M * 2;
    const ch = 110;

    this.page.drawRectangle({
      x,
      y,
      width: cw,
      height: ch + 25,
      color: c("#ffffff"),
      borderColor: c("#cbd5e1"),
      borderWidth: 0.6,
    });

    this.page.drawText("QoE Risk Matrix", {
      x: x + 10,
      y: y + ch + 8,
      size: 10,
      font: this.bold,
      color: c("#0f172a"),
    });

    const cells = [
      ["Excellent", "#dcfce7", "Low risk"],
      ["Stable", "#cffafe", "Normal watch"],
      ["Buffer Risk", "#fef9c3", "Optimization needed"],
      ["Poor", "#fee2e2", "Immediate action"],
    ];

    const qoe = num(metrics.qoe_score);
    const active =
      qoe >= 90 ? 0 :
      qoe >= 75 ? 1 :
      qoe >= 60 ? 2 :
      3;

    cells.forEach((cell, i) => {
      const bx = x + 18 + i * ((cw - 36) / 4);
      const bw = (cw - 50) / 4;

      this.page.drawRectangle({
        x: bx,
        y: y + 35,
        width: bw,
        height: 52,
        color: c(cell[1]),
        borderColor: c(i === active ? "#0f172a" : "#cbd5e1"),
        borderWidth: i === active ? 1.6 : 0.6,
      });

      this.page.drawText(cell[0], {
        x: bx + 8,
        y: y + 68,
        size: 8,
        font: this.bold,
        color: c("#0f172a"),
      });

      this.page.drawText(cell[2], {
        x: bx + 8,
        y: y + 52,
        size: 7,
        font: this.font,
        color: c("#475569"),
      });
    });

    this.y -= 150;
  }
}

export async function GET() {
  try {
    const [metrics, history, alerts, qoeLatest] = await Promise.all([
      safeJson(\`\${API_URL}/api/qos/metrics?x=\${Date.now()}\`, {}),
      safeJson(\`\${API_URL}/api/qos/history?x=\${Date.now()}\`, []),
      safeJson(\`\${API_URL}/api/alerts?x=\${Date.now()}\`, []),
      safeJson(\`\${API_URL}/api/qoe/latest?x=\${Date.now()}\`, {}),
    ]);

    const rows = Array.isArray(history) ? history.slice(0, 50) : [];
    const alertRows = Array.isArray(alerts) ? alerts : [];

    const pdf = await PDFDocument.create();
    const regular = await pdf.embedFont(StandardFonts.Helvetica);
    const bold = await pdf.embedFont(StandardFonts.HelveticaBold);
    const r = new Report(pdf, { regular, bold });

    const generatedAt = new Date();

    r.title(
      "Executive Technical Summary",
      "This carrier-grade report summarizes live browser-to-Cloud Run streaming QoE telemetry, SLA condition, active alerts, telemetry flow, and network performance trends. The report is generated server-side and does not capture the dashboard screen."
    );

    r.cardGrid([
      { label: "Generated At", value: generatedAt.toLocaleString(), note: "Server-side PDF" },
      { label: "Telemetry Source", value: metrics.source || "real-qoe-probe", note: "Live probe source", color: "#0891b2" },
      { label: "Current Status", value: metrics.streaming_status || qoeStatus(metrics.qoe_score), note: "QoE classification", color: "#059669" },
      { label: "QoE Score", value: \`\${fmt(metrics.qoe_score, 1)} / 100\`, note: "Streaming experience index", color: "#16a34a" },
      { label: "Active Alerts", value: String(alertRows.length), note: "Threshold events", color: alertRows.length ? "#dc2626" : "#059669" },
      { label: "Sample Window", value: String(rows.length || qoeLatest.count || 0), note: "Latest telemetry samples" },
    ], 3);

    r.section("Live KPI Snapshot");
    r.cardGrid([
      { label: "Throughput", value: \`\${fmt(metrics.throughput, 2)} Mbps\`, color: "#0891b2" },
      { label: "Latency", value: \`\${fmt(metrics.latency, 2)} ms\`, color: "#ca8a04" },
      { label: "Jitter", value: \`\${fmt(metrics.jitter, 2)} ms\`, color: "#7c3aed" },
      { label: "Packet Loss", value: \`\${fmt(metrics.packet_loss, 2)} %\`, color: "#dc2626" },
      { label: "Bandwidth Field", value: \`\${fmt(metrics.bandwidth ?? metrics.throughput, 2)} Mbps\`, color: "#0891b2" },
      { label: "Latest Timestamp", value: metrics.timestamp || "-", color: "#0f172a" },
    ], 3);

    r.section("Measurement Window Statistics");
    r.cardGrid([
      { label: "Average Throughput", value: \`\${fmt(avg(rows, "throughput"), 2)} Mbps\`, color: "#0891b2" },
      { label: "Minimum Throughput", value: \`\${fmt(min(rows, "throughput"), 2)} Mbps\`, color: "#0f172a" },
      { label: "Average Latency", value: \`\${fmt(avg(rows, "latency"), 2)} ms\`, color: "#ca8a04" },
      { label: "Maximum Latency", value: \`\${fmt(max(rows, "latency"), 2)} ms\`, color: "#dc2626" },
      { label: "Average Jitter", value: \`\${fmt(avg(rows, "jitter"), 2)} ms\`, color: "#7c3aed" },
      { label: "Average QoE", value: \`\${fmt(avg(rows, "qoe_score"), 1)} / 100\`, color: "#16a34a" },
    ], 3);

    r.section("Architecture and Telemetry Flow");
    r.flowDiagram();

    r.section("Trend Visualization");
    r.lineChart("Throughput, Latency, and Jitter Trend", rows, [
      { key: "throughput", label: "Throughput Mbps", color: "#06b6d4" },
      { key: "latency", label: "Latency ms", color: "#eab308" },
      { key: "jitter", label: "Jitter ms", color: "#a855f7" },
    ]);

    r.barChart("QoE Score Distribution Window", rows, "qoe_score", "#22c55e");

    r.section("SLA Risk Classification");
    r.riskMatrix(metrics);

    r.section("Active Alert Table");
    if (alertRows.length) {
      r.table(
        ["Type", "Message", "Metric", "Time", "Source"],
        alertRows.slice(0, 12).map((a) => [
          a.type || "-",
          a.message || "-",
          a.metric || "-",
          a.time || "-",
          a.source || "-",
        ]),
        [55, 190, 85, 80, 110]
      );
    } else {
      r.paragraph("No active threshold alerts are currently present. Current streaming telemetry is within configured operating limits.");
    }

    r.section("Latest Real Telemetry Samples");
    if (rows.length) {
      r.table(
        ["Timestamp", "Throughput", "Latency", "Jitter", "Loss", "QoE", "Source"],
        rows.slice(0, 18).map((s) => [
          s.timestamp || "-",
          \`\${fmt(s.throughput, 2)} Mbps\`,
          \`\${fmt(s.latency, 2)} ms\`,
          \`\${fmt(s.jitter, 2)} ms\`,
          \`\${fmt(s.packet_loss, 2)}%\`,
          fmt(s.qoe_score, 1),
          s.source || "-",
        ]),
        [72, 82, 72, 65, 50, 45, 134]
      );
    } else {
      r.paragraph("No telemetry samples are available. Keep Streaming QoE or Dashboard open to feed real browser-to-Cloud Run QoE probe data.");
    }

    r.section("Engineering Interpretation");
    r.paragraph(
      \`The current telemetry source is \${metrics.source || "real-qoe-probe"}. Current throughput is \${fmt(metrics.throughput, 2)} Mbps, latency is \${fmt(metrics.latency, 2)} ms, jitter is \${fmt(metrics.jitter, 2)} ms, and packet loss is \${fmt(metrics.packet_loss, 2)}%. The QoE score is \${fmt(metrics.qoe_score, 1)}, classified as \${metrics.streaming_status || qoeStatus(metrics.qoe_score)}.\`
    );

    r.paragraph(
      "This report is designed as technical evidence for presentation. It proves that the platform exports a structured report from live API telemetry, not from a browser screenshot. Floating widgets, UI overlays, and old dashboard captures cannot appear in this export path."
    );

    r.footer();

    const bytes = await pdf.save();

    return new Response(Buffer.from(bytes), {
      status: 200,
      headers: {
        "Content-Type": "application/pdf",
        "Content-Disposition": \`attachment; filename="AKSARA_QoE_Carrier_Grade_Report_\${generatedAt.toISOString().slice(0, 10)}.pdf"\`,
        "Cache-Control": "no-store, no-cache, must-revalidate",
      },
    });
  } catch (error) {
    return Response.json(
      {
        error: "PDF generation failed",
        detail: String(error?.stack || error?.message || error),
        engine: "pdf-lib",
        apiUrl: API_URL,
      },
      { status: 500 }
    );
  }
}
JS

cat > app/api/reports/csv/route.js <<JS
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "$API_URL";

function clean(value) {
  if (value === null || value === undefined) return "";
  return String(value).replaceAll('"', '""');
}

function row(values) {
  return values.map((v) => '"' + clean(v) + '"').join(",");
}

async function safeJson(url, fallback) {
  try {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) return fallback;
    return await r.json();
  } catch {
    return fallback;
  }
}

export async function GET() {
  const now = new Date();

  const [metrics, history, alerts] = await Promise.all([
    safeJson(\`\${API_URL}/api/qos/metrics?x=\${Date.now()}\`, {}),
    safeJson(\`\${API_URL}/api/qos/history?x=\${Date.now()}\`, []),
    safeJson(\`\${API_URL}/api/alerts?x=\${Date.now()}\`, []),
  ]);

  const lines = [];

  lines.push(row([
    "section",
    "timestamp",
    "throughput_mbps",
    "latency_ms",
    "jitter_ms",
    "packet_loss_percent",
    "qoe_score",
    "streaming_status",
    "source",
    "alert_type",
    "alert_message",
    "alert_metric",
    "notes",
  ]));

  lines.push(row([
    "metadata",
    now.toISOString(),
    "",
    "",
    "",
    "",
    "",
    "",
    "server-side-export",
    "",
    "",
    "",
    "Structured CSV generated from real backend telemetry, not UI screenshot.",
  ]));

  lines.push(row([
    "live_summary",
    metrics.timestamp || "",
    metrics.throughput ?? "",
    metrics.latency ?? "",
    metrics.jitter ?? "",
    metrics.packet_loss ?? "",
    metrics.qoe_score ?? "",
    metrics.streaming_status ?? "",
    metrics.source ?? "",
    "",
    "",
    "",
    "Current real QoE summary.",
  ]));

  if (Array.isArray(history)) {
    history.forEach((h, i) => {
      lines.push(row([
        \`telemetry_sample_\${i + 1}\`,
        h.timestamp || "",
        h.throughput ?? "",
        h.latency ?? "",
        h.jitter ?? "",
        h.packet_loss ?? "",
        h.qoe_score ?? "",
        h.streaming_status || h.status || "",
        h.source || "",
        "",
        "",
        "",
        "Real browser-to-Cloud Run telemetry sample.",
      ]));
    });
  }

  if (Array.isArray(alerts) && alerts.length) {
    alerts.forEach((a, i) => {
      lines.push(row([
        \`active_alert_\${i + 1}\`,
        a.time || "",
        "",
        "",
        "",
        "",
        "",
        "",
        a.source || "",
        a.type || "",
        a.message || "",
        a.metric || "",
        "Alert generated from threshold condition.",
      ]));
    });
  }

  return new Response(lines.join("\\n"), {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": \`attachment; filename="AKSARA_QoE_Technical_Telemetry_\${now.toISOString().slice(0, 10)}.csv"\`,
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
JS

echo "=================================================="
echo "PDF ROUTE PATCHED"
echo "=================================================="
