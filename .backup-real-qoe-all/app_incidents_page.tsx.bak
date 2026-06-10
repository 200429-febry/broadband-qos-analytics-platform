"use client";

import { useEffect, useMemo, useState } from "react";

type AlertItem = {
  id: number | string;
  type: string;
  message: string;
  metric: string;
  time: string;
  source?: string;
};

function SummaryCard({ title, value, color }: { title: string; value: string | number; color: string }) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <p className="text-sm text-slate-400">{title}</p>
      <p className={`mt-3 text-3xl font-black ${color}`}>{value}</p>
    </div>
  );
}

export default function IncidentsPage() {
  const [alerts, setAlerts] = useState<AlertItem[]>([]);

  const fetchIncidents = async () => {
    const res = await fetch(`/api/qos-alerts?x=${Date.now()}`, { cache: "no-store" });
    const data = await res.json();
    setAlerts(Array.isArray(data) ? data : []);
  };

  useEffect(() => {
    fetchIncidents();
    const interval = setInterval(fetchIncidents, 5000);
    return () => clearInterval(interval);
  }, []);

  const summary = useMemo(() => ({
    total: alerts.length,
    critical: alerts.filter((a) => a.type === "critical").length,
    warning: alerts.filter((a) => a.type === "warning").length,
    state: alerts.length ? "ACTIVE" : "STABLE",
  }), [alerts]);

  return (
    <main className="space-y-8 p-6 text-white">
      <div>
        <h1 className="text-3xl font-black">Incident Timeline</h1>
        <p className="mt-2 text-slate-400">Fault management timeline for real QoE degradation, latency spikes, jitter risk, and network recovery events.</p>
      </div>

      <section className="grid gap-4 md:grid-cols-4">
        <SummaryCard title="Total Events" value={summary.total} color="text-cyan-400" />
        <SummaryCard title="Critical" value={summary.critical} color="text-red-400" />
        <SummaryCard title="Warnings" value={summary.warning} color="text-yellow-400" />
        <SummaryCard title="System State" value={summary.state} color={summary.state === "STABLE" ? "text-emerald-400" : "text-amber-400"} />
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6">
        <div className="mb-5 flex items-center justify-between">
          <div>
            <h2 className="text-xl font-black">Live Fault Timeline</h2>
            <p className="text-sm text-slate-400">Auto-refresh from real QoE alert engine.</p>
          </div>
          <button onClick={fetchIncidents} className="rounded-xl border border-emerald-500/30 px-4 py-2 text-sm font-bold text-emerald-300 hover:bg-emerald-500/10">
            Refresh
          </button>
        </div>

        {alerts.length === 0 ? (
          <div className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-10 text-center">
            <p className="text-lg font-black text-emerald-300">No Active Incidents</p>
            <p className="mt-2 text-sm text-slate-400">Real QoE telemetry is currently within normal operating thresholds.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {alerts.map((incident) => (
              <div key={incident.id} className="rounded-xl border border-red-500/20 bg-red-500/10 p-4">
                <p className="font-bold text-red-300">{incident.message}</p>
                <p className="mt-1 text-sm text-slate-400">{incident.metric} • {incident.time} • {incident.source || "Real QoE"}</p>
              </div>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
