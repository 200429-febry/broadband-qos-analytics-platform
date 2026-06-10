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

function SummaryCard({ label, value, color }: { label: string; value: string | number; color: string }) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <p className="text-sm text-slate-400">{label}</p>
      <p className={`mt-3 text-3xl font-black ${color}`}>{value}</p>
    </div>
  );
}

export default function AlertsPage() {
  const [alerts, setAlerts] = useState<AlertItem[]>([]);

  const fetchAlerts = async () => {
    const res = await fetch(`/api/qos-alerts?x=${Date.now()}`, { cache: "no-store" });
    const data = await res.json();
    setAlerts(Array.isArray(data) ? data : []);
  };

  useEffect(() => {
    fetchAlerts();
    const interval = setInterval(fetchAlerts, 3000);
    return () => clearInterval(interval);
  }, []);

  const summary = useMemo(() => ({
    total: alerts.length,
    critical: alerts.filter((a) => a.type === "critical").length,
    warning: alerts.filter((a) => a.type === "warning").length,
    threshold: alerts.filter((a) => a.source?.includes("Real")).length,
  }), [alerts]);

  return (
    <main className="space-y-8 p-6 text-white">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-3xl font-black">Alert Center</h1>
          <p className="mt-2 text-slate-400">Operational alert console based on real Streaming QoE threshold violations.</p>
        </div>
        <button onClick={fetchAlerts} className="rounded-xl border border-emerald-500/30 px-5 py-3 text-sm font-bold text-emerald-300 hover:bg-emerald-500/10">
          Refresh
        </button>
      </div>

      <section className="grid gap-4 md:grid-cols-4">
        <SummaryCard label="Active Alerts" value={summary.total} color="text-cyan-400" />
        <SummaryCard label="Critical" value={summary.critical} color="text-red-400" />
        <SummaryCard label="Warning" value={summary.warning} color="text-yellow-400" />
        <SummaryCard label="Real QoE Threshold" value={summary.threshold} color="text-emerald-400" />
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/60 p-6">
        <h2 className="text-xl font-black">Recent Critical & Warning Events</h2>
        <p className="mt-2 text-sm text-slate-400">Alerts are generated from real browser-to-Cloud Run QoE probe thresholds.</p>

        <div className="mt-5 space-y-3">
          {alerts.length === 0 ? (
            <div className="rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-10 text-center">
              <p className="text-lg font-black text-emerald-300">No Active Alerts</p>
              <p className="mt-2 text-sm text-slate-400">Current QoE and network state are within acceptable operating thresholds.</p>
            </div>
          ) : (
            alerts.map((alert) => (
              <div key={alert.id} className="rounded-xl border border-red-500/20 bg-red-500/10 p-4">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="font-bold text-red-300">{alert.message}</p>
                    <p className="mt-1 text-sm text-slate-400">{alert.metric} • {alert.time} • {alert.source || "Real QoE"}</p>
                  </div>
                  <span className="rounded-full bg-red-500/10 px-3 py-1 text-xs font-bold uppercase text-red-300">{alert.type}</span>
                </div>
              </div>
            ))
          )}
        </div>
      </section>
    </main>
  );
}
