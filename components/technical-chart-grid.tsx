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

function points(data: H[], key: keyof H, w: number, h: number, pad = 22) {
  const arr = data.slice(0, 24).reverse();
  const vals = arr.map((x) => n(x[key]));
  const hi = Math.max(...vals, 1);
  const lo = Math.min(...vals, 0);
  const range = Math.max(hi - lo, 1);

  return arr.map((d, i) => {
    const x = pad + (i * (w - pad * 2)) / Math.max(arr.length - 1, 1);
    const y = h - pad - ((n(d[key]) - lo) / range) * (h - pad * 2);
    return `${x},${y}`;
  }).join(" ");
}

function ChartBox({
  title,
  subtitle,
  icon: Icon,
  children,
}: {
  title: string;
  subtitle?: string;
  icon?: any;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
      <div className="mb-4 flex items-start justify-between gap-4">
        <div>
          <h3 className="text-lg font-black text-white">{title}</h3>
          {subtitle ? <p className="mt-1 text-xs text-slate-500">{subtitle}</p> : null}
        </div>
        {Icon ? (
          <div className="rounded-xl border border-cyan-500/20 bg-cyan-500/10 p-2">
            <Icon className="h-5 w-5 text-cyan-300" />
          </div>
        ) : null}
      </div>
      {children}
    </div>
  );
}

function MultiLineChart({ data }: { data: H[] }) {
  const w = 720;
  const h = 260;
  const hasData = data.length > 1;

  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="h-[280px] w-full">
      <rect x="0" y="0" width={w} height={h} rx="18" fill="#020617" />
      {[0, 1, 2, 3, 4].map((i) => (
        <line
          key={i}
          x1="35"
          x2={w - 20}
          y1={30 + i * 45}
          y2={30 + i * 45}
          stroke="#1e293b"
          strokeDasharray="5 5"
        />
      ))}
      {hasData ? (
        <>
          <polyline points={points(data, "throughput", w, h)} fill="none" stroke="#06b6d4" strokeWidth="3" />
          <polyline points={points(data, "latency", w, h)} fill="none" stroke="#eab308" strokeWidth="3" />
          <polyline points={points(data, "jitter", w, h)} fill="none" stroke="#a855f7" strokeWidth="3" />
        </>
      ) : (
        <text x="300" y="130" fill="#64748b" fontSize="15">Waiting for telemetry...</text>
      )}
      <text x="35" y="245" fill="#06b6d4" fontSize="12">Throughput</text>
      <text x="140" y="245" fill="#eab308" fontSize="12">Latency</text>
      <text x="220" y="245" fill="#a855f7" fontSize="12">Jitter</text>
    </svg>
  );
}

function BarChart({ data, metric }: { data: H[]; metric: keyof H }) {
  const arr = data.slice(0, 16).reverse();
  const hi = Math.max(...arr.map((x) => n(x[metric])), 1);

  return (
    <div className="flex h-[190px] items-end gap-2 rounded-2xl bg-slate-950 p-4">
      {arr.map((item, i) => {
        const value = n(item[metric]);
        const height = Math.max((value / hi) * 150, 3);
        return (
          <div key={i} className="flex flex-1 flex-col items-center justify-end gap-2">
            <div
              className="w-full rounded-t-lg bg-cyan-400/80 shadow-[0_0_18px_rgba(34,211,238,0.35)]"
              style={{ height }}
              title={`${metric}: ${value}`}
            />
          </div>
        );
      })}
    </div>
  );
}

function RiskMatrix({ data, alerts }: { data: H[]; alerts: AlertItem[] }) {
  const latency = avg(data, "latency");
  const jitter = avg(data, "jitter");
  const qoe = avg(data, "qoe_score");
  const risk =
    alerts.length > 0 || qoe < 60 ? 3 :
    qoe < 75 || latency > 120 || jitter > 40 ? 2 :
    qoe < 90 || latency > 80 || jitter > 20 ? 1 :
    0;

  const cells = [
    ["LOW", "Healthy streaming path", "border-emerald-500/40 bg-emerald-500/10 text-emerald-300"],
    ["WATCH", "QoE needs monitoring", "border-cyan-500/40 bg-cyan-500/10 text-cyan-300"],
    ["RISK", "Optimization required", "border-yellow-500/40 bg-yellow-500/10 text-yellow-300"],
    ["CRITICAL", "Immediate action", "border-red-500/40 bg-red-500/10 text-red-300"],
  ];

  return (
    <div className="grid gap-3 md:grid-cols-4">
      {cells.map((cell, i) => (
        <div
          key={cell[0]}
          className={`rounded-2xl border p-4 ${i === risk ? cell[2] : "border-slate-800 bg-slate-950 text-slate-500"}`}
        >
          <p className="text-2xl font-black">{cell[0]}</p>
          <p className="mt-2 text-xs">{cell[1]}</p>
        </div>
      ))}
    </div>
  );
}

function Pipeline3D({ data, alerts }: { data: H[]; alerts: AlertItem[] }) {
  const nodes = [
    { name: "Browser Probe", detail: "Client QoE sample", icon: Activity, status: data.length ? "ONLINE" : "WAIT" },
    { name: "Cloud Run Frontend", detail: "Next.js UI + export", icon: Server, status: "ONLINE" },
    { name: "FastAPI Gateway", detail: "QoS metrics API", icon: GitBranch, status: "ONLINE" },
    { name: "Cloud SQL", detail: "Operational DB", icon: Database, status: "RUNNABLE" },
    { name: "Analytics Layer", detail: "Reports / alerts / ML", icon: BarChart3, status: alerts.length ? "ALERT" : "STABLE" },
  ];

  return (
    <div className="grid gap-4 lg:grid-cols-5" style={{ perspective: "1200px" }}>
      {nodes.map((node, index) => {
        const Icon = node.icon;
        const danger = node.status === "ALERT" || node.status === "WAIT";
        return (
          <div
            key={node.name}
            className={`rounded-3xl border p-5 shadow-2xl transition hover:-translate-y-2 ${
              danger ? "border-yellow-500/40 bg-yellow-500/10" : "border-emerald-500/30 bg-emerald-500/10"
            }`}
            style={{
              transform: `rotateY(${(index - 2) * 4}deg) rotateX(4deg)`,
              transformStyle: "preserve-3d",
            }}
          >
            <Icon className={danger ? "h-6 w-6 text-yellow-300" : "h-6 w-6 text-emerald-300"} />
            <h4 className="mt-4 font-black text-white">{node.name}</h4>
            <p className="mt-2 text-xs text-slate-400">{node.detail}</p>
            <p className={danger ? "mt-4 text-xs font-black text-yellow-300" : "mt-4 text-xs font-black text-emerald-300"}>
              {node.status}
            </p>
          </div>
        );
      })}
    </div>
  );
}

export function TechnicalChartGrid({ scope = "dashboard" }: { scope?: string }) {
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
    } catch {}
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

  const summary = useMemo(() => {
    return {
      avgThroughput: avg(history, "throughput"),
      avgLatency: avg(history, "latency"),
      avgJitter: avg(history, "jitter"),
      avgQoe: avg(history, "qoe_score"),
      minThroughput: min(history, "throughput"),
      maxLatency: max(history, "latency"),
    };
  }, [history]);

  return (
    <section className="mt-8 space-y-6">
      <div>
        <h2 className="text-2xl font-black text-white">Carrier-Grade Technical Visualization Layer</h2>
        <p className="mt-2 text-sm text-slate-400">
          Useful charts only: telemetry trend, QoE distribution, SLA risk, and 3D service pipeline from real QoE history.
          Scope: {scope}.
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-4">
        <div className="rounded-2xl border border-slate-800 bg-slate-900/80 p-4">
          <Zap className="h-5 w-5 text-cyan-300" />
          <p className="mt-3 text-xs uppercase tracking-[0.2em] text-slate-500">Avg Throughput</p>
          <p className="mt-2 text-3xl font-black">{summary.avgThroughput.toFixed(2)} Mbps</p>
        </div>
        <div className="rounded-2xl border border-slate-800 bg-slate-900/80 p-4">
          <Gauge className="h-5 w-5 text-yellow-300" />
          <p className="mt-3 text-xs uppercase tracking-[0.2em] text-slate-500">Avg Latency</p>
          <p className="mt-2 text-3xl font-black">{summary.avgLatency.toFixed(2)} ms</p>
        </div>
        <div className="rounded-2xl border border-slate-800 bg-slate-900/80 p-4">
          <Radio className="h-5 w-5 text-purple-300" />
          <p className="mt-3 text-xs uppercase tracking-[0.2em] text-slate-500">Avg Jitter</p>
          <p className="mt-2 text-3xl font-black">{summary.avgJitter.toFixed(2)} ms</p>
        </div>
        <div className="rounded-2xl border border-slate-800 bg-slate-900/80 p-4">
          <AlertTriangle className="h-5 w-5 text-red-300" />
          <p className="mt-3 text-xs uppercase tracking-[0.2em] text-slate-500">Active Alerts</p>
          <p className="mt-2 text-3xl font-black">{alerts.length}</p>
        </div>
      </div>

      <ChartBox title="Multi-Metric Trend" subtitle="Throughput, latency, and jitter in one telemetry window." icon={Activity}>
        <MultiLineChart data={history} />
      </ChartBox>

      <div className="grid gap-6 xl:grid-cols-2">
        <ChartBox title="QoE Score Distribution" subtitle="Shows whether streaming condition is consistently healthy." icon={BarChart3}>
          <BarChart data={history} metric="qoe_score" />
        </ChartBox>

        <ChartBox title="Latency Stress Distribution" subtitle="Useful for detecting buffering, congestion, or API response spikes." icon={Gauge}>
          <BarChart data={history} metric="latency" />
        </ChartBox>
      </div>

      <ChartBox title="SLA Risk Matrix" subtitle="Risk class derived from QoE, latency, jitter, and active alerts." icon={AlertTriangle}>
        <RiskMatrix data={history} alerts={alerts} />
      </ChartBox>

      <ChartBox title="3D Cloud Service Pipeline" subtitle="Visual dependency of browser probe, Cloud Run, API, database, and analytics." icon={Box}>
        <Pipeline3D data={history} alerts={alerts} />
      </ChartBox>
    </section>
  );
}
