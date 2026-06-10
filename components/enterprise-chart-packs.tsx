"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertTriangle,
  BarChart3,
  Box,
  Database,
  Gauge,
  GitBranch,
  Radio,
  Server,
  ShieldCheck,
  Zap,
} from "lucide-react";

type H = {
  timestamp?: string;
  throughput?: number;
  latency?: number;
  jitter?: number;
  packet_loss?: number;
  qoe_score?: number;
  source?: string;
};

type AlertItem = {
  id?: string | number;
  type?: string;
  message?: string;
  metric?: string;
  time?: string;
  source?: string;
};

function n(v: unknown, fallback = 0) {
  const x = Number(v);
  return Number.isFinite(x) ? x : fallback;
}

function avg(items: H[], key: keyof H) {
  if (!items.length) return 0;
  return items.reduce((s, item) => s + n(item[key]), 0) / items.length;
}

function max(items: H[], key: keyof H) {
  if (!items.length) return 0;
  return Math.max(...items.map((item) => n(item[key])));
}

function min(items: H[], key: keyof H) {
  if (!items.length) return 0;
  return Math.min(...items.map((item) => n(item[key])));
}

function useTelemetry() {
  const [history, setHistory] = useState<H[]>([]);
  const [alerts, setAlerts] = useState<AlertItem[]>([]);

  async function refresh() {
    try {
      const [h, a] = await Promise.all([
        fetch(`/api/qos-history?x=${Date.now()}`, { cache: "no-store" }).then((r) => r.json()),
        fetch(`/api/qos-alerts?x=${Date.now()}`, { cache: "no-store" }).then((r) => r.json()),
      ]);

      setHistory(Array.isArray(h) ? h : []);
      setAlerts(Array.isArray(a) ? a : []);
    } catch {
      // keep previous
    }
  }

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, 5000);
    window.addEventListener("real-qoe-updated", refresh);

    return () => {
      clearInterval(interval);
      window.removeEventListener("real-qoe-updated", refresh);
    };
  }, []);

  return { history, alerts, refresh };
}

function panel(title: string, subtitle: string, icon: any, children: any) {
  const Icon = icon;

  return (
    <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
      <div className="mb-4 flex items-start justify-between gap-4">
        <div>
          <h3 className="text-lg font-black text-white">{title}</h3>
          <p className="mt-1 text-xs text-slate-500">{subtitle}</p>
        </div>
        <div className="rounded-xl border border-cyan-500/20 bg-cyan-500/10 p-2">
          <Icon className="h-5 w-5 text-cyan-300" />
        </div>
      </div>
      {children}
    </div>
  );
}

function points(data: H[], key: keyof H, w: number, h: number, pad = 28) {
  const arr = data.slice(0, 24).reverse();
  const vals = arr.map((x) => n(x[key]));
  const hi = Math.max(...vals, 1);
  const lo = Math.min(...vals, 0);
  const range = Math.max(hi - lo, 1);

  return arr
    .map((d, i) => {
      const x = pad + (i * (w - pad * 2)) / Math.max(arr.length - 1, 1);
      const y = h - pad - ((n(d[key]) - lo) / range) * (h - pad * 2);
      return `${x},${y}`;
    })
    .join(" ");
}

function DashboardTrafficComplex({ history }: { history: H[] }) {
  const w = 900;
  const h = 320;
  const data = history.slice(0, 24).reverse();

  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="h-[340px] w-full">
      <defs>
        <linearGradient id="dashFill" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="var(--aksara-accent)" stopOpacity="0.32" />
          <stop offset="100%" stopColor="var(--aksara-accent)" stopOpacity="0.02" />
        </linearGradient>
      </defs>
      <rect x="0" y="0" width={w} height={h} rx="22" fill="#020617" />
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <line key={i} x1="50" x2={w - 30} y1={40 + i * 42} y2={40 + i * 42} stroke="#1e293b" strokeDasharray="7 7" />
      ))}
      <polyline points={points(data, "throughput", w, h)} fill="none" stroke="var(--aksara-accent)" strokeWidth="4" />
      <polyline points={points(data, "latency", w, h)} fill="none" stroke="#eab308" strokeWidth="3" />
      <polyline points={points(data, "jitter", w, h)} fill="none" stroke="#a855f7" strokeWidth="2.5" />
      {data.map((d, i) => {
        const x = 28 + (i * (w - 56)) / Math.max(data.length - 1, 1);
        const y = 275 - (n(d.qoe_score) / 100) * 90;
        const color = n(d.qoe_score) >= 90 ? "#22c55e" : n(d.qoe_score) >= 75 ? "#06b6d4" : n(d.qoe_score) >= 60 ? "#eab308" : "#ef4444";
        return <circle key={i} cx={x} cy={y} r="4" fill={color} />;
      })}
      <text x="55" y="300" fill="var(--aksara-accent)" fontSize="13">Throughput</text>
      <text x="165" y="300" fill="#eab308" fontSize="13">Latency</text>
      <text x="245" y="300" fill="#a855f7" fontSize="13">Jitter</text>
      <text x="315" y="300" fill="#22c55e" fontSize="13">QoE dots</text>
    </svg>
  );
}

function DashboardSlaRadar({ history, alerts }: { history: H[]; alerts: AlertItem[] }) {
  const throughput = Math.min((avg(history, "throughput") / 80) * 100, 100);
  const latency = Math.max(100 - (avg(history, "latency") / 200) * 100, 0);
  const jitter = Math.max(100 - (avg(history, "jitter") / 80) * 100, 0);
  const qoe = avg(history, "qoe_score");
  const reliability = alerts.length ? Math.max(100 - alerts.length * 16, 0) : 100;
  const values = [throughput, latency, jitter, qoe, reliability];
  const labels = ["Capacity", "Latency", "Jitter", "QoE", "Reliability"];

  const center = 150;
  const r = 105;

  const poly = values.map((v, i) => {
    const angle = (-90 + i * 72) * Math.PI / 180;
    const rr = (v / 100) * r;
    return `${center + Math.cos(angle) * rr},${center + Math.sin(angle) * rr}`;
  }).join(" ");

  return (
    <svg viewBox="0 0 300 300" className="mx-auto h-[300px] w-full max-w-[420px]">
      <rect x="0" y="0" width="300" height="300" rx="22" fill="#020617" />
      {[25, 50, 75, 100].map((pct) => (
        <polygon
          key={pct}
          points={[0, 1, 2, 3, 4].map((_, i) => {
            const angle = (-90 + i * 72) * Math.PI / 180;
            const rr = (pct / 100) * r;
            return `${center + Math.cos(angle) * rr},${center + Math.sin(angle) * rr}`;
          }).join(" ")}
          fill="none"
          stroke="#1e293b"
        />
      ))}
      <polygon points={poly} fill="var(--aksara-accent)" fillOpacity="0.24" stroke="var(--aksara-accent)" strokeWidth="3" />
      {labels.map((label, i) => {
        const angle = (-90 + i * 72) * Math.PI / 180;
        return (
          <text key={label} x={center + Math.cos(angle) * 128 - 25} y={center + Math.sin(angle) * 128} fill="#cbd5e1" fontSize="11">
            {label}
          </text>
        );
      })}
    </svg>
  );
}

function DashboardCapacityBars({ history }: { history: H[] }) {
  const data = history.slice(0, 18).reverse();
  const maxT = Math.max(...data.map((d) => n(d.throughput)), 1);

  return (
    <div className="grid h-[280px] grid-cols-18 items-end gap-2 rounded-2xl bg-slate-950 p-5">
      {data.map((d, i) => {
        const height = Math.max((n(d.throughput) / maxT) * 210, 5);
        const qoe = n(d.qoe_score);
        const color = qoe >= 90 ? "bg-emerald-400" : qoe >= 75 ? "bg-cyan-400" : qoe >= 60 ? "bg-yellow-400" : "bg-red-400";
        return (
          <div key={i} className="flex h-full flex-col justify-end gap-1">
            <div className={`${color} rounded-t-xl shadow-lg`} style={{ height }} title={`${d.timestamp} ${d.throughput} Mbps`} />
          </div>
        );
      })}
    </div>
  );
}

function RealtimeOscilloscope({ history }: { history: H[] }) {
  const w = 900;
  const h = 230;
  const data = history.slice(0, 32).reverse();

  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="h-[250px] w-full">
      <rect x="0" y="0" width={w} height={h} rx="22" fill="#000814" />
      {[...Array(10)].map((_, i) => (
        <line key={`v${i}`} x1={50 + i * 85} x2={50 + i * 85} y1="20" y2={h - 25} stroke="#0f766e" strokeOpacity="0.35" />
      ))}
      {[...Array(5)].map((_, i) => (
        <line key={`h${i}`} x1="30" x2={w - 30} y1={35 + i * 38} y2={35 + i * 38} stroke="#0f766e" strokeOpacity="0.35" />
      ))}
      <polyline points={points(data, "latency", w, h)} fill="none" stroke="#22c55e" strokeWidth="3" />
      <polyline points={points(data, "jitter", w, h)} fill="none" stroke="#f59e0b" strokeWidth="2" />
      <text x="35" y="210" fill="#22c55e" fontSize="13">Latency waveform</text>
      <text x="190" y="210" fill="#f59e0b" fontSize="13">Jitter overlay</text>
    </svg>
  );
}

function RealtimeWaterfall({ history }: { history: H[] }) {
  const data = history.slice(0, 40);

  return (
    <div className="rounded-2xl bg-slate-950 p-4">
      <div className="grid grid-cols-20 gap-1">
        {data.map((d, i) => {
          const latency = n(d.latency);
          const cls =
            latency < 60 ? "bg-emerald-400" :
            latency < 100 ? "bg-cyan-400" :
            latency < 160 ? "bg-yellow-400" : "bg-red-400";

          return (
            <div key={i} className={`${cls} h-10 rounded-md opacity-90`} title={`${d.timestamp} latency ${latency} ms`} />
          );
        })}
      </div>
      <p className="mt-3 text-xs text-slate-500">Waterfall color represents latency pressure per probe interval.</p>
    </div>
  );
}

function RealtimeEventLanes({ history, alerts }: { history: H[]; alerts: AlertItem[] }) {
  const data = history.slice(0, 12);

  return (
    <div className="space-y-3 rounded-2xl bg-slate-950 p-4">
      {data.map((d, i) => {
        const qoe = n(d.qoe_score);
        const alert = qoe < 75 || n(d.latency) > 100 || n(d.jitter) > 35;
        return (
          <div key={i} className="grid grid-cols-[120px_1fr_90px] items-center gap-3">
            <p className="text-xs text-slate-400">{d.timestamp || "-"}</p>
            <div className="h-3 rounded-full bg-slate-800">
              <div
                className={alert ? "h-3 rounded-full bg-yellow-400" : "h-3 rounded-full bg-emerald-400"}
                style={{ width: `${Math.max(Math.min(qoe, 100), 3)}%` }}
              />
            </div>
            <p className={alert ? "text-xs font-bold text-yellow-300" : "text-xs font-bold text-emerald-300"}>
              {alert ? "WATCH" : "OK"}
            </p>
          </div>
        );
      })}
      {alerts.length ? <p className="text-xs text-red-300">{alerts.length} active alert events detected.</p> : null}
    </div>
  );
}

function QoeGauge({ value }: { value: number }) {
  const radius = 82;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (Math.max(Math.min(value, 100), 0) / 100) * circumference;

  return (
    <svg viewBox="0 0 220 220" className="mx-auto h-[240px] w-full max-w-[320px]">
      <rect x="0" y="0" width="220" height="220" rx="28" fill="#020617" />
      <circle cx="110" cy="110" r={radius} fill="none" stroke="#1e293b" strokeWidth="18" />
      <circle
        cx="110"
        cy="110"
        r={radius}
        fill="none"
        stroke="var(--aksara-accent)"
        strokeWidth="18"
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={offset}
        transform="rotate(-90 110 110)"
      />
      <text x="110" y="104" textAnchor="middle" fill="#ffffff" fontSize="38" fontWeight="900">{value.toFixed(0)}</text>
      <text x="110" y="130" textAnchor="middle" fill="#94a3b8" fontSize="12">QoE Score</text>
    </svg>
  );
}

function QoeDegradationStack({ history }: { history: H[] }) {
  const latest = history[0] || {};
  const latencyPenalty = Math.max((n(latest.latency) - 80) * 0.18, 0);
  const jitterPenalty = Math.max((n(latest.jitter) - 20) * 0.7, 0);
  const lossPenalty = n(latest.packet_loss) * 20;
  const remaining = Math.max(100 - latencyPenalty - jitterPenalty - lossPenalty, 0);

  const parts = [
    ["Healthy Budget", remaining, "bg-emerald-400"],
    ["Latency Penalty", latencyPenalty, "bg-yellow-400"],
    ["Jitter Penalty", jitterPenalty, "bg-purple-400"],
    ["Loss Penalty", lossPenalty, "bg-red-400"],
  ];

  return (
    <div className="rounded-2xl bg-slate-950 p-5">
      <div className="flex h-12 overflow-hidden rounded-xl border border-slate-800">
        {parts.map(([label, value, cls]) => (
          <div key={String(label)} className={`${cls} h-full`} style={{ width: `${Math.max(Number(value), 2)}%` }} title={`${label}: ${Number(value).toFixed(1)}`} />
        ))}
      </div>
      <div className="mt-4 grid gap-2 md:grid-cols-4">
        {parts.map(([label, value, cls]) => (
          <div key={String(label)} className="rounded-xl border border-slate-800 bg-slate-900/80 p-3">
            <p className="text-xs text-slate-400">{label}</p>
            <p className="mt-1 text-lg font-black">{Number(value).toFixed(1)}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function QoeDecisionMatrix({ history }: { history: H[] }) {
  const latest = history[0] || {};
  const items = [
    {
      title: "Buffer Probability",
      value: n(latest.latency) > 100 || n(latest.jitter) > 35 ? "Elevated" : "Low",
      desc: "Derived from latency and jitter pressure.",
    },
    {
      title: "Transport Stability",
      value: n(latest.packet_loss) > 0.5 ? "Lossy" : "Stable",
      desc: "Based on packet-loss percentage.",
    },
    {
      title: "Capacity Headroom",
      value: n(latest.throughput) > 25 ? "Enough" : "Limited",
      desc: "Uses measured browser downlink throughput.",
    },
    {
      title: "Recommended Action",
      value: n(latest.qoe_score) >= 90 ? "Continue Monitoring" : "Inspect Path",
      desc: "Operational recommendation from QoE state.",
    },
  ];

  return (
    <div className="grid gap-4 md:grid-cols-4">
      {items.map((item) => (
        <div key={item.title} className="rounded-2xl border border-slate-800 bg-slate-950 p-4">
          <p className="text-xs uppercase tracking-[0.2em] text-slate-500">{item.title}</p>
          <p className="mt-3 text-2xl font-black text-white">{item.value}</p>
          <p className="mt-2 text-xs text-slate-400">{item.desc}</p>
        </div>
      ))}
    </div>
  );
}

export function DashboardNocAnalytics() {
  const { history, alerts } = useTelemetry();

  const summary = useMemo(() => ({
    avgThroughput: avg(history, "throughput"),
    avgLatency: avg(history, "latency"),
    minThroughput: min(history, "throughput"),
    maxLatency: max(history, "latency"),
  }), [history]);

  return (
    <section className="mt-8 space-y-6">
      <div>
        <h2 className="text-2xl font-black text-white">NOC Performance Analytics</h2>
        <p className="mt-2 text-sm text-slate-400">
          Dashboard-level view: executive KPI trend, SLA radar, and capacity distribution from real QoE telemetry.
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-4">
        {[
          ["Avg Throughput", `${summary.avgThroughput.toFixed(2)} Mbps`, Zap],
          ["Avg Latency", `${summary.avgLatency.toFixed(2)} ms`, Gauge],
          ["Min Throughput", `${summary.minThroughput.toFixed(2)} Mbps`, BarChart3],
          ["Max Latency", `${summary.maxLatency.toFixed(2)} ms`, AlertTriangle],
        ].map(([label, value, Icon]: any) => (
          <div key={label} className="rounded-2xl border border-slate-800 bg-slate-900/80 p-4">
            <Icon className="h-5 w-5 text-cyan-300" />
            <p className="mt-3 text-xs uppercase tracking-[0.2em] text-slate-500">{label}</p>
            <p className="mt-2 text-3xl font-black">{value}</p>
          </div>
        ))}
      </div>

      {panel("Integrated KPI Trend", "Throughput, latency, jitter, and QoE markers in one NOC chart.", Activity, <DashboardTrafficComplex history={history} />)}

      <div className="grid gap-6 xl:grid-cols-2">
        {panel("SLA Radar Profile", "High-level quality shape across capacity, latency, jitter, QoE, and reliability.", ShieldCheck, <DashboardSlaRadar history={history} alerts={alerts} />)}
        {panel("Capacity Distribution", "Throughput bars colored by QoE condition.", BarChart3, <DashboardCapacityBars history={history} />)}
      </div>
    </section>
  );
}

export function RealtimeEngineerConsole() {
  const { history, alerts } = useTelemetry();

  return (
    <section className="mt-8 space-y-6">
      <div>
        <h2 className="text-2xl font-black text-white">Realtime Engineering Console</h2>
        <p className="mt-2 text-sm text-slate-400">
          Realtime-specific visualization: oscilloscope waveform, latency waterfall, and event lanes.
        </p>
      </div>

      {panel("Latency / Jitter Oscilloscope", "Realtime waveform view for burst detection and congestion diagnosis.", Radio, <RealtimeOscilloscope history={history} />)}

      <div className="grid gap-6 xl:grid-cols-2">
        {panel("Probe Waterfall", "Interval-by-interval latency pressure map.", Activity, <RealtimeWaterfall history={history} />)}
        {panel("Event Lanes", "Operational state per telemetry interval.", GitBranch, <RealtimeEventLanes history={history} alerts={alerts} />)}
      </div>
    </section>
  );
}

export function QoeEngineerLab() {
  const { history } = useTelemetry();
  const latest = history[0] || {};
  const qoe = n(latest.qoe_score);

  return (
    <section className="mt-8 space-y-6">
      <div>
        <h2 className="text-2xl font-black text-white">Streaming QoE Engineering Detail</h2>
        <p className="mt-2 text-sm text-slate-400">
          QoE-specific view: quality gauge, degradation budget, and streaming decision matrix.
        </p>
      </div>

      <div className="grid gap-6 xl:grid-cols-[360px_1fr]">
        {panel("QoE Quality Gauge", "Current perceived streaming experience index.", Gauge, <QoeGauge value={qoe} />)}
        {panel("Degradation Budget", "How latency, jitter, and packet loss reduce the QoE score.", AlertTriangle, <QoeDegradationStack history={history} />)}
      </div>

      {panel("Streaming Decision Matrix", "Actionable interpretation for streaming playback condition.", Box, <QoeDecisionMatrix history={history} />)}
    </section>
  );
}
