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
