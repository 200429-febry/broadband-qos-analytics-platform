"use client";

import { useEffect, useMemo, useState } from "react";
import { Bell, LogOut, ShieldAlert } from "lucide-react";
import { GlobalSearch } from "@/components/global-search";

type AlertItem = {
  id?: number | string;
  type?: string;
  message?: string;
  metric?: string;
  time?: string;
  source?: string;
};

export function Header() {
  const [alerts, setAlerts] = useState<AlertItem[]>([]);

  const fetchAlerts = async () => {
    try {
      const res = await fetch(`/api/qos-alerts?x=${Date.now()}`, { cache: "no-store" });
      const data = await res.json();
      setAlerts(Array.isArray(data) ? data : []);
    } catch {
      setAlerts([]);
    }
  };

  useEffect(() => {
    fetchAlerts();
    const interval = setInterval(fetchAlerts, 5000);
    return () => clearInterval(interval);
  }, []);

  const criticalCount = useMemo(
    () => alerts.filter((a) => a.type === "critical").length,
    [alerts]
  );

  const systemLabel = criticalCount > 0 ? "System Critical" : "System Stable";
  const badgeLabel = alerts.length > 99 ? "99+" : String(alerts.length);

  const logout = () => {
    localStorage.removeItem("access_token");
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    window.location.href = "/login";
  };

  return (
    <header className="sticky top-0 z-[2000] border-b border-slate-800 bg-slate-950/90 backdrop-blur-xl">
      <div className="flex h-16 items-center justify-between gap-4 px-6">
        <GlobalSearch />

        <div className="fixed right-6 top-3 z-[2147483647] flex items-center gap-3">
          <a
            href="/alerts"
            className={`flex cursor-pointer items-center gap-2 rounded-lg px-3 py-2 text-xs font-semibold uppercase tracking-[0.2em] transition active:scale-95 ${
              criticalCount > 0
                ? "text-red-400 hover:bg-red-500/10"
                : "text-emerald-400 hover:bg-emerald-500/10"
            }`}
          >
            <span
              className={`h-3 w-3 rounded-full ${
                criticalCount > 0
                  ? "bg-red-500 shadow-[0_0_16px_rgba(239,68,68,0.9)]"
                  : "bg-emerald-500 shadow-[0_0_16px_rgba(16,185,129,0.8)]"
              }`}
            />
            <ShieldAlert className="h-4 w-4" />
            <span className="hidden md:inline">{systemLabel}</span>
          </a>

          <a
            href="/alerts"
            title="Open Alert Center"
            aria-label="Open Alert Center"
            className="relative flex h-10 w-10 cursor-pointer items-center justify-center rounded-lg transition hover:bg-red-500/10 active:scale-95"
          >
            <Bell className="h-5 w-5 text-slate-300" />
            {alerts.length > 0 ? (
              <span className="pointer-events-none absolute -right-1 -top-1 rounded-full bg-red-500 px-1.5 text-[10px] font-bold text-white">
                {badgeLabel}
              </span>
            ) : null}
          </a>

          <button
            type="button"
            onClick={logout}
            className="flex cursor-pointer items-center gap-2 rounded-lg border border-slate-800 bg-slate-900 px-3 py-2 text-sm text-slate-300 hover:bg-slate-800 active:scale-95"
          >
            <LogOut className="h-4 w-4" />
            <span className="hidden sm:inline">Logout</span>
          </button>
        </div>
      </div>
    </header>
  );
}
