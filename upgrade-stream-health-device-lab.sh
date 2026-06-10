#!/bin/bash
set -e

echo "=================================================="
echo "UPGRADE STREAM HEALTH: ADVANCED DEVICE + NETWORK LAB"
echo "=================================================="

mkdir -p .backup-stream-health
[ -f app/stream/page.tsx ] && cp app/stream/page.tsx .backup-stream-health/stream-page.tsx.bak

cat > app/stream/page.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  Activity,
  AlertTriangle,
  BatteryCharging,
  Cpu,
  Database,
  Gauge,
  Globe2,
  HardDrive,
  Laptop,
  MemoryStick,
  MonitorSmartphone,
  Network,
  Radio,
  RefreshCw,
  Router,
  ShieldAlert,
  Smartphone,
  Thermometer,
  Wifi,
  Zap,
} from "lucide-react";

type QoeSample = {
  time?: string;
  timestamp?: string;
  latency?: number;
  jitter?: number;
  downloadMbps?: number;
  uploadMbps?: number;
  throughput?: number;
  qoeScore?: number;
  qoe_score?: number;
  status?: string;
  source?: string;
};

type QoeLatest = {
  count?: number;
  samples?: QoeSample[];
};

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

type DeviceInfo = {
  browser: string;
  browserVersion: string;
  platform: string;
  os: string;
  architecture: string;
  bitness: string;
  model: string;
  deviceClass: string;
  cpuCores: string;
  memory: string;
  gpu: string;
  screen: string;
  pixelRatio: string;
  refreshRate: string;
  colorDepth: string;
  storageQuota: string;
  storageUsage: string;
  battery: string;
  batteryCharging: string;
  language: string;
  timezone: string;
  online: string;
  cookies: string;
  touch: string;
  chipset: string;
  cpuTemperature: string;
  wifiName: string;
};

type NetworkInfo = {
  effectiveType: string;
  downlink: string;
  rtt: string;
  saveData: string;
  type: string;
  uplink: string;
  transportNote: string;
};

function n(value: unknown, fallback = 0) {
  const x = Number(value);
  return Number.isFinite(x) ? x : fallback;
}

function fmt(value: unknown, digits = 2) {
  return n(value).toFixed(digits);
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function parseBrowser() {
  const ua = navigator.userAgent;

  if (ua.includes("Edg/")) return { name: "Microsoft Edge", version: ua.match(/Edg\/([\d.]+)/)?.[1] || "-" };
  if (ua.includes("OPR/")) return { name: "Opera", version: ua.match(/OPR\/([\d.]+)/)?.[1] || "-" };
  if (ua.includes("Chrome/")) return { name: "Chrome", version: ua.match(/Chrome\/([\d.]+)/)?.[1] || "-" };
  if (ua.includes("Firefox/")) return { name: "Firefox", version: ua.match(/Firefox\/([\d.]+)/)?.[1] || "-" };
  if (ua.includes("Safari/") && ua.includes("Version/")) return { name: "Safari", version: ua.match(/Version\/([\d.]+)/)?.[1] || "-" };

  return { name: "Unknown Browser", version: "-" };
}

function parseOS() {
  const ua = navigator.userAgent;

  if (ua.includes("Windows NT 10.0")) return "Windows 10/11";
  if (ua.includes("Windows")) return "Windows";
  if (ua.includes("Android")) return `Android ${ua.match(/Android\s([\d.]+)/)?.[1] || ""}`.trim();
  if (ua.includes("iPhone")) return "iOS iPhone";
  if (ua.includes("iPad")) return "iPadOS";
  if (ua.includes("Mac OS X")) return "macOS";
  if (ua.includes("Linux")) return "Linux";

  return navigator.platform || "Unknown OS";
}

function getDeviceClass() {
  const ua = navigator.userAgent.toLowerCase();

  if (/android|iphone|ipod/.test(ua)) return "Mobile Phone";
  if (/ipad|tablet/.test(ua)) return "Tablet";
  return "Desktop / Laptop";
}

function getWebGlRenderer() {
  try {
    const canvas = document.createElement("canvas");
    const gl =
      canvas.getContext("webgl") ||
      canvas.getContext("experimental-webgl");

    if (!gl) return "WebGL unavailable";

    const webgl = gl as WebGLRenderingContext;
    const debugInfo = webgl.getExtension("WEBGL_debug_renderer_info");

    if (debugInfo) {
      return webgl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL) || "Unknown GPU Renderer";
    }

    return webgl.getParameter(webgl.RENDERER) || "Unknown GPU Renderer";
  } catch {
    return "GPU renderer blocked";
  }
}

async function estimateRefreshRate() {
  return new Promise<string>((resolve) => {
    const frames: number[] = [];
    let last = performance.now();

    function step(now: number) {
      frames.push(now - last);
      last = now;

      if (frames.length >= 40) {
        const avg = frames.slice(5).reduce((a, b) => a + b, 0) / Math.max(frames.length - 5, 1);
        const hz = Math.round(1000 / avg);
        resolve(`${hz} Hz estimate`);
        return;
      }

      requestAnimationFrame(step);
    }

    requestAnimationFrame(step);

    setTimeout(() => resolve("Unavailable"), 1200);
  });
}

async function getStorageInfo() {
  try {
    if (!navigator.storage?.estimate) {
      return { quota: "Unavailable", usage: "Unavailable" };
    }

    const estimate = await navigator.storage.estimate();
    const quotaGb = (Number(estimate.quota || 0) / 1024 / 1024 / 1024).toFixed(2);
    const usageMb = (Number(estimate.usage || 0) / 1024 / 1024).toFixed(2);

    return {
      quota: `${quotaGb} GB browser quota`,
      usage: `${usageMb} MB used`,
    };
  } catch {
    return { quota: "Unavailable", usage: "Unavailable" };
  }
}

async function getBatteryInfo() {
  try {
    const nav = navigator as any;

    if (!nav.getBattery) {
      return {
        battery: "Unavailable",
        charging: "Unavailable",
      };
    }

    const battery = await nav.getBattery();

    return {
      battery: `${Math.round(Number(battery.level || 0) * 100)}%`,
      charging: battery.charging ? "Charging" : "Not Charging",
    };
  } catch {
    return {
      battery: "Blocked / unavailable",
      charging: "Blocked / unavailable",
    };
  }
}

async function getHighEntropyDevice() {
  try {
    const nav = navigator as any;

    if (!nav.userAgentData?.getHighEntropyValues) {
      return {
        architecture: "Unavailable",
        bitness: "Unavailable",
        model: "Unavailable",
        platform: navigator.platform || "Unknown",
      };
    }

    const values = await nav.userAgentData.getHighEntropyValues([
      "architecture",
      "bitness",
      "model",
      "platform",
      "platformVersion",
      "uaFullVersion",
    ]);

    return {
      architecture: values.architecture || "Unavailable",
      bitness: values.bitness || "Unavailable",
      model: values.model || "Desktop model hidden by browser",
      platform: `${values.platform || navigator.platform || "Unknown"} ${values.platformVersion || ""}`.trim(),
    };
  } catch {
    return {
      architecture: "Blocked",
      bitness: "Blocked",
      model: "Blocked",
      platform: navigator.platform || "Unknown",
    };
  }
}

function getNetworkInfo(): NetworkInfo {
  const nav = navigator as any;
  const connection = nav.connection || nav.mozConnection || nav.webkitConnection;

  return {
    effectiveType: connection?.effectiveType || "Unavailable",
    downlink: connection?.downlink ? `${connection.downlink} Mbps estimate` : "Unavailable",
    rtt: connection?.rtt ? `${connection.rtt} ms estimate` : "Unavailable",
    saveData: connection?.saveData ? "Enabled" : "Disabled / unavailable",
    type: connection?.type || "Browser hides Wi-Fi/Ethernet detail",
    uplink: "Not exposed by browser",
    transportNote:
      "SSID, Wi-Fi PHY rate, link speed, and router name are protected by browser security.",
  };
}

async function collectDeviceInfo(): Promise<DeviceInfo> {
  const browser = parseBrowser();
  const entropy = await getHighEntropyDevice();
  const storage = await getStorageInfo();
  const battery = await getBatteryInfo();
  const refresh = await estimateRefreshRate();

  const memory = (navigator as any).deviceMemory
    ? `${(navigator as any).deviceMemory} GB estimate`
    : "Unavailable";

  const screenInfo = `${window.screen.width} × ${window.screen.height}`;

  return {
    browser: browser.name,
    browserVersion: browser.version,
    platform: entropy.platform || navigator.platform || "Unknown",
    os: parseOS(),
    architecture: entropy.architecture,
    bitness: entropy.bitness,
    model: entropy.model,
    deviceClass: getDeviceClass(),
    cpuCores: `${navigator.hardwareConcurrency || "Unavailable"}`,
    memory,
    gpu: getWebGlRenderer(),
    screen: screenInfo,
    pixelRatio: `${window.devicePixelRatio}x`,
    refreshRate: refresh,
    colorDepth: `${window.screen.colorDepth}-bit`,
    storageQuota: storage.quota,
    storageUsage: storage.usage,
    battery: battery.battery,
    batteryCharging: battery.charging,
    language: navigator.language || "Unknown",
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "Unknown",
    online: navigator.onLine ? "Online" : "Offline",
    cookies: navigator.cookieEnabled ? "Enabled" : "Disabled",
    touch: navigator.maxTouchPoints ? `${navigator.maxTouchPoints} touch points` : "No touch detected",
    chipset:
      getDeviceClass() === "Mobile Phone"
        ? "Protected by browser. Use device model + GPU renderer as chipset clue."
        : "CPU chipset/model is not exposed by browser.",
    cpuTemperature:
      "Protected by browser/OS. Web apps cannot read CPU temperature.",
    wifiName:
      "Protected by browser. SSID and Wi-Fi link speed are not exposed.",
  };
}

function statusFromScore(score: number) {
  if (score >= 90) return "EXCELLENT";
  if (score >= 75) return "STABLE";
  if (score >= 60) return "BUFFER RISK";
  return "POOR";
}

function Card({
  label,
  value,
  unit,
  icon: Icon,
  accent,
  note,
}: {
  label: string;
  value: string | number;
  unit?: string;
  icon?: any;
  accent?: string;
  note?: string;
}) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950/80 p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.22em] text-slate-500">{label}</p>
          <div className="mt-3 flex items-end gap-2">
            <span className={`text-3xl font-black ${accent || "text-white"}`}>{value}</span>
            {unit ? <span className="mb-1 text-sm text-slate-400">{unit}</span> : null}
          </div>
          {note ? <p className="mt-2 text-xs leading-relaxed text-slate-500">{note}</p> : null}
        </div>
        {Icon ? (
          <div className="rounded-xl border border-cyan-500/20 bg-cyan-500/10 p-2">
            <Icon className="h-5 w-5 text-cyan-300" />
          </div>
        ) : null}
      </div>
    </div>
  );
}

function MiniSpec({
  label,
  value,
  icon: Icon,
  accent,
}: {
  label: string;
  value: string | number;
  icon?: any;
  accent?: string;
}) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-950/80 p-4">
      <div className="flex items-start gap-3">
        {Icon ? <Icon className={`mt-1 h-5 w-5 ${accent || "text-cyan-300"}`} /> : null}
        <div className="min-w-0">
          <p className="text-[10px] uppercase tracking-[0.22em] text-slate-500">{label}</p>
          <p className="mt-2 break-words text-sm font-black text-white">{value || "-"}</p>
        </div>
      </div>
    </div>
  );
}

export default function StreamHealthPage() {
  const [latest, setLatest] = useState<QoeLatest>({});
  const [metrics, setMetrics] = useState<Metric>({});
  const [device, setDevice] = useState<DeviceInfo | null>(null);
  const [network, setNetwork] = useState<NetworkInfo | null>(null);
  const [lastRefresh, setLastRefresh] = useState("-");
  const [loading, setLoading] = useState(false);
  const mounted = useRef(false);

  const samples = useMemo(() => {
    const fromLatest = Array.isArray(latest.samples) ? latest.samples : [];
    return fromLatest.slice(0, 50);
  }, [latest.samples]);

  const summary = useMemo(() => {
    const avg = (key: keyof QoeSample) => {
      if (!samples.length) return 0;
      const values = samples.map((s) => n(s[key])).filter(Number.isFinite);
      if (!values.length) return 0;
      return values.reduce((a, b) => a + b, 0) / values.length;
    };

    const currentScore = n(metrics.qoe_score ?? samples[0]?.qoeScore ?? samples[0]?.qoe_score);
    const currentStatus = metrics.streaming_status || samples[0]?.status || statusFromScore(currentScore);

    return {
      activeSamples: samples.length || latest.count || 0,
      avgLatency: avg("latency"),
      avgJitter: avg("jitter"),
      avgDownload:
        avg("downloadMbps") || avg("throughput") || n(metrics.throughput),
      avgUpload: avg("uploadMbps"),
      currentScore,
      currentStatus,
      lastTime: metrics.timestamp || samples[0]?.time || samples[0]?.timestamp || "-",
    };
  }, [samples, latest.count, metrics]);

  async function refreshAll() {
    setLoading(true);

    try {
      const [latestRes, metricsRes] = await Promise.all([
        fetch(`/api/qoe-latest?x=${Date.now()}`, { cache: "no-store" }),
        fetch(`/api/qos-metrics?x=${Date.now()}`, { cache: "no-store" }),
      ]);

      const latestJson = await latestRes.json();
      const metricsJson = await metricsRes.json();

      setLatest(latestJson || {});
      setMetrics(metricsJson || {});
      setNetwork(getNetworkInfo());
      setLastRefresh(new Date().toLocaleTimeString());
    } finally {
      setLoading(false);
    }
  }

  async function refreshDevice() {
    const info = await collectDeviceInfo();
    setDevice(info);
    setNetwork(getNetworkInfo());
  }

  useEffect(() => {
    if (mounted.current) return;
    mounted.current = true;

    refreshDevice();
    refreshAll();

    const interval = setInterval(refreshAll, 5000);

    const onRealtime = () => refreshAll();
    window.addEventListener("real-qoe-updated", onRealtime);
    window.addEventListener("online", refreshAll);
    window.addEventListener("offline", refreshAll);

    return () => {
      clearInterval(interval);
      window.removeEventListener("real-qoe-updated", onRealtime);
      window.removeEventListener("online", refreshAll);
      window.removeEventListener("offline", refreshAll);
    };
  }, []);

  const statusClass =
    summary.currentScore >= 90
      ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-300"
      : summary.currentScore >= 75
      ? "border-cyan-500/30 bg-cyan-500/10 text-cyan-300"
      : summary.currentScore >= 60
      ? "border-yellow-500/30 bg-yellow-500/10 text-yellow-300"
      : "border-red-500/30 bg-red-500/10 text-red-300";

  return (
    <main className="space-y-8 p-6 text-white">
      <section className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">Streaming Infrastructure Monitor</h1>
          <p className="mt-2 max-w-5xl text-slate-400">
            HLS / WebRTC-style streaming health derived from real browser-side QoE telemetry,
            device diagnostics, browser capability, GPU renderer, storage, battery, and network information.
            Last telemetry refresh: <span className="font-bold text-cyan-300">{summary.lastTime}</span>
          </p>
        </div>

        <div className="flex gap-3">
          <button
            onClick={refreshDevice}
            className="rounded-xl border border-purple-500/30 bg-purple-500/10 px-5 py-3 text-sm font-bold text-purple-300 hover:bg-purple-500/20"
          >
            <Cpu className="mr-2 inline h-4 w-4" />
            Refresh Device Specs
          </button>

          <button
            onClick={refreshAll}
            className="rounded-xl border border-cyan-500/30 bg-cyan-500/10 px-5 py-3 text-sm font-bold text-cyan-300 hover:bg-cyan-500/20"
          >
            <RefreshCw className="mr-2 inline h-4 w-4" />
            {loading ? "Refreshing..." : "Refresh Telemetry"}
          </button>
        </div>
      </section>

      <section className={`rounded-3xl border p-6 ${statusClass}`}>
        <div className="flex flex-wrap items-center justify-between gap-5">
          <div>
            <p className="text-xs uppercase tracking-[0.25em] opacity-80">Current Streaming State</p>
            <h2 className="mt-2 text-4xl font-black">{summary.currentStatus}</h2>
            <p className="mt-2 text-sm text-slate-300">
              QoE is calculated from real browser-to-Cloud Run probe: latency, jitter, download, upload, and alert thresholds.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <div className="rounded-2xl border border-slate-700 bg-slate-950/70 p-4">
              <p className="text-xs text-slate-400">QoE Score</p>
              <p className="mt-1 text-3xl font-black">{fmt(summary.currentScore, 0)}</p>
            </div>
            <div className="rounded-2xl border border-slate-700 bg-slate-950/70 p-4">
              <p className="text-xs text-slate-400">Samples</p>
              <p className="mt-1 text-3xl font-black">{summary.activeSamples}</p>
            </div>
            <div className="rounded-2xl border border-slate-700 bg-slate-950/70 p-4">
              <p className="text-xs text-slate-400">Source</p>
              <p className="mt-1 text-sm font-black">{metrics.source || samples[0]?.source || "real-qoe-probe"}</p>
            </div>
            <div className="rounded-2xl border border-slate-700 bg-slate-950/70 p-4">
              <p className="text-xs text-slate-400">Page Refresh</p>
              <p className="mt-1 text-sm font-black">{lastRefresh}</p>
            </div>
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-cyan-500/30 bg-cyan-500/5 p-6">
        <h2 className="mb-5 text-xl font-black">Client Device Diagnostics</h2>

        <div className="grid gap-4 md:grid-cols-4">
          <Card label="Logical CPU Cores" value={device?.cpuCores || "-"} icon={Cpu} />
          <Card label="Device Memory" value={device?.memory || "-"} icon={MemoryStick} />
          <Card label="Browser" value={device?.browser || "-"} unit={device?.browserVersion || ""} icon={Globe2} />
          <Card label="Device Class" value={device?.deviceClass || "-"} icon={device?.deviceClass === "Mobile Phone" ? Smartphone : Laptop} />
        </div>

        <div className="mt-4 grid gap-4 md:grid-cols-3">
          <MiniSpec label="Detected Device Model" value={device?.model || "-"} icon={MonitorSmartphone} accent="text-cyan-300" />
          <MiniSpec label="Operating System / Platform" value={`${device?.os || "-"} • ${device?.platform || "-"}`} icon={Laptop} accent="text-emerald-300" />
          <MiniSpec label="CPU Architecture / Bitness" value={`${device?.architecture || "-"} • ${device?.bitness || "-"}`} icon={Cpu} accent="text-yellow-300" />
          <MiniSpec label="GPU / WebGL Renderer" value={device?.gpu || "-"} icon={Zap} accent="text-purple-300" />
          <MiniSpec label="Screen / Pixel Ratio" value={`${device?.screen || "-"} • ${device?.pixelRatio || "-"}`} icon={MonitorSmartphone} accent="text-cyan-300" />
          <MiniSpec label="Refresh Rate / Color Depth" value={`${device?.refreshRate || "-"} • ${device?.colorDepth || "-"}`} icon={Activity} accent="text-emerald-300" />
          <MiniSpec label="Storage Quota" value={device?.storageQuota || "-"} icon={HardDrive} accent="text-blue-300" />
          <MiniSpec label="Storage Usage" value={device?.storageUsage || "-"} icon={Database} accent="text-blue-300" />
          <MiniSpec label="Battery" value={`${device?.battery || "-"} • ${device?.batteryCharging || "-"}`} icon={BatteryCharging} accent="text-green-300" />
          <MiniSpec label="Language / Timezone" value={`${device?.language || "-"} • ${device?.timezone || "-"}`} icon={Globe2} accent="text-cyan-300" />
          <MiniSpec label="Touch / Cookies" value={`${device?.touch || "-"} • Cookies ${device?.cookies || "-"}`} icon={MonitorSmartphone} accent="text-purple-300" />
          <MiniSpec label="Online State" value={device?.online || "-"} icon={Network} accent="text-emerald-300" />
        </div>
      </section>

      <section className="rounded-3xl border border-emerald-500/30 bg-emerald-500/5 p-6">
        <h2 className="mb-5 text-xl font-black">Connection & Transport Diagnostics</h2>

        <div className="grid gap-4 md:grid-cols-4">
          <Card label="Browser Network Type" value={network?.type || "-"} icon={Wifi} />
          <Card label="Effective Connection" value={network?.effectiveType || "-"} icon={Radio} />
          <Card label="RTT Estimate" value={network?.rtt || "-"} icon={Gauge} />
          <Card label="Downlink Estimate" value={network?.downlink || "-"} icon={Router} />
        </div>

        <div className="mt-4 grid gap-4 md:grid-cols-3">
          <MiniSpec label="Save Data Mode" value={network?.saveData || "-"} icon={ShieldAlert} accent="text-yellow-300" />
          <MiniSpec label="Uplink Link-Speed Access" value={network?.uplink || "-"} icon={Wifi} accent="text-red-300" />
          <MiniSpec label="Transport Note" value={network?.transportNote || "-"} icon={AlertTriangle} accent="text-yellow-300" />
        </div>
      </section>

      <section className="rounded-3xl border border-red-500/30 bg-red-500/5 p-6">
        <h2 className="mb-5 text-xl font-black">Protected Hardware Fields</h2>

        <div className="grid gap-4 md:grid-cols-3">
          <MiniSpec label="CPU / Mobile Chipset" value={device?.chipset || "-"} icon={Cpu} accent="text-red-300" />
          <MiniSpec label="CPU Temperature" value={device?.cpuTemperature || "-"} icon={Thermometer} accent="text-red-300" />
          <MiniSpec label="Wi-Fi SSID / Real Link Speed" value={device?.wifiName || "-"} icon={Wifi} accent="text-red-300" />
        </div>

        <p className="mt-4 rounded-xl border border-slate-800 bg-slate-950/80 p-4 text-sm leading-relaxed text-slate-400">
          Browser security intentionally blocks hardware-sensitive data such as CPU temperature,
          exact CPU/chipset model, Wi-Fi SSID, router name, and physical link speed. For presentation,
          this page shows all accessible real diagnostics and clearly marks protected fields instead of faking them.
        </p>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
        <h2 className="mb-5 text-xl font-black">Streaming Health Summary</h2>

        <div className="grid gap-4 md:grid-cols-5">
          <Card label="Active Samples" value={summary.activeSamples} icon={Database} />
          <Card label="Avg Latency" value={fmt(summary.avgLatency, 1)} unit="ms" icon={Gauge} accent="text-yellow-300" />
          <Card label="Avg Jitter" value={fmt(summary.avgJitter, 1)} unit="ms" icon={Radio} accent="text-purple-300" />
          <Card label="Avg Download" value={fmt(summary.avgDownload, 2)} unit="Mbps" icon={Zap} accent="text-cyan-300" />
          <Card label="Avg Upload" value={fmt(summary.avgUpload, 2)} unit="Mbps" icon={Network} accent="text-emerald-300" />
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
        <h2 className="mb-5 text-xl font-black">Recent Streaming Probe Samples</h2>

        <div className="overflow-hidden rounded-xl border border-slate-800">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950 text-xs uppercase tracking-[0.2em] text-slate-500">
              <tr>
                <th className="p-3">Time</th>
                <th className="p-3">QoE</th>
                <th className="p-3">Latency</th>
                <th className="p-3">Jitter</th>
                <th className="p-3">Down</th>
                <th className="p-3">Up</th>
                <th className="p-3">Status</th>
                <th className="p-3">Source</th>
              </tr>
            </thead>

            <tbody>
              {samples.slice(0, 15).map((sample, index) => {
                const qoe = n(sample.qoeScore ?? sample.qoe_score);
                const status = sample.status || statusFromScore(qoe);

                return (
                  <tr key={index} className="border-t border-slate-800">
                    <td className="p-3">{sample.time || sample.timestamp || "-"}</td>
                    <td className="p-3 text-cyan-300">{fmt(qoe, 0)}</td>
                    <td className="p-3">{fmt(sample.latency, 1)} ms</td>
                    <td className="p-3">{fmt(sample.jitter, 1)} ms</td>
                    <td className="p-3">{fmt(sample.downloadMbps ?? sample.throughput, 2)} Mbps</td>
                    <td className="p-3">{fmt(sample.uploadMbps, 2)} Mbps</td>
                    <td className={status === "EXCELLENT" ? "p-3 text-emerald-300" : status === "STABLE" ? "p-3 text-cyan-300" : status === "BUFFER RISK" ? "p-3 text-yellow-300" : "p-3 text-red-300"}>
                      {status}
                    </td>
                    <td className="p-3 text-slate-400">{sample.source || metrics.source || "real-qoe-probe"}</td>
                  </tr>
                );
              })}

              {samples.length === 0 ? (
                <tr>
                  <td colSpan={8} className="p-6 text-center text-slate-500">
                    Waiting for real streaming probe samples...
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
TSX

echo "=================================================="
echo "DONE"
echo "=================================================="
