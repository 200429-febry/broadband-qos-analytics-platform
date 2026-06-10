"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { signIn } from "next-auth/react";
import { RadioTower, Wifi, Lock, User } from "lucide-react";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export default function LoginPage() {
  const router = useRouter();

  const [username, setUsername] = useState("admin");
  const [password, setPassword] = useState("admin");
  const [error, setError] = useState("");

  const login = async () => {
    setError("");

    try {
      const res = await fetch(`${API_URL}/api/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      });

      const data = await res.json();

      if (!data.access_token) {
        setError(data.error || "Login failed");
        return;
      }

      localStorage.setItem("access_token", data.access_token);
      localStorage.setItem(
        "user",
        JSON.stringify({
          username: data.username || username,
          role: data.role || "Admin",
        })
      );

      router.push("/");
    } catch {
      setError("Unable to connect to authentication service.");
    }
  };

  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-slate-950 text-white">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(0,255,200,0.18),transparent_35%),radial-gradient(circle_at_bottom_right,rgba(59,130,246,0.22),transparent_35%)]" />

      <div className="absolute inset-0 opacity-30">
        <div className="absolute inset-0 bg-[linear-gradient(rgba(34,211,238,0.12)_1px,transparent_1px),linear-gradient(90deg,rgba(34,211,238,0.12)_1px,transparent_1px)] bg-[size:60px_60px] animate-pulse" />
      </div>

      <div className="absolute bottom-0 left-0 right-0 h-72 opacity-60">
        <div className="absolute bottom-0 left-[5%] h-32 w-20 bg-slate-800/80" />
        <div className="absolute bottom-0 left-[18%] h-48 w-24 bg-slate-800/80" />
        <div className="absolute bottom-0 left-[34%] h-40 w-28 bg-slate-800/80" />
        <div className="absolute bottom-0 right-[28%] h-56 w-24 bg-slate-800/80" />
        <div className="absolute bottom-0 right-[12%] h-36 w-20 bg-slate-800/80" />
      </div>

      <div className="absolute left-16 top-24 hidden h-96 w-96 items-center justify-center lg:flex">
        <div className="relative">
          <RadioTower className="h-24 w-24 text-cyan-300 drop-shadow-[0_0_25px_rgba(34,211,238,0.8)]" />

          <span className="absolute left-1/2 top-1/2 h-40 w-40 -translate-x-1/2 -translate-y-1/2 rounded-full border border-cyan-400/30 animate-ping" />
          <span className="absolute left-1/2 top-1/2 h-64 w-64 -translate-x-1/2 -translate-y-1/2 rounded-full border border-emerald-400/20 animate-pulse" />
          <span className="absolute left-1/2 top-1/2 h-80 w-80 -translate-x-1/2 -translate-y-1/2 rounded-full border border-blue-400/10 animate-ping" />
        </div>
      </div>

      <div className="absolute right-20 bottom-28 hidden lg:block">
        <div className="rounded-2xl border border-cyan-500/20 bg-slate-900/60 p-4 backdrop-blur-xl">
          <div className="mb-3 flex items-center gap-2 text-cyan-300">
            <Wifi className="h-5 w-5" />
            <span className="text-sm font-semibold">Live QoS Signal</span>
          </div>

          <div className="space-y-2 text-xs text-slate-300">
            <p>Latency Stream • Active</p>
            <p>Packet Loss Probe • Online</p>
            <p>Base Station Link • Nominal</p>
          </div>
        </div>
      </div>

      <section className="relative z-10 w-full max-w-md rounded-3xl border border-white/10 bg-slate-950/75 p-8 shadow-2xl backdrop-blur-2xl">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-cyan-500/10 ring-1 ring-cyan-400/30">
            <RadioTower className="h-9 w-9 text-cyan-300" />
          </div>

          <h1 className="text-3xl font-black tracking-tight">
            AKSARA UNION
          </h1>

          <p className="mt-2 text-sm text-slate-400">
            QoS Analytics & Prediction Platform
          </p>
        </div>

        <div className="space-y-4">
          <label className="block">
            <span className="mb-2 block text-sm text-slate-400">Username</span>
            <div className="flex items-center rounded-xl border border-white/10 bg-slate-900/80 px-3">
              <User className="h-4 w-4 text-slate-500" />
              <input
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                className="w-full bg-transparent px-3 py-3 text-white outline-none"
              />
            </div>
          </label>

          <label className="block">
            <span className="mb-2 block text-sm text-slate-400">Password</span>
            <div className="flex items-center rounded-xl border border-white/10 bg-slate-900/80 px-3">
              <Lock className="h-4 w-4 text-slate-500" />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full bg-transparent px-3 py-3 text-white outline-none"
              />
            </div>
          </label>

          {error && (
            <div className="rounded-xl border border-red-500/30 bg-red-500/10 p-3 text-sm text-red-300">
              {error}
            </div>
          )}

          <button
            type="button"
            onClick={login}
            className="w-full rounded-lg bg-cyan-400 px-4 py-3 text-sm font-bold text-slate-950 transition hover:bg-cyan-300"
          >
            Enter Network Operations Center
          </button>

          <button
            type="button"
            onClick={() => signIn("google", { callbackUrl: "/auth/google-success" })}
            className="w-full rounded-lg border border-cyan-500/30 bg-white px-4 py-3 text-sm font-semibold text-slate-900 transition hover:bg-cyan-50"
          >
            Continue with Google
          </button>
        </div>

        <p className="mt-6 text-center text-xs text-slate-500">
          Cloud-Native • Realtime • AI-Driven • Telco Grade
        </p>
      </section>
    </main>
  );
}
