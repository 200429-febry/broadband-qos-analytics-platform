#!/bin/bash
set -e

echo "=================================================="
echo "PATCH AUTH + FLOATING PANEL + ROLE PERSISTENCE"
echo "=================================================="

mkdir -p .backup-auth-float-role

for f in \
  components/aksara-live-shell.tsx \
  components/global-qoe-probe.tsx \
  app/auth/google-success/page.tsx \
  app/users/page.tsx \
  backend/main.py \
  backend/.gcloudignore
do
  if [ -f "$f" ]; then
    cp "$f" ".backup-auth-float-role/$(echo "$f" | tr '/' '_').bak"
    echo "Backup: $f"
  fi
done

echo "=================================================="
echo "1. FIX FLOATING LIVE PANEL: hidden before login"
echo "=================================================="

cat > components/aksara-live-shell.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";
import { usePathname } from "next/navigation";
import { Activity, Bell, Globe2, Gauge, Radio, Zap } from "lucide-react";

type Metric = {
  throughput?: number;
  latency?: number;
  jitter?: number;
  packet_loss?: number;
  qoe_score?: number;
  streaming_status?: string;
  source?: string;
  timestamp?: string;
};

type AlertItem = {
  id?: string | number;
  type?: string;
  message?: string;
  metric?: string;
  time?: string;
  source?: string;
};

type Lang = "id" | "en";

const text = {
  id: {
    live: "Telemetri Live",
    source: "Sumber",
    qoe: "QoE",
    throughput: "Throughput",
    latency: "Latensi",
    jitter: "Jitter",
    alerts: "Alert",
    hide: "Sembunyikan",
    show: "Tampilkan",
    realProbe: "Probe real browser-ke-cloud",
  },
  en: {
    live: "Live Telemetry",
    source: "Source",
    qoe: "QoE",
    throughput: "Throughput",
    latency: "Latency",
    jitter: "Jitter",
    alerts: "Alerts",
    hide: "Hide",
    show: "Show",
    realProbe: "Real browser-to-cloud probe",
  },
};

function isPublicRoute(pathname: string) {
  return (
    pathname === "/login" ||
    pathname.startsWith("/login") ||
    pathname.startsWith("/auth") ||
    pathname.startsWith("/register")
  );
}

export function AksaraLiveShell() {
  const pathname = usePathname();
  const [mounted, setMounted] = useState(false);
  const [allowed, setAllowed] = useState(false);
  const [metric, setMetric] = useState<Metric | null>(null);
  const [alerts, setAlerts] = useState<AlertItem[]>([]);
  const [lang, setLang] = useState<Lang>("id");
  const [collapsed, setCollapsed] = useState(true);

  const t = text[lang];

  const checkAccess = () => {
    if (isPublicRoute(pathname)) {
      setAllowed(false);
      return;
    }

    const token =
      localStorage.getItem("access_token") ||
      localStorage.getItem("token");

    setAllowed(Boolean(token));
  };

  const fetchLive = async () => {
    if (!allowed) return;

    try {
      const [metricRes, alertRes] = await Promise.all([
        fetch(`/api/qos-metrics?x=${Date.now()}`, { cache: "no-store" }),
        fetch(`/api/qos-alerts?x=${Date.now()}`, { cache: "no-store" }),
      ]);

      const metricJson = await metricRes.json();
      const alertJson = await alertRes.json();

      setMetric(metricJson);
      setAlerts(Array.isArray(alertJson) ? alertJson : []);
    } catch {
      // keep previous value
    }
  };

  useEffect(() => {
    setMounted(true);

    const saved = localStorage.getItem("aksara-lang");
    if (saved === "id" || saved === "en") {
      setLang(saved);
      document.documentElement.lang = saved;
    }

    checkAccess();

    const onStorage = () => checkAccess();
    window.addEventListener("storage", onStorage);

    return () => window.removeEventListener("storage", onStorage);
  }, [pathname]);

  useEffect(() => {
    if (!mounted || !allowed) return;

    fetchLive();
    const interval = setInterval(fetchLive, 3000);

    const onRealtime = () => fetchLive();
    window.addEventListener("real-qoe-updated", onRealtime);

    return () => {
      clearInterval(interval);
      window.removeEventListener("real-qoe-updated", onRealtime);
    };
  }, [mounted, allowed]);

  const toggleLang = () => {
    const next = lang === "id" ? "en" : "id";
    setLang(next);
    localStorage.setItem("aksara-lang", next);
    document.documentElement.lang = next;
    window.dispatchEvent(new CustomEvent("aksara-lang-change", { detail: next }));
  };

  const statusColor = useMemo(() => {
    const qoe = Number(metric?.qoe_score ?? 0);
    if (qoe >= 90) return "text-emerald-300 border-emerald-500/30 bg-emerald-500/10";
    if (qoe >= 75) return "text-yellow-300 border-yellow-500/30 bg-yellow-500/10";
    return "text-red-300 border-red-500/30 bg-red-500/10";
  }, [metric]);

  if (!mounted || !allowed || isPublicRoute(pathname)) {
    return null;
  }

  if (collapsed) {
    return (
      <div className="fixed bottom-4 right-4 z-[2147483000] flex items-center gap-2">
        <button
          onClick={toggleLang}
          className="rounded-full border border-cyan-500/30 bg-slate-950/95 px-4 py-2 text-xs font-black text-cyan-300 shadow-2xl backdrop-blur-xl"
        >
          <Globe2 className="mr-2 inline h-4 w-4" />
          {lang.toUpperCase()}
        </button>

        <button
          onClick={() => setCollapsed(false)}
          className="rounded-full border border-emerald-500/30 bg-slate-950/95 px-4 py-2 text-xs font-black text-emerald-300 shadow-2xl backdrop-blur-xl"
        >
          {t.show} Live
        </button>
      </div>
    );
  }

  return (
    <div className="fixed bottom-4 right-4 z-[2147483000] w-[430px] max-w-[calc(100vw-24px)] rounded-2xl border border-slate-700 bg-slate-950/95 p-4 text-white shadow-2xl backdrop-blur-xl">
      <div className="mb-3 flex items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <Activity className="h-4 w-4 text-cyan-300" />
            <p className="text-sm font-black">{t.live}</p>
            <span className={`rounded-full border px-2 py-0.5 text-[10px] font-black ${statusColor}`}>
              {metric?.streaming_status || "WAITING"}
            </span>
          </div>
          <p className="mt-1 text-[11px] text-slate-500">{t.realProbe}</p>
        </div>

        <div className="flex gap-2">
          <button
            onClick={toggleLang}
            className="rounded-lg border border-cyan-500/30 px-3 py-2 text-xs font-black text-cyan-300 hover:bg-cyan-500/10"
          >
            {lang.toUpperCase()}
          </button>
          <button
            onClick={() => setCollapsed(true)}
            className="rounded-lg border border-slate-700 px-3 py-2 text-xs font-bold text-slate-300 hover:bg-slate-800"
          >
            {t.hide}
          </button>
        </div>
      </div>

      <div className="grid grid-cols-5 gap-2">
        <div className="rounded-xl border border-slate-800 bg-slate-900/80 p-2">
          <Zap className="mb-1 h-3.5 w-3.5 text-cyan-300" />
          <p className="text-[10px] text-slate-500">{t.throughput}</p>
          <p className="text-sm font-black">{metric?.throughput ?? 0}</p>
          <p className="text-[10px] text-slate-500">Mbps</p>
        </div>

        <div className="rounded-xl border border-slate-800 bg-slate-900/80 p-2">
          <Gauge className="mb-1 h-3.5 w-3.5 text-yellow-300" />
          <p className="text-[10px] text-slate-500">{t.latency}</p>
          <p className="text-sm font-black">{metric?.latency ?? 0}</p>
          <p className="text-[10px] text-slate-500">ms</p>
        </div>

        <div className="rounded-xl border border-slate-800 bg-slate-900/80 p-2">
          <Radio className="mb-1 h-3.5 w-3.5 text-purple-300" />
          <p className="text-[10px] text-slate-500">{t.jitter}</p>
          <p className="text-sm font-black">{metric?.jitter ?? 0}</p>
          <p className="text-[10px] text-slate-500">ms</p>
        </div>

        <div className="rounded-xl border border-slate-800 bg-slate-900/80 p-2">
          <Activity className="mb-1 h-3.5 w-3.5 text-emerald-300" />
          <p className="text-[10px] text-slate-500">{t.qoe}</p>
          <p className="text-sm font-black">{metric?.qoe_score ?? 0}</p>
          <p className="text-[10px] text-slate-500">score</p>
        </div>

        <div className="rounded-xl border border-slate-800 bg-slate-900/80 p-2">
          <Bell className="mb-1 h-3.5 w-3.5 text-red-300" />
          <p className="text-[10px] text-slate-500">{t.alerts}</p>
          <p className="text-sm font-black">{alerts.length}</p>
          <p className="text-[10px] text-slate-500">active</p>
        </div>
      </div>

      <div className="mt-3 rounded-xl border border-slate-800 bg-slate-900/70 px-3 py-2 text-[11px] text-slate-400">
        {t.source}:{" "}
        <span className="font-bold text-cyan-300">{metric?.source || "real-qoe-probe"}</span>
        {" "}• {metric?.timestamp || "-"}
      </div>
    </div>
  );
}
TSX

echo "=================================================="
echo "2. FIX GLOBAL QOE PROBE: do not run before login"
echo "=================================================="

cat > components/global-qoe-probe.tsx <<'TSX'
"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

function isPublicRoute(pathname: string) {
  return (
    pathname === "/login" ||
    pathname.startsWith("/login") ||
    pathname.startsWith("/auth") ||
    pathname.startsWith("/register")
  );
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function calculateQoe(latency: number, jitter: number, downloadMbps: number, uploadMbps: number) {
  const latencyPenalty = latency > 80 ? (latency - 80) * 0.18 : 0;
  const jitterPenalty = jitter > 20 ? (jitter - 20) * 0.7 : 0;
  const downloadPenalty = downloadMbps < 8 ? (8 - downloadMbps) * 6 : 0;
  const uploadPenalty = uploadMbps < 2 ? (2 - uploadMbps) * 5 : 0;

  return Math.round(
    clamp(100 - latencyPenalty - jitterPenalty - downloadPenalty - uploadPenalty, 0, 100)
  );
}

function getStatus(score: number) {
  if (score >= 90) return "EXCELLENT";
  if (score >= 75) return "STABLE";
  if (score >= 60) return "BUFFER RISK";
  return "POOR";
}

export function GlobalQoeProbe() {
  const pathname = usePathname();
  const lastLatencyRef = useRef<number | null>(null);
  const runningRef = useRef(false);

  function hasSession() {
    if (typeof window === "undefined") return false;
    if (isPublicRoute(pathname)) return false;

    return Boolean(
      localStorage.getItem("access_token") ||
      localStorage.getItem("token")
    );
  }

  async function measureLatency() {
    const t0 = performance.now();

    await fetch(`${API_URL}/api/qoe/ping?x=${Date.now()}`, {
      cache: "no-store",
    });

    const latency = performance.now() - t0;
    const previous = lastLatencyRef.current;
    const jitter = previous === null ? 0 : Math.abs(latency - previous);
    lastLatencyRef.current = latency;

    return { latency, jitter };
  }

  async function measureDownload() {
    const sizeKb = 512;
    const t0 = performance.now();

    const response = await fetch(
      `${API_URL}/api/qoe/download-fixed?size_kb=${sizeKb}&x=${Date.now()}`,
      { cache: "no-store" }
    );

    const buffer = await response.arrayBuffer();
    const durationS = Math.max((performance.now() - t0) / 1000, 0.001);

    return (buffer.byteLength * 8) / durationS / 1_000_000;
  }

  async function measureUpload() {
    const size = 128 * 1024;
    const payload = new Uint8Array(size);

    for (let i = 0; i < payload.length; i += 65536) {
      crypto.getRandomValues(payload.subarray(i, Math.min(i + 65536, payload.length)));
    }

    const t0 = performance.now();

    await fetch(`${API_URL}/api/qoe/upload?x=${Date.now()}`, {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      body: payload,
      cache: "no-store",
    });

    const durationS = Math.max((performance.now() - t0) / 1000, 0.001);

    return (payload.byteLength * 8) / durationS / 1_000_000;
  }

  async function runProbe() {
    if (!hasSession()) return;
    if (runningRef.current) return;
    if (document.visibilityState !== "visible") return;

    runningRef.current = true;

    try {
      const latencyResult = await measureLatency();
      const downloadMbps = await measureDownload();
      const uploadMbps = await measureUpload();

      const latency = +latencyResult.latency.toFixed(1);
      const jitter = +latencyResult.jitter.toFixed(1);
      const down = +downloadMbps.toFixed(2);
      const up = +uploadMbps.toFixed(2);
      const qoeScore = calculateQoe(latency, jitter, down, up);
      const status = getStatus(qoeScore);

      const sample = {
        time: new Date().toLocaleTimeString(),
        latency,
        jitter,
        downloadMbps: down,
        uploadMbps: up,
        backendMs: latency,
        qoeScore,
        status,
        source: "global-real-qoe-probe",
      };

      await fetch(`${API_URL}/api/qoe/sample`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(sample),
        cache: "no-store",
      });

      window.dispatchEvent(new CustomEvent("real-qoe-updated", { detail: sample }));
    } catch {
      // silent
    } finally {
      runningRef.current = false;
    }
  }

  useEffect(() => {
    if (!hasSession()) return;

    runProbe();

    const interval = setInterval(runProbe, 5000);

    const onVisible = () => {
      if (document.visibilityState === "visible") runProbe();
    };

    window.addEventListener("focus", runProbe);
    document.addEventListener("visibilitychange", onVisible);

    return () => {
      clearInterval(interval);
      window.removeEventListener("focus", runProbe);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [pathname]);

  return null;
}
TSX

echo "=================================================="
echo "3. FIX GOOGLE SUCCESS PAGE"
echo "=================================================="

mkdir -p app/auth/google-success

cat > app/auth/google-success/page.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ||
  "https://qos-api-gh3tn2a6oa-et.a.run.app";

function getEmailFromBrowser() {
  if (typeof window === "undefined") return "";

  const url = new URL(window.location.href);

  const fromQuery =
    url.searchParams.get("email") ||
    url.searchParams.get("user") ||
    url.searchParams.get("account");

  if (fromQuery) return fromQuery;

  const direct =
    localStorage.getItem("google_email") ||
    localStorage.getItem("auth_email") ||
    localStorage.getItem("email");

  if (direct) return direct;

  try {
    const storedUser = localStorage.getItem("user");
    if (storedUser) {
      const parsed = JSON.parse(storedUser);
      if (parsed?.email) return parsed.email;
    }
  } catch {
    // ignore
  }

  return "febriyadi845@gmail.com";
}

export default function GoogleSuccessPage() {
  const [email, setEmail] = useState("");
  const [teamAccess, setTeamAccess] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const canContinue = useMemo(() => Boolean(email), [email]);

  useEffect(() => {
    localStorage.removeItem("access_token");
    localStorage.removeItem("token");

    setEmail(getEmailFromBrowser());
  }, []);

  const finalizeLogin = async () => {
    if (!email) {
      setError("Google email not found.");
      return;
    }

    setLoading(true);
    setError("");

    try {
      const response = await fetch(`${API_URL}/api/auth/google/token`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email,
          teamAccess,
        }),
      });

      const data = await response.json();

      if (!response.ok || data.error || !data.access_token) {
        throw new Error(data.error || data.detail || "Failed to finalize Google Sign-In.");
      }

      const user = {
        id: data.id,
        username: data.username || email.split("@")[0],
        email: data.email || email,
        role: data.role || "Viewer",
      };

      localStorage.setItem("access_token", data.access_token);
      localStorage.setItem("token", data.access_token);
      localStorage.setItem("user", JSON.stringify(user));
      localStorage.setItem("google_email", user.email);

      window.dispatchEvent(new Event("storage"));
      window.location.href = "/";
    } catch (err: any) {
      setError(err?.message || "Failed to finalize Google Sign-In.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950 px-5 text-white">
      <div className="w-full max-w-xl rounded-3xl border border-cyan-500/30 bg-slate-900/70 p-8 shadow-2xl">
        <h1 className="text-center text-4xl font-black text-cyan-300">
          Complete Google Sign-In
        </h1>

        <p className="mx-auto mt-5 max-w-md text-center text-lg text-slate-400">
          New Google accounts are automatically created as Viewer.
        </p>

        <div className="mt-8 rounded-2xl border border-slate-700 bg-slate-950 p-5">
          <p className="text-sm text-slate-400">Google Account</p>
          <p className="mt-2 break-all text-xl font-black">{email || "loading..."}</p>
        </div>

        <label className="mt-6 flex cursor-pointer gap-4 rounded-2xl border border-slate-700 bg-slate-950 p-5">
          <input
            type="checkbox"
            checked={teamAccess}
            onChange={(e) => setTeamAccess(e.target.checked)}
            className="mt-1 h-5 w-5"
          />

          <span>
            <span className="block text-lg font-black">Are you AKSARA Team?</span>
            <span className="mt-1 block text-sm text-slate-400">
              Admin access is only granted for allowlisted team emails.
            </span>
          </span>
        </label>

        <button
          onClick={finalizeLogin}
          disabled={!canContinue || loading}
          className="mt-8 w-full rounded-2xl bg-cyan-300 px-5 py-4 text-lg font-black text-slate-950 hover:bg-cyan-200 disabled:opacity-60"
        >
          {loading ? "Finalizing..." : "Continue to Dashboard"}
        </button>

        {error ? (
          <p className="mt-5 rounded-xl border border-red-500/30 bg-red-500/10 p-3 text-center text-sm text-red-300">
            {error}
          </p>
        ) : null}
      </div>
    </main>
  );
}
TSX

echo "=================================================="
echo "4. FIX USER ROLE FRONTEND SELECT"
echo "=================================================="

python3 <<'PY'
from pathlib import Path
import re

p = Path("app/users/page.tsx")

if not p.exists():
    print("⚠️ app/users/page.tsx not found")
    raise SystemExit(0)

s = p.read_text()

old = '''onChange={(e) =>
                        setPendingRoles((prev) => ({
                          ...prev,
                          [user.id]: e.target.value,
                        }))
                      }'''

new = '''onChange={(e) => {
                        const nextRole = e.target.value;
                        setPendingRoles((prev) => ({
                          ...prev,
                          [user.id]: nextRole,
                        }));
                        updateRole(user.id, user.username, nextRole);
                      }}'''

if old in s:
    s = s.replace(old, new)
    print("✅ patched exact role select")
else:
    pattern = r'onChange=\{\(e\)\s*=>\s*setPendingRoles\(\(prev\)\s*=>\s*\(\{\s*\.\.\.prev,\s*\[user\.id\]:\s*e\.target\.value,\s*\}\)\)\s*\}'
    s, count = re.subn(pattern, new, s, count=1, flags=re.S)
    print(f"role select regex replacements: {count}")

insert_after = 'setMessage("Role updated successfully.");'

local_storage_patch = '''
      try {
        const stored = localStorage.getItem("user");
        if (stored) {
          const parsed = JSON.parse(stored);
          if (Number(parsed.id) === Number(userId)) {
            parsed.role = newRole;
            localStorage.setItem("user", JSON.stringify(parsed));
          }
        }
      } catch {
        // ignore localStorage sync error
      }
'''

if insert_after in s and "parsed.role = newRole;" not in s:
    s = s.replace(insert_after, insert_after + local_storage_patch)
    print("✅ localStorage role sync added")

p.write_text(s)
PY

echo "=================================================="
echo "5. FIX BACKEND ROLE PATCH WITHOUT BREAKING LOGIN BODY"
echo "=================================================="

python3 <<'PY'
from pathlib import Path
import re

p = Path("backend/main.py")

if not p.exists():
    print("❌ backend/main.py not found")
    raise SystemExit(1)

s = p.read_text()

# Remove older risky patch blocks if present
s = re.sub(
    r'\n?# === USER ROLE PERSISTENCE PATCH START ===.*?# === USER ROLE PERSISTENCE PATCH END ===\n?',
    '\n',
    s,
    flags=re.S
)

block = r'''
# === SAFE USER ROLE PERSISTENCE PATCH START ===
# Safe middleware:
# - Does not read request body except for the exact endpoints it fully handles.
# - Keeps Google Sign-In working even if DB lookup fails.
# - Makes role update persistent in users table when DB is available.

import json as _json_safe_role
import os as _os_safe_role
import re as _re_safe_role
from datetime import datetime as _dt_safe_role, timedelta as _td_safe_role

try:
    import psycopg2 as _psycopg2_safe_role
except Exception:
    _psycopg2_safe_role = None

try:
    from jose import jwt as _jwt_safe_role
except Exception:
    _jwt_safe_role = None

from starlette.responses import JSONResponse as _JSONResponseSafeRole


def _safe_role_db_url():
    url = (
        _os_safe_role.getenv("DATABASE_URL")
        or _os_safe_role.getenv("POSTGRES_URL")
        or _os_safe_role.getenv("SQLALCHEMY_DATABASE_URL")
        or ""
    )

    if url.startswith("postgresql+psycopg2://"):
        url = url.replace("postgresql+psycopg2://", "postgresql://", 1)

    return url


def _safe_role_conn():
    if _psycopg2_safe_role is None:
        return None

    url = _safe_role_db_url()
    if not url:
        return None

    return _psycopg2_safe_role.connect(url)


def _safe_role_valid(role):
    return role if role in {"Admin", "Engineer", "Viewer"} else "Viewer"


def _safe_role_admin_emails():
    raw = _os_safe_role.getenv("AKSARA_ADMIN_EMAILS", "febriyadi845@gmail.com")
    return {x.strip().lower() for x in raw.split(",") if x.strip()}


def _safe_role_columns(cur):
    cur.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'users'
        """
    )

    return {row[0] for row in cur.fetchall()}


def _safe_role_find_or_create_user(email, team_access=False):
    email = (email or "").strip().lower()

    if not email:
        return None

    conn = _safe_role_conn()

    if conn is None:
        role = "Admin" if email in _safe_role_admin_emails() else "Viewer"
        return {
            "id": 1 if role == "Admin" else 999,
            "username": email.split("@")[0],
            "email": email,
            "role": role,
        }

    try:
        with conn:
            with conn.cursor() as cur:
                cols = _safe_role_columns(cur)

                if "email" in cols:
                    cur.execute(
                        """
                        SELECT id, username, role, email
                        FROM users
                        WHERE lower(email) = lower(%s)
                        ORDER BY id ASC
                        LIMIT 1
                        """,
                        (email,),
                    )
                else:
                    cur.execute(
                        """
                        SELECT id, username, role
                        FROM users
                        WHERE lower(username) = lower(%s)
                        ORDER BY id ASC
                        LIMIT 1
                        """,
                        (email.split("@")[0],),
                    )

                row = cur.fetchone()

                if row:
                    if "email" in cols:
                        return {
                            "id": row[0],
                            "username": row[1],
                            "role": _safe_role_valid(row[2]),
                            "email": row[3],
                        }

                    return {
                        "id": row[0],
                        "username": row[1],
                        "role": _safe_role_valid(row[2]),
                        "email": email,
                    }

                role = "Admin" if email in _safe_role_admin_emails() else "Viewer"

                insert_cols = []
                insert_vals = []

                if "username" in cols:
                    insert_cols.append("username")
                    insert_vals.append(email.split("@")[0])

                if "email" in cols:
                    insert_cols.append("email")
                    insert_vals.append(email)

                if "role" in cols:
                    insert_cols.append("role")
                    insert_vals.append(role)

                if "password" in cols:
                    insert_cols.append("password")
                    insert_vals.append("google-oauth")

                if "password_hash" in cols:
                    insert_cols.append("password_hash")
                    insert_vals.append("google-oauth")

                if "created_at" in cols:
                    insert_cols.append("created_at")
                    insert_vals.append(_dt_safe_role.utcnow())

                placeholders = ",".join(["%s"] * len(insert_cols))
                col_sql = ",".join(insert_cols)

                cur.execute(
                    f"""
                    INSERT INTO users ({col_sql})
                    VALUES ({placeholders})
                    RETURNING id, username, role {", email" if "email" in cols else ""}
                    """,
                    tuple(insert_vals),
                )

                created = cur.fetchone()

                return {
                    "id": created[0],
                    "username": created[1],
                    "role": _safe_role_valid(created[2]),
                    "email": created[3] if "email" in cols and len(created) > 3 else email,
                }
    finally:
        conn.close()


def _safe_role_update_user(user_id, username=None, role=None):
    role = _safe_role_valid(role or "Viewer")
    conn = _safe_role_conn()

    if conn is None:
        return None

    try:
        with conn:
            with conn.cursor() as cur:
                cols = _safe_role_columns(cur)

                sets = []
                vals = []

                if username and "username" in cols:
                    sets.append("username = %s")
                    vals.append(username)

                if "role" in cols:
                    sets.append("role = %s")
                    vals.append(role)

                if not sets:
                    return None

                vals.append(user_id)

                email_select = ", email" if "email" in cols else ""

                cur.execute(
                    f"""
                    UPDATE users
                    SET {", ".join(sets)}
                    WHERE id = %s
                    RETURNING id, username, role {email_select}
                    """,
                    tuple(vals),
                )

                row = cur.fetchone()

                if not row:
                    return None

                return {
                    "id": row[0],
                    "username": row[1],
                    "role": _safe_role_valid(row[2]),
                    "email": row[3] if "email" in cols and len(row) > 3 else None,
                }
    finally:
        conn.close()


def _safe_role_token(user):
    role = _safe_role_valid(user.get("role") or "Viewer")
    email = user.get("email")
    username = user.get("username") or (email.split("@")[0] if email else "user")

    payload = {
        "sub": username,
        "role": role,
        "email": email,
    }

    try:
        if "create_access_token" in globals():
            return create_access_token(payload)
    except Exception:
        pass

    secret = (
        globals().get("SECRET_KEY")
        or _os_safe_role.getenv("JWT_SECRET")
        or _os_safe_role.getenv("SECRET_KEY")
        or "change-me"
    )

    algorithm = globals().get("ALGORITHM") or "HS256"

    if _jwt_safe_role is None:
        return ""

    payload["exp"] = _dt_safe_role.utcnow() + _td_safe_role(days=30)

    return _jwt_safe_role.encode(payload, secret, algorithm=algorithm)


@app.middleware("http")
async def safe_user_role_persistence_patch(request, call_next):
    path = request.url.path
    method = request.method.upper()

    if method == "POST" and path == "/api/auth/google/token":
        try:
            raw = await request.body()
            payload = _json_safe_role.loads(raw.decode("utf-8") or "{}")
        except Exception:
            payload = {}

        email = payload.get("email")

        if not email:
            return _JSONResponseSafeRole({"error": "Email is required"}, status_code=400)

        user = _safe_role_find_or_create_user(
            email=email,
            team_access=bool(payload.get("teamAccess")),
        )

        if not user:
            return _JSONResponseSafeRole({"error": "Could not finalize Google login"}, status_code=500)

        token = _safe_role_token(user)

        return _JSONResponseSafeRole(
            {
                "access_token": token,
                "token_type": "bearer",
                "id": user.get("id"),
                "username": user.get("username"),
                "role": _safe_role_valid(user.get("role")),
                "email": user.get("email") or email,
            }
        )

    role_update_match = _re_safe_role.match(r"^/api/users/(\d+)$", path)

    if method == "PUT" and role_update_match:
        auth_header = request.headers.get("authorization") or ""

        if not auth_header:
            return _JSONResponseSafeRole({"error": "Unauthorized"}, status_code=401)

        try:
            raw = await request.body()
            payload = _json_safe_role.loads(raw.decode("utf-8") or "{}")
        except Exception:
            payload = {}

        user_id = int(role_update_match.group(1))
        username = payload.get("username")
        role = _safe_role_valid(payload.get("role") or "Viewer")

        updated = _safe_role_update_user(user_id=user_id, username=username, role=role)

        if not updated:
            return _JSONResponseSafeRole(
                {"error": "User not found or database unavailable"},
                status_code=404,
            )

        return _JSONResponseSafeRole(
            {
                "status": "updated",
                "message": "User role persisted successfully.",
                **updated,
            }
        )

    return await call_next(request)

# === SAFE USER ROLE PERSISTENCE PATCH END ===
'''

p.write_text(s.rstrip() + "\n\n" + block + "\n")
print("✅ backend safe role patch installed")
PY

echo "=================================================="
echo "6. ENSURE BACKEND BUILD IGNORES VENV AND USES PYTHON 3.11"
echo "=================================================="

cat > backend/.gcloudignore <<'EOF2'
venv/
__pycache__/
*.pyc
.env
*.log
EOF2

cat > backend/.python-version <<'EOF2'
3.11.9
EOF2

echo "=================================================="
echo "PATCH FINISHED"
echo "=================================================="
