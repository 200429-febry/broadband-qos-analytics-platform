#!/bin/bash
set -e

echo "=================================================="
echo "FIX PDF REPORT: CLEAN LAYOUT + LONG TECHNICAL ANALYSIS"
echo "=================================================="

REGION="asia-southeast2"
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

PROJECT_ID=$(gcloud config get-value project)

echo "API_URL=$API_URL"
echo "PROJECT_ID=$PROJECT_ID"

mkdir -p .backup-pdf-clean-v2
[ -f app/api/reports/pdf/route.js ] && cp app/api/reports/pdf/route.js .backup-pdf-clean-v2/route.js.bak
[ -f app/api/reports/pdf/route.ts ] && cp app/api/reports/pdf/route.ts .backup-pdf-clean-v2/route.ts.bak

npm install pdf-lib

rm -f app/api/reports/pdf/route.ts
mkdir -p app/api/reports/pdf

cat > app/api/reports/pdf/route.js <<'JS'
import { PDFDocument, StandardFonts, rgb } from "pdf-lib";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";
const PROJECT_ID = "__PROJECT_ID__";
const REGION = "asia-southeast2";

const PAGE_W = 595.28;
const PAGE_H = 841.89;
const M = 42;

function color(hex) {
  const h = hex.replace("#", "");
  return rgb(
    parseInt(h.slice(0, 2), 16) / 255,
    parseInt(h.slice(2, 4), 16) / 255,
    parseInt(h.slice(4, 6), 16) / 255
  );
}

function num(v, fallback = 0) {
  const x = Number(v);
  return Number.isFinite(x) ? x : fallback;
}

function fmt(v, d = 2) {
  return num(v).toFixed(d);
}

function avg(arr, key) {
  if (!Array.isArray(arr) || arr.length === 0) return 0;
  const values = arr.map((x) => num(x?.[key])).filter(Number.isFinite);
  if (!values.length) return 0;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function min(arr, key) {
  if (!Array.isArray(arr) || arr.length === 0) return 0;
  const values = arr.map((x) => num(x?.[key])).filter(Number.isFinite);
  if (!values.length) return 0;
  return Math.min(...values);
}

function max(arr, key) {
  if (!Array.isArray(arr) || arr.length === 0) return 0;
  const values = arr.map((x) => num(x?.[key])).filter(Number.isFinite);
  if (!values.length) return 0;
  return Math.max(...values);
}

function stddev(arr, key) {
  if (!Array.isArray(arr) || arr.length < 2) return 0;
  const mean = avg(arr, key);
  const values = arr.map((x) => num(x?.[key])).filter(Number.isFinite);
  const variance = values.reduce((s, v) => s + Math.pow(v - mean, 2), 0) / values.length;
  return Math.sqrt(variance);
}

function statusFromQoe(score) {
  const q = num(score);
  if (q >= 90) return "EXCELLENT";
  if (q >= 75) return "STABLE";
  if (q >= 60) return "BUFFER RISK";
  return "POOR";
}

function riskColor(status) {
  if (status === "EXCELLENT") return "#16a34a";
  if (status === "STABLE") return "#0891b2";
  if (status === "BUFFER RISK") return "#d97706";
  return "#dc2626";
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

function wrapText(text, font, size, width) {
  const raw = String(text || "").replace(/\s+/g, " ").trim();
  if (!raw) return [];

  const words = raw.split(" ");
  const lines = [];
  let line = "";

  for (const word of words) {
    const trial = line ? `${line} ${word}` : word;
    if (font.widthOfTextAtSize(trial, size) <= width) {
      line = trial;
    } else {
      if (line) lines.push(line);
      line = word;
    }
  }

  if (line) lines.push(line);
  return lines;
}

class PdfWriter {
  constructor(pdf, fonts) {
    this.pdf = pdf;
    this.font = fonts.regular;
    this.bold = fonts.bold;
    this.pages = [];
    this.page = null;
    this.y = 0;
    this.pageNo = 0;
  }

  addPage(title = "AKSARA QoE / SLA Technical Report") {
    this.page = this.pdf.addPage([PAGE_W, PAGE_H]);
    this.pages.push(this.page);
    this.pageNo += 1;

    this.page.drawRectangle({
      x: 0,
      y: 0,
      width: PAGE_W,
      height: PAGE_H,
      color: color("#f8fafc"),
    });

    this.page.drawRectangle({
      x: 0,
      y: PAGE_H - 76,
      width: PAGE_W,
      height: 76,
      color: color("#020617"),
    });

    this.page.drawText("AKSARA UNION QoS ANALYTICS PLATFORM", {
      x: M,
      y: PAGE_H - 28,
      size: 8,
      font: this.bold,
      color: color("#67e8f9"),
    });

    this.page.drawText(title, {
      x: M,
      y: PAGE_H - 54,
      size: 18,
      font: this.bold,
      color: color("#ffffff"),
    });

    this.page.drawLine({
      start: { x: M, y: PAGE_H - 84 },
      end: { x: PAGE_W - M, y: PAGE_H - 84 },
      thickness: 0.6,
      color: color("#38bdf8"),
    });

    this.y = PAGE_H - 112;
  }

  cover(title, subtitle, meta) {
    this.page = this.pdf.addPage([PAGE_W, PAGE_H]);
    this.pages.push(this.page);
    this.pageNo += 1;

    this.page.drawRectangle({
      x: 0,
      y: 0,
      width: PAGE_W,
      height: PAGE_H,
      color: color("#020617"),
    });

    this.page.drawRectangle({
      x: 0,
      y: 0,
      width: PAGE_W,
      height: 260,
      color: color("#0f172a"),
    });

    this.page.drawText("AKSARA UNION", {
      x: M,
      y: PAGE_H - 95,
      size: 14,
      font: this.bold,
      color: color("#67e8f9"),
    });

    const titleLines = wrapText(title, this.bold, 28, PAGE_W - M * 2);
    let y = PAGE_H - 150;
    titleLines.forEach((line) => {
      this.page.drawText(line, {
        x: M,
        y,
        size: 28,
        font: this.bold,
        color: color("#ffffff"),
      });
      y -= 35;
    });

    const subLines = wrapText(subtitle, this.font, 10, PAGE_W - M * 2);
    y -= 10;
    subLines.forEach((line) => {
      this.page.drawText(line, {
        x: M,
        y,
        size: 10,
        font: this.font,
        color: color("#cbd5e1"),
      });
      y -= 15;
    });

    const boxY = 350;
    this.page.drawRectangle({
      x: M,
      y: boxY,
      width: PAGE_W - M * 2,
      height: 190,
      color: color("#0b1220"),
      borderColor: color("#1e293b"),
      borderWidth: 1,
    });

    let my = boxY + 150;
    meta.forEach(([k, v]) => {
      this.page.drawText(k, {
        x: M + 22,
        y: my,
        size: 9,
        font: this.font,
        color: color("#94a3b8"),
      });
      this.page.drawText(String(v), {
        x: M + 170,
        y: my,
        size: 10,
        font: this.bold,
        color: color("#ffffff"),
      });
      my -= 28;
    });

    this.page.drawText("Structured server-side PDF export. No screenshot capture. No floating UI overlay.", {
      x: M,
      y: 95,
      size: 9,
      font: this.bold,
      color: color("#67e8f9"),
    });

    this.page.drawText("This report is generated from live backend telemetry endpoints and is suitable for technical verification, operational review, and project demonstration.", {
      x: M,
      y: 75,
      size: 8,
      font: this.font,
      color: color("#cbd5e1"),
    });
  }

  ensure(height = 70) {
    if (!this.page || this.y - height < 62) {
      this.addPage();
    }
  }

  section(title, subtitle = "") {
    this.ensure(58);
    this.page.drawText(title, {
      x: M,
      y: this.y,
      size: 15,
      font: this.bold,
      color: color("#0f172a"),
    });
    this.y -= 18;

    if (subtitle) {
      const lines = wrapText(subtitle, this.font, 8.5, PAGE_W - M * 2);
      lines.forEach((line) => {
        this.page.drawText(line, {
          x: M,
          y: this.y,
          size: 8.5,
          font: this.font,
          color: color("#475569"),
        });
        this.y -= 12;
      });
    }

    this.page.drawLine({
      start: { x: M, y: this.y - 2 },
      end: { x: PAGE_W - M, y: this.y - 2 },
      thickness: 0.4,
      color: color("#cbd5e1"),
    });
    this.y -= 18;
  }

  paragraph(text, size = 8.7) {
    const lines = wrapText(text, this.font, size, PAGE_W - M * 2);
    this.ensure(lines.length * 12 + 20);

    lines.forEach((line) => {
      this.page.drawText(line, {
        x: M,
        y: this.y,
        size,
        font: this.font,
        color: color("#1e293b"),
      });
      this.y -= 12;
    });

    this.y -= 6;
  }

  bullet(items) {
    items.forEach((item) => {
      const lines = wrapText(item, this.font, 8.4, PAGE_W - M * 2 - 18);
      this.ensure(lines.length * 12 + 8);

      this.page.drawText("•", {
        x: M,
        y: this.y,
        size: 10,
        font: this.bold,
        color: color("#0891b2"),
      });

      lines.forEach((line, idx) => {
        this.page.drawText(line, {
          x: M + 16,
          y: this.y,
          size: 8.4,
          font: this.font,
          color: color("#1e293b"),
        });
        if (idx < lines.length - 1) this.y -= 12;
      });

      this.y -= 15;
    });

    this.y -= 2;
  }

  cards(cards, cols = 3) {
    const gap = 10;
    const cardW = (PAGE_W - M * 2 - gap * (cols - 1)) / cols;
    const cardH = 64;
    const rows = Math.ceil(cards.length / cols);

    this.ensure(rows * (cardH + gap) + 10);

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
        color: color("#ffffff"),
        borderColor: color(card.border || "#cbd5e1"),
        borderWidth: 0.7,
      });

      this.page.drawText(String(card.label), {
        x: x + 10,
        y: y + cardH - 18,
        size: 7,
        font: this.font,
        color: color("#64748b"),
      });

      this.page.drawText(String(card.value), {
        x: x + 10,
        y: y + 25,
        size: 13,
        font: this.bold,
        color: color(card.color || "#0f172a"),
      });

      if (card.note) {
        const noteLines = wrapText(card.note, this.font, 6.5, cardW - 20).slice(0, 1);
        noteLines.forEach((line) => {
          this.page.drawText(line, {
            x: x + 10,
            y: y + 10,
            size: 6.5,
            font: this.font,
            color: color("#64748b"),
          });
        });
      }
    });

    this.y -= rows * (cardH + gap) + 4;
  }

  table(headers, rows, widths, maxRows = 22) {
    const rowH = 22;
    const headerH = 23;
    const visible = rows.slice(0, maxRows);

    this.ensure(headerH + visible.length * rowH + 25);

    const drawHeader = () => {
      let x = M;
      this.page.drawRectangle({
        x: M,
        y: this.y - headerH,
        width: PAGE_W - M * 2,
        height: headerH,
        color: color("#0f172a"),
      });

      headers.forEach((h, i) => {
        this.page.drawText(h, {
          x: x + 5,
          y: this.y - 15,
          size: 6.8,
          font: this.bold,
          color: color("#ffffff"),
        });
        x += widths[i];
      });

      this.y -= headerH;
    };

    drawHeader();

    visible.forEach((row, r) => {
      if (this.y - rowH < 62) {
        this.addPage();
        drawHeader();
      }

      let x = M;
      const bg = r % 2 === 0 ? "#ffffff" : "#eef2f7";

      this.page.drawRectangle({
        x: M,
        y: this.y - rowH,
        width: PAGE_W - M * 2,
        height: rowH,
        color: color(bg),
        borderColor: color("#dbe4ee"),
        borderWidth: 0.25,
      });

      row.forEach((cell, i) => {
        this.page.drawText(String(cell ?? "-").slice(0, 34), {
          x: x + 5,
          y: this.y - 14,
          size: 6.6,
          font: this.font,
          color: color("#0f172a"),
        });
        x += widths[i];
      });

      this.y -= rowH;
    });

    if (rows.length > maxRows) {
      this.page.drawText(`Table truncated in preview: showing ${maxRows} of ${rows.length} records. Full data is available in CSV export and API endpoint.`, {
        x: M,
        y: this.y - 10,
        size: 7,
        font: this.font,
        color: color("#64748b"),
      });
      this.y -= 20;
    } else {
      this.y -= 12;
    }
  }

  lineChart(title, rows, series) {
    this.ensure(190);

    const x = M;
    const y = this.y - 160;
    const w = PAGE_W - M * 2;
    const h = 135;

    this.page.drawRectangle({
      x,
      y,
      width: w,
      height: h + 26,
      color: color("#ffffff"),
      borderColor: color("#cbd5e1"),
      borderWidth: 0.7,
    });

    this.page.drawText(title, {
      x: x + 12,
      y: y + h + 10,
      size: 10,
      font: this.bold,
      color: color("#0f172a"),
    });

    const data = Array.isArray(rows) ? rows.slice(0, 18).reverse() : [];

    for (let i = 0; i <= 4; i++) {
      const gy = y + 18 + (i * (h - 32)) / 4;
      this.page.drawLine({
        start: { x: x + 36, y: gy },
        end: { x: x + w - 18, y: gy },
        thickness: 0.25,
        color: color("#e2e8f0"),
      });
    }

    if (data.length < 2) {
      this.page.drawText("Not enough telemetry data available for trend rendering.", {
        x: x + 48,
        y: y + 70,
        size: 8.5,
        font: this.font,
        color: color("#64748b"),
      });
      this.y -= 182;
      return;
    }

    const plotX = x + 38;
    const plotY = y + 22;
    const plotW = w - 58;
    const plotH = h - 40;

    series.forEach((s, si) => {
      const values = data.map((d) => num(d[s.key]));
      const hi = Math.max(...values, s.minMax || 1);
      const lo = Math.min(...values, 0);
      const range = Math.max(hi - lo, 1);

      let prev = null;

      values.forEach((v, i) => {
        const px = plotX + (i * plotW) / Math.max(values.length - 1, 1);
        const py = plotY + ((v - lo) / range) * plotH;

        if (prev) {
          this.page.drawLine({
            start: prev,
            end: { x: px, y: py },
            thickness: 1.4,
            color: color(s.color),
          });
        }

        this.page.drawCircle({
          x: px,
          y: py,
          size: 2.2,
          color: color(s.color),
        });

        prev = { x: px, y: py };
      });

      this.page.drawText(s.label, {
        x: x + 12 + si * 130,
        y: y + 7,
        size: 7.2,
        font: this.bold,
        color: color(s.color),
      });
    });

    this.y -= 182;
  }

  barChart(title, rows, key, barColor) {
    this.ensure(160);

    const x = M;
    const y = this.y - 130;
    const w = PAGE_W - M * 2;
    const h = 105;

    this.page.drawRectangle({
      x,
      y,
      width: w,
      height: h + 26,
      color: color("#ffffff"),
      borderColor: color("#cbd5e1"),
      borderWidth: 0.7,
    });

    this.page.drawText(title, {
      x: x + 12,
      y: y + h + 10,
      size: 10,
      font: this.bold,
      color: color("#0f172a"),
    });

    const data = Array.isArray(rows) ? rows.slice(0, 16).reverse() : [];
    const hi = Math.max(...data.map((d) => num(d[key])), 1);
    const bw = (w - 58) / Math.max(data.length, 1);

    data.forEach((d, i) => {
      const v = num(d[key]);
      const bh = Math.max((v / hi) * (h - 28), 3);
      const bx = x + 38 + i * bw;

      this.page.drawRectangle({
        x: bx,
        y: y + 18,
        width: Math.max(bw - 4, 4),
        height: bh,
        color: color(barColor),
      });
    });

    this.y -= 152;
  }

  flowDiagram() {
    this.ensure(210);

    const x = M;
    const y = this.y - 170;
    const w = PAGE_W - M * 2;
    const boxW = 88;
    const boxH = 50;
    const gap = 14;

    this.page.drawRectangle({
      x,
      y,
      width: w,
      height: 160,
      color: color("#ffffff"),
      borderColor: color("#cbd5e1"),
      borderWidth: 0.7,
    });

    this.page.drawText("Telemetry Processing Flow", {
      x: x + 12,
      y: y + 140,
      size: 10.5,
      font: this.bold,
      color: color("#0f172a"),
    });

    const boxes = [
      ["Browser", "QoE Probe"],
      ["Frontend", "Cloud Run"],
      ["FastAPI", "QoS API"],
      ["Cloud SQL", "History"],
      ["Report", "PDF / CSV"],
    ];

    boxes.forEach((b, i) => {
      const bx = x + 16 + i * (boxW + gap);
      const by = y + 72;

      this.page.drawRectangle({
        x: bx,
        y: by,
        width: boxW,
        height: boxH,
        color: color(i === 0 ? "#ecfeff" : i === 3 ? "#dcfce7" : "#eff6ff"),
        borderColor: color("#0891b2"),
        borderWidth: 0.75,
      });

      this.page.drawText(b[0], {
        x: bx + 8,
        y: by + 30,
        size: 8,
        font: this.bold,
        color: color("#0f172a"),
      });

      this.page.drawText(b[1], {
        x: bx + 8,
        y: by + 16,
        size: 7,
        font: this.font,
        color: color("#475569"),
      });

      if (i < boxes.length - 1) {
        this.page.drawLine({
          start: { x: bx + boxW + 2, y: by + 25 },
          end: { x: bx + boxW + gap - 3, y: by + 25 },
          thickness: 1,
          color: color("#0891b2"),
        });
      }
    });

    const notes = [
      "Browser active probe measures latency, jitter, downlink, uplink, and response time.",
      "FastAPI normalizes the telemetry into QoS history, metrics, alerts, prediction, and report endpoints.",
      "PDF and CSV exports consume the same operational API data, ensuring the exported report is not a UI screenshot.",
    ];

    let ny = y + 45;
    notes.forEach((note) => {
      this.page.drawText(note, {
        x: x + 18,
        y: ny,
        size: 7.2,
        font: this.font,
        color: color("#334155"),
      });
      ny -= 13;
    });

    this.y -= 192;
  }

  riskMatrix(currentStatus) {
    this.ensure(150);

    const x = M;
    const y = this.y - 118;
    const w = PAGE_W - M * 2;
    const cellW = (w - 32) / 4;

    this.page.drawRectangle({
      x,
      y,
      width: w,
      height: 122,
      color: color("#ffffff"),
      borderColor: color("#cbd5e1"),
      borderWidth: 0.7,
    });

    this.page.drawText("QoE / SLA Risk Matrix", {
      x: x + 12,
      y: y + 100,
      size: 10.5,
      font: this.bold,
      color: color("#0f172a"),
    });

    const cells = [
      ["Excellent", "Low operational risk", "#dcfce7"],
      ["Stable", "Normal monitoring", "#cffafe"],
      ["Buffer Risk", "Optimization required", "#fef9c3"],
      ["Poor", "Immediate investigation", "#fee2e2"],
    ];

    cells.forEach((cell, i) => {
      const bx = x + 16 + i * cellW;
      const active = cell[0].toUpperCase() === currentStatus;

      this.page.drawRectangle({
        x: bx,
        y: y + 35,
        width: cellW - 6,
        height: 48,
        color: color(cell[2]),
        borderColor: color(active ? "#020617" : "#cbd5e1"),
        borderWidth: active ? 1.7 : 0.5,
      });

      this.page.drawText(cell[0], {
        x: bx + 8,
        y: y + 64,
        size: 8,
        font: this.bold,
        color: color("#0f172a"),
      });

      this.page.drawText(cell[1], {
        x: bx + 8,
        y: y + 48,
        size: 6.8,
        font: this.font,
        color: color("#334155"),
      });
    });

    this.y -= 140;
  }

  footer() {
    this.pages.forEach((p, idx) => {
      p.drawLine({
        start: { x: M, y: 34 },
        end: { x: PAGE_W - M, y: 34 },
        thickness: 0.4,
        color: color("#cbd5e1"),
      });

      p.drawText(`AKSARA UNION QoS Analytics Platform | Real Browser-to-Cloud QoE Telemetry | Page ${idx + 1} of ${this.pages.length}`, {
        x: M,
        y: 20,
        size: 7,
        font: this.font,
        color: color("#64748b"),
      });
    });
  }
}

export async function GET() {
  try {
    const [metricsRaw, historyRaw, alertsRaw, latestRaw] = await Promise.all([
      safeJson(`${API_URL}/api/qos/metrics?x=${Date.now()}`, {}),
      safeJson(`${API_URL}/api/qos/history?x=${Date.now()}`, []),
      safeJson(`${API_URL}/api/alerts?x=${Date.now()}`, []),
      safeJson(`${API_URL}/api/qoe/latest?x=${Date.now()}`, {}),
    ]);

    const history = Array.isArray(historyRaw) ? historyRaw.slice(0, 80) : [];
    const alerts = Array.isArray(alertsRaw) ? alertsRaw : [];
    const generatedAt = new Date();

    const metrics = {
      throughput: num(metricsRaw.throughput),
      latency: num(metricsRaw.latency),
      jitter: num(metricsRaw.jitter),
      packet_loss: num(metricsRaw.packet_loss),
      bandwidth: num(metricsRaw.bandwidth ?? metricsRaw.throughput),
      qoe_score: num(metricsRaw.qoe_score),
      streaming_status: metricsRaw.streaming_status || statusFromQoe(metricsRaw.qoe_score),
      source: metricsRaw.source || "real-qoe-probe",
      timestamp: metricsRaw.timestamp || "-",
    };

    const status = metrics.streaming_status || statusFromQoe(metrics.qoe_score);

    const stats = {
      avgThroughput: avg(history, "throughput"),
      minThroughput: min(history, "throughput"),
      maxThroughput: max(history, "throughput"),
      avgLatency: avg(history, "latency"),
      maxLatency: max(history, "latency"),
      avgJitter: avg(history, "jitter"),
      maxJitter: max(history, "jitter"),
      avgLoss: avg(history, "packet_loss"),
      avgQoe: avg(history, "qoe_score"),
      qoeStd: stddev(history, "qoe_score"),
      latencyStd: stddev(history, "latency"),
      sampleCount: history.length || latestRaw.count || 0,
    };

    const pdf = await PDFDocument.create();
    const regular = await pdf.embedFont(StandardFonts.Helvetica);
    const bold = await pdf.embedFont(StandardFonts.HelveticaBold);

    const r = new PdfWriter(pdf, { regular, bold });

    r.cover(
      "Carrier-Grade QoE / SLA Technical Report",
      "Structured operational report generated from live browser-to-cloud telemetry. The document summarizes QoE condition, SLA compliance, latency and jitter behavior, throughput stability, active alert conditions, telemetry architecture, and engineering recommendations.",
      [
        ["Generated At", generatedAt.toLocaleString()],
        ["Project ID", PROJECT_ID],
        ["Region", REGION],
        ["Telemetry Source", metrics.source],
        ["Current Status", status],
        ["API Endpoint", API_URL],
      ]
    );

    r.addPage();

    r.section("1. Executive Technical Summary", "High-level operational condition derived from real QoE telemetry.");
    r.cards([
      { label: "Current Status", value: status, color: riskColor(status), note: "QoE classification" },
      { label: "QoE Score", value: `${fmt(metrics.qoe_score, 1)} / 100`, color: riskColor(status), note: "Streaming experience index" },
      { label: "Active Alerts", value: String(alerts.length), color: alerts.length ? "#dc2626" : "#16a34a", note: "Threshold events" },
      { label: "Throughput", value: `${fmt(metrics.throughput, 2)} Mbps`, color: "#0891b2", note: "Latest downlink estimate" },
      { label: "Latency", value: `${fmt(metrics.latency, 2)} ms`, color: "#d97706", note: "Latest browser-to-cloud RTT" },
      { label: "Jitter", value: `${fmt(metrics.jitter, 2)} ms`, color: "#7c3aed", note: "Latency variation" },
    ]);

    r.paragraph(
      `The current platform condition is classified as ${status}. This classification is calculated from live browser-to-Cloud Run telemetry, including measured throughput, latency, jitter, packet-loss indication, and QoE scoring. The latest sample reports ${fmt(metrics.throughput, 2)} Mbps throughput, ${fmt(metrics.latency, 2)} ms latency, ${fmt(metrics.jitter, 2)} ms jitter, and ${fmt(metrics.packet_loss, 2)}% packet loss. These values indicate the real performance experienced by the active client session, not a static dashboard placeholder.`
    );

    r.paragraph(
      `From an operational perspective, the system is useful because it links the user-facing streaming condition with backend observability. When streaming playback becomes unstable, the dashboard can correlate that degradation with increased RTT, unstable jitter, reduced throughput, or active alert events. This allows a network engineer to explain whether the issue is more likely related to access-network congestion, unstable transport path, backend response delay, or insufficient available throughput.`
    );

    r.section("2. Live KPI Snapshot", "Latest KPI values returned by the operational API.");
    r.cards([
      { label: "Latest Throughput", value: `${fmt(metrics.throughput, 2)} Mbps`, color: "#0891b2" },
      { label: "Latest Latency", value: `${fmt(metrics.latency, 2)} ms`, color: "#d97706" },
      { label: "Latest Jitter", value: `${fmt(metrics.jitter, 2)} ms`, color: "#7c3aed" },
      { label: "Packet Loss", value: `${fmt(metrics.packet_loss, 2)} %`, color: "#dc2626" },
      { label: "Bandwidth Field", value: `${fmt(metrics.bandwidth, 2)} Mbps`, color: "#0891b2" },
      { label: "Latest Timestamp", value: metrics.timestamp, color: "#0f172a" },
    ]);

    r.section("3. Measurement Window Statistics", "Statistical interpretation over the latest telemetry window.");
    r.cards([
      { label: "Average Throughput", value: `${fmt(stats.avgThroughput, 2)} Mbps`, color: "#0891b2" },
      { label: "Minimum Throughput", value: `${fmt(stats.minThroughput, 2)} Mbps`, color: "#0f172a" },
      { label: "Maximum Throughput", value: `${fmt(stats.maxThroughput, 2)} Mbps`, color: "#0891b2" },
      { label: "Average Latency", value: `${fmt(stats.avgLatency, 2)} ms`, color: "#d97706" },
      { label: "Maximum Latency", value: `${fmt(stats.maxLatency, 2)} ms`, color: "#dc2626" },
      { label: "Latency Deviation", value: `${fmt(stats.latencyStd, 2)} ms`, color: "#7c3aed" },
      { label: "Average Jitter", value: `${fmt(stats.avgJitter, 2)} ms`, color: "#7c3aed" },
      { label: "Maximum Jitter", value: `${fmt(stats.maxJitter, 2)} ms`, color: "#dc2626" },
      { label: "Average QoE", value: `${fmt(stats.avgQoe, 1)} / 100`, color: riskColor(status) },
    ]);

    r.paragraph(
      `The measurement window contains ${stats.sampleCount} telemetry records. The average throughput is ${fmt(stats.avgThroughput, 2)} Mbps, while the minimum observed throughput is ${fmt(stats.minThroughput, 2)} Mbps. A large difference between average and minimum throughput indicates unstable capacity headroom, which is important for streaming applications because video playback usually tolerates moderate latency but becomes sensitive when available throughput falls below the required bitrate for the selected resolution.`
    );

    r.paragraph(
      `The latency profile shows an average of ${fmt(stats.avgLatency, 2)} ms and a maximum of ${fmt(stats.maxLatency, 2)} ms. The latency deviation is ${fmt(stats.latencyStd, 2)} ms. In practical QoE monitoring, latency deviation and jitter are often more important than one isolated RTT value because they describe how stable the session feels over time. A session with moderate but stable latency can still perform better than a session with frequent spikes that trigger buffering, adaptive bitrate downgrade, or delayed segment delivery.`
    );

    r.section("4. Telemetry Architecture and Data Flow", "End-to-end path from browser probe to report export.");
    r.flowDiagram();

    r.paragraph(
      `The telemetry pipeline begins at the browser where active probing is performed. The browser sends controlled requests to Cloud Run endpoints for latency, upload, download, and sample submission. The FastAPI backend processes those measurements and exposes normalized endpoints for current metrics, historical samples, alerts, QoE windows, and reports. This design is stronger than a dummy dashboard because every visualization and report is driven by the same API data source.`
    );

    r.paragraph(
      `Cloud SQL functions as the operational database layer, while BigQuery can be used as the analytical warehouse for larger telemetry history. Cloud Run separates the frontend and backend services, allowing the dashboard to scale independently from the API. This separation is consistent with production-style cloud architecture because the presentation layer, telemetry API, database layer, and analytical layer are not hardcoded into one static page.`
    );

    r.section("5. Trend Visualization", "Throughput, latency, jitter, and QoE behavior over time.");
    r.lineChart("Throughput, Latency, and Jitter Trend", history, [
      { key: "throughput", label: "Throughput Mbps", color: "#06b6d4" },
      { key: "latency", label: "Latency ms", color: "#eab308" },
      { key: "jitter", label: "Jitter ms", color: "#a855f7" },
    ]);
    r.barChart("QoE Score Distribution Window", history, "qoe_score", "#22c55e");

    r.paragraph(
      `The trend chart is used to detect whether QoE degradation is caused by a single isolated spike or by a sustained degradation pattern. If throughput remains high while QoE decreases, the likely cause may be latency fluctuation, jitter burst, or backend delay. If throughput drops sharply together with QoE, the issue is more likely related to capacity limitation, access-link congestion, Wi-Fi/Ethernet instability, or competing traffic on the client network.`
    );

    r.section("6. SLA and QoE Risk Classification", "Operational classification based on QoE and active threshold conditions.");
    r.riskMatrix(status);

    r.paragraph(
      `The SLA logic used in this report is based on the relationship between QoE score, latency, jitter, packet loss, throughput, and active alerts. A high QoE score indicates that the streaming path is currently usable and stable. A buffer-risk or poor condition indicates that one or more technical parameters have crossed the threshold where user experience can degrade. This classification is not meant to replace operator-grade KPI counters, but it provides a practical real-time view of client-side experience.`
    );

    r.bullet([
      `Excellent condition means QoE is above 90, latency and jitter are stable, and the active telemetry window does not show severe degradation.`,
      `Stable condition means the service is still acceptable, but the system should continue monitoring for developing latency or jitter patterns.`,
      `Buffer Risk means the measured path may still work but has enough instability to cause adaptive bitrate reduction, buffering, or degraded perceived quality.`,
      `Poor condition means the active session should be investigated immediately because throughput, latency, jitter, or packet-loss behavior has crossed critical limits.`,
    ]);

    r.section("7. Active Alert Analysis", "Alert events generated from backend threshold and QoE conditions.");
    if (alerts.length) {
      r.table(
        ["Type", "Message", "Metric", "Time", "Source"],
        alerts.map((a) => [
          a.type || "-",
          a.message || "-",
          a.metric || "-",
          a.time || "-",
          a.source || "-",
        ]),
        [55, 190, 78, 70, 118],
        18
      );
      r.paragraph(
        `The alert table contains ${alerts.length} active or recent threshold events. These alerts should be interpreted as operational symptoms. For example, high real latency indicates a delayed browser-to-cloud response path, high jitter indicates unstable variation between successive probes, and low real download throughput indicates reduced available capacity for video segment delivery.`
      );
    } else {
      r.paragraph(
        `No active alerts were present during report generation. This means the latest telemetry window is within the configured operating thresholds. The absence of alerts should still be evaluated together with the trend chart because short-lived spikes may not always remain active at the time of export.`
      );
    }

    r.section("8. Latest Real Telemetry Samples", "Recent API samples used by dashboard, reports, alerts, and prediction modules.");
    if (history.length) {
      r.table(
        ["Timestamp", "Throughput", "Latency", "Jitter", "Loss", "QoE", "Source"],
        history.map((s) => [
          s.timestamp || "-",
          `${fmt(s.throughput, 2)} Mbps`,
          `${fmt(s.latency, 2)} ms`,
          `${fmt(s.jitter, 2)} ms`,
          `${fmt(s.packet_loss, 2)}%`,
          fmt(s.qoe_score, 1),
          s.source || "-",
        ]),
        [72, 82, 72, 65, 50, 45, 134],
        26
      );
    } else {
      r.paragraph(
        `No telemetry sample was available at export time. Keep the Streaming QoE page open while playing YouTube or another streaming workload so that the browser continues sending real probe samples to Cloud Run.`
      );
    }

    r.section("9. Engineering Diagnosis", "Technical interpretation of the current measurement window.");
    r.paragraph(
      `Based on the latest measurement, the dominant condition is ${status}. The current throughput of ${fmt(metrics.throughput, 2)} Mbps should be compared against the expected bitrate of the active streaming workload. For ordinary HD playback this throughput may be sufficient, but for higher-resolution video or simultaneous background traffic, reduced throughput can increase the probability of adaptive bitrate downgrade.`
    );

    r.paragraph(
      `Latency and jitter should be analyzed together. The current latency is ${fmt(metrics.latency, 2)} ms and the current jitter is ${fmt(metrics.jitter, 2)} ms. If both values increase at the same time, the issue may come from queueing delay, unstable access link, overloaded client network, temporary routing variation, or backend response fluctuation. If jitter is high while average latency remains acceptable, the session may still experience irregular buffering because segment delivery becomes inconsistent.`
    );

    r.paragraph(
      `The packet-loss field is ${fmt(metrics.packet_loss, 2)}%. Even small packet-loss values can affect streaming quality when combined with high jitter or low throughput. In adaptive streaming, packet loss and delay variation may force the player to request lower-bitrate segments. In real-time communication scenarios such as WebRTC, packet loss can also reduce audio/video continuity and increase concealment artifacts.`
    );

    r.section("10. Recommended Engineering Actions", "Action plan for demonstration and troubleshooting.");
    r.bullet([
      `Keep the Streaming QoE page active while running YouTube, meeting, or large download traffic in another browser window. This produces real browser-to-cloud telemetry instead of static demonstration values.`,
      `When QoE drops, compare the trend chart against alert records. If latency and jitter spike first, investigate RTT path and backend responsiveness. If throughput drops first, investigate access capacity and local network load.`,
      `Use the System Evidence Center in the Database Monitor page to open Cloud SQL, BigQuery, Cloud Run API, logs, and raw telemetry endpoints as technical proof of the deployed cloud pipeline.`,
      `Use the CSV export for raw sample verification and the PDF export for structured executive and engineering reporting.`,
      `For a cleaner presentation, generate the PDF after at least 1-2 minutes of active streaming so the report contains a richer telemetry window and more meaningful trend analysis.`,
    ]);

    r.section("11. Cloud Evidence Appendix", "Operational cloud components used by the platform.");
    r.cards([
      { label: "Frontend", value: "Cloud Run", color: "#0891b2", note: "Next.js dashboard" },
      { label: "Backend API", value: "Cloud Run", color: "#0891b2", note: "FastAPI QoS endpoints" },
      { label: "Database", value: "Cloud SQL", color: "#16a34a", note: "PostgreSQL operational layer" },
      { label: "Analytics", value: "BigQuery", color: "#d97706", note: "Telemetry warehouse" },
      { label: "Region", value: REGION, color: "#0f172a", note: "Deployment region" },
      { label: "Project", value: PROJECT_ID, color: "#0f172a", note: "GCP project ID" },
    ]);

    r.paragraph(
      `The platform is deployed on Google Cloud using separate services for the frontend and backend API. The report endpoint reads live telemetry from the backend API at ${API_URL}. This confirms that the exported report is coupled to the operational service layer rather than being generated from a static frontend screen.`
    );

    r.footer();

    const bytes = await pdf.save();

    return new Response(Buffer.from(bytes), {
      status: 200,
      headers: {
        "Content-Type": "application/pdf",
        "Content-Disposition": `attachment; filename="AKSARA_QoE_SLA_Technical_Report_${generatedAt.toISOString().slice(0, 10)}.pdf"`,
        "Cache-Control": "no-store, no-cache, must-revalidate",
      },
    });
  } catch (error) {
    return Response.json(
      {
        error: "PDF generation failed",
        detail: String(error?.stack || error?.message || error),
        apiUrl: API_URL,
      },
      { status: 500 }
    );
  }
}
JS

python3 <<PY
from pathlib import Path
p = Path("app/api/reports/pdf/route.js")
s = p.read_text()
s = s.replace("__API_URL__", "$API_URL")
s = s.replace("__PROJECT_ID__", "$PROJECT_ID")
p.write_text(s)
print("✅ PDF route replaced with clean long technical report")
PY

echo "=================================================="
echo "DONE"
echo "=================================================="
