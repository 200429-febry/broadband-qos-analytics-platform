"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Search,
  LayoutDashboard,
  Activity,
  Radio,
  Map,
  BrainCircuit,
  Server,
  AlertTriangle,
  FileText,
  Rocket,
  BarChart3,
  Database,
  ClipboardList,
  Users,
  Settings,
  Network,
} from "lucide-react";

const SEARCH_ITEMS = [
  { title: "Dashboard", path: "/", keywords: "home overview noc qos kpi dashboard", icon: LayoutDashboard },
  { title: "Realtime Monitor", path: "/monitoring", keywords: "realtime monitor latency throughput jitter packet loss live", icon: Activity },
  { title: "QoS Analytics", path: "/analytics", keywords: "qos analytics throughput latency packet loss jitter chart", icon: Radio },
  { title: "Coverage Map", path: "/coverage", keywords: "coverage bts cell tower opencellid lte gsm map", icon: Map },
  { title: "Prediction ML", path: "/predictions", keywords: "prediction ml machine learning forecast anomaly", icon: BrainCircuit },
  { title: "Stream Health", path: "/stream", keywords: "stream health telemetry ingestion pipeline", icon: Server },
  { title: "Incidents", path: "/incidents", keywords: "incident outage problem event ticket", icon: AlertTriangle },
  { title: "Reports", path: "/reports", keywords: "report pdf export document summary", icon: FileText },
  { title: "Deployment", path: "/deployment", keywords: "deploy cloud run gcp release revision", icon: Rocket },
  { title: "Observability", path: "/observability", keywords: "observability prometheus grafana metric log trace", icon: BarChart3 },
  { title: "Alert Center", path: "/alerts", keywords: "alert warning critical notification system critical", icon: AlertTriangle },
  { title: "Topology", path: "/topology", keywords: "topology network node architecture backhaul", icon: Network },
  { title: "Database Monitor", path: "/database", keywords: "database db sql cloud sql storage table", icon: Database },
  { title: "Audit Log", path: "/audit", keywords: "audit log history activity security", icon: ClipboardList },
  { title: "User Management", path: "/users", keywords: "user admin account role management viewer engineer", icon: Users },
  { title: "Settings", path: "/settings", keywords: "setting configuration preference system", icon: Settings },
];

export function GlobalSearch() {
  const router = useRouter();
  const rootRef = useRef<HTMLDivElement | null>(null);

  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();

    if (!q) return SEARCH_ITEMS.slice(0, 6);

    return SEARCH_ITEMS.filter((item) => {
      const haystack = `${item.title} ${item.keywords} ${item.path}`.toLowerCase();
      return haystack.includes(q);
    }).slice(0, 8);
  }, [query]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (!rootRef.current) return;

      if (!rootRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        setQuery("");
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, []);

  const goTo = (path: string) => {
    setQuery("");
    setOpen(false);
    router.push(path);
  };

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();

    if (results.length > 0) {
      goTo(results[0].path);
    }
  };

  return (
    <div ref={rootRef} className="relative w-full max-w-[520px]">
      <form onSubmit={handleSubmit}>
        <div className="flex items-center gap-2 rounded-full border border-slate-800 bg-slate-950/80 px-4 py-2 focus-within:border-emerald-400 focus-within:ring-2 focus-within:ring-emerald-500/20">
          <Search className="h-4 w-4 text-slate-500" />

          <input
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              setOpen(true);
            }}
            onFocus={() => setOpen(true)}
            placeholder="Search modules, BTS, streams, alerts..."
            className="w-full bg-transparent text-sm text-slate-200 outline-none placeholder:text-slate-500"
          />
        </div>
      </form>

      {open && (
        <div className="absolute left-0 top-12 z-[99999] w-full overflow-hidden rounded-2xl border border-slate-800 bg-slate-950 shadow-2xl">
          <div className="border-b border-slate-800 px-4 py-2 text-[11px] uppercase tracking-[0.2em] text-slate-500">
            Global Search
          </div>

          {results.length > 0 ? (
            <div className="max-h-[360px] overflow-y-auto p-2">
              {results.map((item) => {
                const Icon = item.icon;

                return (
                  <button
                    key={item.path}
                    type="button"
                    onClick={() => goTo(item.path)}
                    className="flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left hover:bg-slate-900"
                  >
                    <span className="flex h-9 w-9 items-center justify-center rounded-lg border border-slate-800 bg-slate-900 text-emerald-300">
                      <Icon className="h-4 w-4" />
                    </span>

                    <span>
                      <span className="block text-sm font-semibold text-slate-100">
                        {item.title}
                      </span>
                      <span className="block text-xs text-slate-500">
                        {item.path}
                      </span>
                    </span>
                  </button>
                );
              })}
            </div>
          ) : (
            <div className="px-4 py-6 text-sm text-slate-400">
              No module found for "{query}".
            </div>
          )}

          <div className="border-t border-slate-800 px-4 py-2 text-[11px] text-slate-500">
            Enter opens first result • Esc clears • Click outside closes
          </div>
        </div>
      )}
    </div>
  );
}
