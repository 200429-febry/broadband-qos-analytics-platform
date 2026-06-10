"use client";

import { useEffect, useState } from "react";
import { ClipboardList, RefreshCw, ShieldCheck } from "lucide-react";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

interface AuditLog {
  id: number;
  username: string;
  role: string;
  action: string;
  detail: string;
  created_at: string;
}

export default function AuditLogPage() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [lastUpdated, setLastUpdated] = useState("");

  const fetchLogs = async () => {
    const res = await fetch(`${API_URL}/api/admin/audit/logs?x=${Date.now()}`, {
      cache: "no-store",
    });

    const data = await res.json();

    if (Array.isArray(data)) {
      setLogs(data);
      setLastUpdated(new Date().toLocaleTimeString());
    }
  };

  useEffect(() => {
    fetchLogs();

    const interval = setInterval(fetchLogs, 3000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-6 p-6 text-white">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-3xl font-bold">Audit Log</h1>
          <p className="text-slate-400">
            Admin-only activity trail for governance, user accountability, and security monitoring.
          </p>
        </div>

        <button
          onClick={fetchLogs}
          className="flex items-center gap-2 rounded-lg border border-emerald-500/30 bg-emerald-500/10 px-4 py-2 text-emerald-300"
        >
          <RefreshCw className="h-4 w-4" />
          Refresh
        </button>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <Card title="Total Events" value={logs.length} />
        <Card
          title="Admin Events"
          value={logs.filter((log) => log.role === "Admin").length}
        />
        <Card
          title="Latest Update"
          value={lastUpdated || "-"}
          small
        />
      </div>

      <div className="rounded-xl border border-slate-700 bg-slate-900 p-5">
        <div className="mb-4 flex items-center gap-2">
          <ClipboardList className="h-5 w-5 text-cyan-400" />
          <h2 className="text-xl font-semibold">Latest User Activity</h2>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="text-slate-400">
              <tr className="border-b border-slate-700">
                <th className="py-3">Time</th>
                <th>User</th>
                <th>Role</th>
                <th>Action</th>
                <th>Detail</th>
              </tr>
            </thead>

            <tbody>
              {logs.map((log) => (
                <tr key={log.id} className="border-b border-slate-800">
                  <td className="py-3 text-slate-300">
                    {new Date(log.created_at).toLocaleString()}
                  </td>
                  <td className="text-cyan-300">{log.username}</td>
                  <td>
                    <span className="rounded-full bg-emerald-500/10 px-2 py-1 text-xs text-emerald-300">
                      {log.role}
                    </span>
                  </td>
                  <td className="font-semibold text-white">{log.action}</td>
                  <td className="text-slate-400">{log.detail}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {!logs.length && (
          <div className="mt-6 flex items-center gap-2 rounded-xl border border-slate-700 bg-slate-950 p-4 text-slate-400">
            <ShieldCheck className="h-5 w-5" />
            No audit activity recorded yet.
          </div>
        )}
      </div>
    </div>
  );
}

function Card({
  title,
  value,
  small,
}: {
  title: string;
  value: string | number;
  small?: boolean;
}) {
  return (
    <div className="rounded-xl border border-slate-700 bg-slate-900 p-5">
      <p className="text-sm text-slate-400">{title}</p>
      <p className={`mt-2 font-bold text-emerald-400 ${small ? "text-xl" : "text-3xl"}`}>
        {value}
      </p>
    </div>
  );
}
