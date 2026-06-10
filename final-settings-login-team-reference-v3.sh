#!/bin/bash
set -e

echo "=================================================="
echo "FINAL SETTINGS WORKING + LOGIN TEAM PHONE + REFERENCES"
echo "=================================================="

REGION="asia-southeast2"
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

PROJECT_ID=$(gcloud config get-value project)

echo "API_URL=$API_URL"
echo "PROJECT_ID=$PROJECT_ID"

mkdir -p .backup-final-settings-login-v3
for f in \
  app/layout.tsx \
  app/settings/page.tsx \
  app/auth/google-success/page.tsx \
  app/globals.css \
  components/global-settings-controller.tsx \
  app/api/auth/google-finalize/route.js
do
  [ -f "$f" ] && cp "$f" ".backup-final-settings-login-v3/$(echo "$f" | tr '/' '_').bak"
done

mkdir -p components
mkdir -p app/api/auth/google-finalize
mkdir -p app/auth/google-success

cat > components/global-settings-controller.tsx <<'TSX'
"use client";

import { useEffect } from "react";

type AksaraSettings = {
  chartMode: string;
  animationMode: string;
  coverageRadius: string;
  mapMode: string;
  refreshRate: string;
  chartWindow: string;
  telemetrySource: string;
  density: string;
  fontSize: string;
};

declare global {
  interface Window {
    __AKSARA_SETTINGS__?: AksaraSettings;
  }
}

function slug(v: string) {
  return String(v || "")
    .toLowerCase()
    .replaceAll(" ", "-")
    .replaceAll("/", "-");
}

function readSettings(): AksaraSettings {
  return {
    chartMode: localStorage.getItem("aksara-chart-mode") || "Engineer Dense",
    animationMode: localStorage.getItem("aksara-animation-mode") || "Normal",
    coverageRadius: localStorage.getItem("aksara-coverage-radius") || "10 km",
    mapMode: localStorage.getItem("aksara-map-mode") || "RF Planning",
    refreshRate: localStorage.getItem("aksara-refresh-rate") || "5s",
    chartWindow: localStorage.getItem("aksara-chart-window") || "15 minutes",
    telemetrySource: localStorage.getItem("aksara-telemetry-source") || "Live API",
    density: localStorage.getItem("aksara-density") || "comfortable",
    fontSize: localStorage.getItem("aksara-font-size") || "normal",
  };
}

function applyRuntimeSettings() {
  const s = readSettings();
  const root = document.documentElement;

  window.__AKSARA_SETTINGS__ = s;

  root.setAttribute("data-aksara-chart-mode", slug(s.chartMode));
  root.setAttribute("data-aksara-animation-mode", slug(s.animationMode));
  root.setAttribute("data-aksara-map-mode", slug(s.mapMode));
  root.setAttribute("data-aksara-density", slug(s.density));
  root.setAttribute("data-aksara-font-profile", slug(s.fontSize));

  const radiusNumber = Number(String(s.coverageRadius).replace(/[^0-9.]/g, "")) || 10;
  root.style.setProperty("--aksara-coverage-radius-km", String(radiusNumber));
  root.style.setProperty("--aksara-refresh-rate-label", `"${s.refreshRate}"`);
  root.style.setProperty("--aksara-chart-window-label", `"${s.chartWindow}"`);
  root.style.setProperty("--aksara-map-mode-label", `"${s.mapMode}"`);

  if (s.chartMode === "Executive Clean") {
    root.style.setProperty("--aksara-chart-height", "260px");
    root.style.setProperty("--aksara-chart-opacity", "0.92");
    root.style.setProperty("--aksara-chart-stroke", "2.2");
  } else if (s.chartMode === "Engineer Dense") {
    root.style.setProperty("--aksara-chart-height", "360px");
    root.style.setProperty("--aksara-chart-opacity", "1");
    root.style.setProperty("--aksara-chart-stroke", "1.7");
  } else if (s.chartMode === "Presentation") {
    root.style.setProperty("--aksara-chart-height", "420px");
    root.style.setProperty("--aksara-chart-opacity", "1");
    root.style.setProperty("--aksara-chart-stroke", "3");
  } else {
    root.style.setProperty("--aksara-chart-height", "320px");
    root.style.setProperty("--aksara-chart-opacity", "0.98");
    root.style.setProperty("--aksara-chart-stroke", "2");
  }

  if (s.animationMode === "Reduced") {
    root.style.setProperty("--aksara-motion-speed", "0s");
    root.setAttribute("data-aksara-reduced-motion", "true");
  } else if (s.animationMode === "Enhanced") {
    root.style.setProperty("--aksara-motion-speed", "0.35s");
    root.setAttribute("data-aksara-reduced-motion", "false");
  } else {
    root.style.setProperty("--aksara-motion-speed", "0.2s");
    root.setAttribute("data-aksara-reduced-motion", "false");
  }

  window.dispatchEvent(
    new CustomEvent("aksara-runtime-settings-applied", {
      detail: s,
    })
  );
}

export function GlobalSettingsController() {
  useEffect(() => {
    applyRuntimeSettings();

    const handler = () => applyRuntimeSettings();

    window.addEventListener("storage", handler);
    window.addEventListener("aksara-settings-change", handler);
    window.addEventListener("aksara-theme-change", handler);
    window.addEventListener("aksara-lang-change", handler);

    const interval = setInterval(applyRuntimeSettings, 5000);

    return () => {
      window.removeEventListener("storage", handler);
      window.removeEventListener("aksara-settings-change", handler);
      window.removeEventListener("aksara-theme-change", handler);
      window.removeEventListener("aksara-lang-change", handler);
      clearInterval(interval);
    };
  }, []);

  return null;
}
TSX

cat >> app/globals.css <<'CSS'

/* AKSARA working settings behavior */
html[data-aksara-chart-mode="executive-clean"] svg {
  max-height: var(--aksara-chart-height, 260px);
  opacity: var(--aksara-chart-opacity, 0.92);
}

html[data-aksara-chart-mode="engineer-dense"] svg {
  max-height: var(--aksara-chart-height, 360px);
  filter: contrast(1.08) saturate(1.1);
}

html[data-aksara-chart-mode="presentation"] svg {
  max-height: var(--aksara-chart-height, 420px);
  filter: contrast(1.15) saturate(1.15);
}

html[data-aksara-animation-mode="reduced"] *,
html[data-aksara-reduced-motion="true"] * {
  animation: none !important;
  transition: none !important;
  scroll-behavior: auto !important;
}

html[data-aksara-animation-mode="enhanced"] .rounded-3xl,
html[data-aksara-animation-mode="enhanced"] .rounded-2xl {
  transition: transform var(--aksara-motion-speed, 0.35s), border-color var(--aksara-motion-speed, 0.35s), background var(--aksara-motion-speed, 0.35s);
}

html[data-aksara-animation-mode="enhanced"] .rounded-3xl:hover,
html[data-aksara-animation-mode="enhanced"] .rounded-2xl:hover {
  transform: translateY(-2px);
}

html[data-aksara-map-mode="standard"] .leaflet-container {
  filter: saturate(0.95) contrast(1);
}

html[data-aksara-map-mode="rf-planning"] .leaflet-container {
  filter: saturate(1.18) contrast(1.12);
}

html[data-aksara-map-mode="atoll-like"] .leaflet-container {
  filter: saturate(1.25) contrast(1.18) hue-rotate(8deg);
}

html[data-aksara-map-mode="cellmapper-like"] .leaflet-container {
  filter: saturate(1.35) contrast(1.08);
}

html[data-aksara-map-mode] .leaflet-container::after {
  content: "Mode: " var(--aksara-map-mode-label) " | Radius: " var(--aksara-coverage-radius-km) " km";
  position: absolute;
  left: 18px;
  bottom: 18px;
  z-index: 900;
  padding: 8px 12px;
  border-radius: 12px;
  background: rgba(2, 6, 23, 0.82);
  color: #67e8f9;
  font-size: 12px;
  font-weight: 800;
  border: 1px solid rgba(34, 211, 238, 0.35);
  pointer-events: none;
}

html[data-aksara-density="compact"] main {
  --aksara-gap: 0.75rem;
}

html[data-aksara-density="spacious"] main {
  --aksara-gap: 1.5rem;
}

html[data-aksara-font-profile="compact"] body {
  font-size: 14px;
}

html[data-aksara-font-profile="large"] body {
  font-size: 17px;
}

html[data-aksara-font-profile="presentation"] body {
  font-size: 18px;
}
CSS

python3 <<'PY'
from pathlib import Path

p = Path("app/layout.tsx")
s = p.read_text()

imp = 'import { GlobalSettingsController } from "@/components/global-settings-controller";'
if imp not in s:
    lines = s.splitlines()
    idx = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            idx = i + 1
    lines.insert(idx, imp)
    s = "\n".join(lines)

if "<GlobalSettingsController />" not in s:
    if "</body>" in s:
        s = s.replace("</body>", "        <GlobalSettingsController />\n      </body>", 1)
    else:
        print("WARNING: </body> not found")

p.write_text(s)
print("✅ GlobalSettingsController injected into layout")
PY

cat > app/settings/page.tsx <<'TSX'
"use client";

import { useEffect, useState } from "react";
import {
  CheckCircle2,
  Database,
  Globe2,
  Languages,
  LayoutDashboard,
  Monitor,
  Palette,
  RefreshCw,
  RotateCcw,
  Settings,
  ShieldCheck,
  SlidersHorizontal,
  Trash2,
  Users,
  BookOpen,
  Wifi,
} from "lucide-react";

const languages = [
  { code: "id", label: "Bahasa Indonesia", note: "Default lokal" },
  { code: "en", label: "English", note: "Enterprise default" },
  { code: "ja", label: "Japanese", note: "日本語 UI" },
  { code: "ko", label: "Korean", note: "한국어 UI" },
  { code: "zh", label: "Chinese", note: "中文 UI" },
  { code: "ar", label: "Arabic", note: "واجهة عربية" },
  { code: "de", label: "German", note: "Deutsch UI" },
  { code: "fr", label: "French", note: "Français UI" },
  { code: "es", label: "Spanish", note: "Español UI" },
  { code: "pt", label: "Portuguese", note: "Português UI" },
  { code: "ms", label: "Malay", note: "Bahasa Melayu" },
  { code: "tr", label: "Turkish", note: "Türkçe UI" },
  { code: "it", label: "Italian", note: "Italiano UI" },
  { code: "nl", label: "Dutch", note: "Nederlands UI" },
  { code: "ru", label: "Russian", note: "Русский UI" },
];

const themes = [
  { key: "obsidian", name: "Obsidian NOC", desc: "Dark neutral, high contrast, safest for presentation.", accent: "#06b6d4" },
  { key: "pacific", name: "Pacific Core", desc: "Blue telco operations center tone.", accent: "#22d3ee" },
  { key: "emerald", name: "Emerald Grid", desc: "Green network health and operations style.", accent: "#34d399" },
  { key: "violet", name: "Violet AI Lab", desc: "ML / prediction-oriented purple theme.", accent: "#a78bfa" },
  { key: "amber", name: "Amber Control", desc: "Warm engineering control-room tone.", accent: "#f59e0b" },
  { key: "graphite", name: "Graphite Enterprise", desc: "Minimal gray enterprise console.", accent: "#e5e7eb" },
  { key: "plasma", name: "Plasma SOC", desc: "Security operation style magenta accent.", accent: "#f472b6" },
  { key: "navy", name: "Navy Carrier", desc: "Carrier-grade deep navy interface.", accent: "#5bc0be" },
  { key: "sunrise", name: "Sunrise Ops", desc: "Warm orange control-room profile.", accent: "#fb923c" },
  { key: "arctic", name: "Arctic Telemetry", desc: "Bright blue cold telemetry profile.", accent: "#7dd3fc" },
  { key: "matrix", name: "Matrix Terminal", desc: "Green terminal-inspired engineering mode.", accent: "#22c55e" },
  { key: "royal", name: "Royal Backbone", desc: "Deep indigo carrier backbone profile.", accent: "#818cf8" },
];

const chartModes = ["Balanced", "Engineer Dense", "Executive Clean", "Presentation"];
const animationModes = ["Reduced", "Normal", "Enhanced"];
const coverageRadius = ["2 km", "5 km", "10 km", "25 km", "50 km"];
const mapModes = ["Standard", "RF Planning", "Atoll-like", "CellMapper-like"];
const refreshOptions = ["3s", "5s", "10s", "15s", "30s"];
const chartWindows = ["5 minutes", "15 minutes", "30 minutes", "1 hour", "6 hours"];
const telemetrySources = ["Live API", "Browser QoE Probe", "Cloud SQL Window", "BigQuery Parsed View"];
const fontSizes = ["compact", "normal", "large", "presentation"];
const densityOptions = ["compact", "comfortable", "spacious"];

const team = [
  {
    name: "Muhammad Febryadi",
    role: "Full Stack Developer",
    responsibility: "Cloud Run deployment, FastAPI integration, QoE telemetry pipeline, report export, database connectivity, and dashboard logic.",
  },
  {
    name: "Sandy Muhammad Rifqi",
    role: "UI/UX Designer",
    responsibility: "Enterprise visual design, dashboard layout, navigation experience, presentation flow, and usability refinement.",
  },
];

const references = [
  "Google Cloud Run deployment architecture for frontend and backend service separation.",
  "Cloud SQL PostgreSQL for operational telemetry and user-management persistence.",
  "BigQuery analytics pattern for historical telemetry warehousing and analytical reporting.",
  "Prometheus / Grafana-style observability concept for metrics, alerts, and service-health monitoring.",
  "OpenCellID and CellMapper-style cellular coverage visualization for BTS marker, provider, and radio-layer mapping.",
  "Atoll-style RF planning workflow for coverage radius, sector visualization, nearest-cell interpretation, and planning-oriented map mode.",
  "YouTube live streaming QoE scenario as practical traffic workload for browser-side measurement.",
  "Huawei / carrier NOC dashboard style as visual inspiration for enterprise-grade monitoring layout.",
];

export default function SettingsPage() {
  const [lang, setLang] = useState("id");
  const [theme, setTheme] = useState("obsidian");
  const [fontSize, setFontSize] = useState("normal");
  const [density, setDensity] = useState("comfortable");
  const [refreshRate, setRefreshRate] = useState("5s");
  const [chartWindow, setChartWindow] = useState("15 minutes");
  const [telemetrySource, setTelemetrySource] = useState("Live API");
  const [radius, setRadius] = useState("10 km");
  const [chartMode, setChartMode] = useState("Engineer Dense");
  const [animationMode, setAnimationMode] = useState("Normal");
  const [mapMode, setMapMode] = useState("RF Planning");
  const [status, setStatus] = useState("Settings loaded from browser profile.");

  useEffect(() => {
    setLang(localStorage.getItem("aksara-lang") || "id");
    setTheme(localStorage.getItem("aksara-theme") || "obsidian");
    setFontSize(localStorage.getItem("aksara-font-size") || "normal");
    setDensity(localStorage.getItem("aksara-density") || "comfortable");
    setRefreshRate(localStorage.getItem("aksara-refresh-rate") || "5s");
    setChartWindow(localStorage.getItem("aksara-chart-window") || "15 minutes");
    setTelemetrySource(localStorage.getItem("aksara-telemetry-source") || "Live API");
    setRadius(localStorage.getItem("aksara-coverage-radius") || "10 km");
    setChartMode(localStorage.getItem("aksara-chart-mode") || "Engineer Dense");
    setAnimationMode(localStorage.getItem("aksara-animation-mode") || "Normal");
    setMapMode(localStorage.getItem("aksara-map-mode") || "RF Planning");
  }, []);

  function notify() {
    window.dispatchEvent(new CustomEvent("aksara-lang-change", { detail: lang }));
    window.dispatchEvent(new CustomEvent("aksara-theme-change", { detail: theme }));
    window.dispatchEvent(new CustomEvent("aksara-settings-change"));
    window.dispatchEvent(new Event("storage"));
  }

  const apply = () => {
    const pairs: Record<string, string> = {
      "aksara-lang": lang,
      "aksara-theme": theme,
      "aksara-font-size": fontSize,
      "aksara-density": density,
      "aksara-refresh-rate": refreshRate,
      "aksara-chart-window": chartWindow,
      "aksara-telemetry-source": telemetrySource,
      "aksara-coverage-radius": radius,
      "aksara-chart-mode": chartMode,
      "aksara-animation-mode": animationMode,
      "aksara-map-mode": mapMode,
    };

    Object.entries(pairs).forEach(([k, v]) => localStorage.setItem(k, v));

    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";

    notify();

    setStatus(
      `Applied: ${chartMode}, ${animationMode}, ${radius}, ${mapMode}. Open Dashboard / Realtime / Coverage Map to see runtime effect.`
    );
  };

  const reset = () => {
    setLang("id");
    setTheme("obsidian");
    setFontSize("normal");
    setDensity("comfortable");
    setRefreshRate("5s");
    setChartWindow("15 minutes");
    setTelemetrySource("Live API");
    setRadius("10 km");
    setChartMode("Engineer Dense");
    setAnimationMode("Normal");
    setMapMode("RF Planning");

    [
      "aksara-lang",
      "aksara-theme",
      "aksara-font-size",
      "aksara-density",
      "aksara-refresh-rate",
      "aksara-chart-window",
      "aksara-telemetry-source",
      "aksara-coverage-radius",
      "aksara-chart-mode",
      "aksara-animation-mode",
      "aksara-map-mode",
    ].forEach((key) => localStorage.removeItem(key));

    notify();
    setStatus("Reset to default enterprise profile.");
  };

  const clearCache = async () => {
    try {
      sessionStorage.clear();

      const preserved: Record<string, string> = {
        "aksara-lang": lang,
        "aksara-theme": theme,
        "aksara-font-size": fontSize,
        "aksara-density": density,
        "aksara-refresh-rate": refreshRate,
        "aksara-chart-window": chartWindow,
        "aksara-telemetry-source": telemetrySource,
        "aksara-coverage-radius": radius,
        "aksara-chart-mode": chartMode,
        "aksara-animation-mode": animationMode,
        "aksara-map-mode": mapMode,
      };

      Object.keys(localStorage).forEach((key) => {
        if (
          key.includes("cache") ||
          key.includes("next") ||
          key.includes("telemetry") ||
          key.includes("qoe") ||
          key.includes("coverage") ||
          key.includes("leaflet") ||
          key.includes("floating")
        ) {
          localStorage.removeItem(key);
        }
      });

      Object.entries(preserved).forEach(([key, value]) => localStorage.setItem(key, value));

      if ("caches" in window) {
        const names = await caches.keys();
        await Promise.all(names.map((name) => caches.delete(name)));
      }

      setStatus("UI cache cleared. Page will reload.");
      setTimeout(() => window.location.reload(), 700);
    } catch {
      setStatus("Cache cleanup partially completed. Use Ctrl + Shift + R if old UI still appears.");
    }
  };

  const SelectRow = ({
    label,
    value,
    setValue,
    options,
  }: {
    label: string;
    value: string;
    setValue: (v: string) => void;
    options: string[];
  }) => (
    <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-800 py-4">
      <div>
        <p className="font-bold text-white">{label}</p>
        <p className="text-xs text-slate-500">Current value: {value}</p>
      </div>
      <select
        value={value}
        onChange={(e) => setValue(e.target.value)}
        className="min-w-[220px] rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-white"
      >
        {options.map((x) => (
          <option key={x} value={x}>
            {x}
          </option>
        ))}
      </select>
    </div>
  );

  return (
    <main className="space-y-8 p-6 text-white">
      <section className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">Settings</h1>
          <p className="mt-2 max-w-4xl text-slate-400">
            Enterprise runtime configuration for language, theme, chart behavior, coverage planning mode,
            telemetry refresh, readability, project team, and reference model.
          </p>
        </div>

        <div className="flex flex-wrap gap-3">
          <button
            onClick={clearCache}
            className="rounded-xl border border-red-500/30 bg-red-500/10 px-5 py-3 text-sm font-bold text-red-300 hover:bg-red-500/20"
          >
            <Trash2 className="mr-2 inline h-4 w-4" />
            Clear UI Cache
          </button>

          <button
            onClick={reset}
            className="rounded-xl border border-slate-700 px-5 py-3 text-sm font-bold text-slate-300 hover:bg-slate-800"
          >
            <RotateCcw className="mr-2 inline h-4 w-4" />
            Reset
          </button>

          <button
            onClick={apply}
            className="rounded-xl border border-cyan-500/30 bg-cyan-500/10 px-5 py-3 text-sm font-black text-cyan-300 hover:bg-cyan-500/20"
          >
            <CheckCircle2 className="mr-2 inline h-4 w-4" />
            Apply Settings
          </button>
        </div>
      </section>

      <section className="rounded-3xl border border-emerald-500/30 bg-emerald-500/10 p-5">
        <div className="flex items-center gap-3">
          <ShieldCheck className="h-6 w-6 text-emerald-300" />
          <div>
            <p className="font-black text-emerald-300">Configuration Status</p>
            <p className="mt-1 text-sm text-slate-300">{status}</p>
          </div>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <Languages className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Language Runtime</h2>
              <p className="text-sm text-slate-400">
                Translates navigation, status labels, common buttons, and operational labels.
              </p>
            </div>
          </div>

          <select
            value={lang}
            onChange={(e) => setLang(e.target.value)}
            className="mb-5 w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-white"
          >
            {languages.map((item) => (
              <option key={item.code} value={item.code}>
                {item.label}
              </option>
            ))}
          </select>

          <div className="grid gap-3 md:grid-cols-3">
            {languages.map((item) => (
              <button
                key={item.code}
                onClick={() => setLang(item.code)}
                className={`rounded-2xl border p-4 text-left transition ${
                  lang === item.code
                    ? "border-cyan-500/60 bg-cyan-500/10"
                    : "border-slate-800 bg-slate-950/70 hover:border-slate-600"
                }`}
              >
                <div className="flex items-center justify-between">
                  <p className="font-black">{item.label}</p>
                  <Globe2 className="h-4 w-4 text-cyan-300" />
                </div>
                <p className="mt-2 text-xs text-slate-400">{item.note}</p>
              </button>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <Palette className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Enterprise Theme Profile</h2>
              <p className="text-sm text-slate-400">
                High-readability theme applied globally across panels, buttons, maps, and charts.
              </p>
            </div>
          </div>

          <div className="grid gap-3 md:grid-cols-2">
            {themes.map((item) => (
              <button
                key={item.key}
                onClick={() => setTheme(item.key)}
                className={`rounded-2xl border p-4 text-left transition ${
                  theme === item.key
                    ? "border-cyan-500/60 bg-cyan-500/10"
                    : "border-slate-800 bg-slate-950/70 hover:border-slate-600"
                }`}
              >
                <div className="flex items-center justify-between">
                  <p className="font-black">{item.name}</p>
                  <span
                    className="h-5 w-5 rounded-full border border-white/20"
                    style={{ backgroundColor: item.accent }}
                  />
                </div>
                <p className="mt-2 text-xs text-slate-400">{item.desc}</p>
              </button>
            ))}
          </div>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-3">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <Monitor className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Readability</h2>
              <p className="text-sm text-slate-400">Font profile for laptop, projector, and technical review.</p>
            </div>
          </div>
          <SelectRow label="Font Size" value={fontSize} setValue={setFontSize} options={fontSizes} />
          <SelectRow label="Layout Density" value={density} setValue={setDensity} options={densityOptions} />
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <Wifi className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Telemetry Behavior</h2>
              <p className="text-sm text-slate-400">Controls refresh timing and data-source preference.</p>
            </div>
          </div>
          <SelectRow label="Refresh Rate" value={refreshRate} setValue={setRefreshRate} options={refreshOptions} />
          <SelectRow label="Chart Window" value={chartWindow} setValue={setChartWindow} options={chartWindows} />
          <SelectRow label="Telemetry Source" value={telemetrySource} setValue={setTelemetrySource} options={telemetrySources} />
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <SlidersHorizontal className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Visualization Profile</h2>
              <p className="text-sm text-slate-400">These settings now affect chart, animation, and coverage map runtime.</p>
            </div>
          </div>
          <SelectRow label="Chart Mode" value={chartMode} setValue={setChartMode} options={chartModes} />
          <SelectRow label="Animation Mode" value={animationMode} setValue={setAnimationMode} options={animationModes} />
          <SelectRow label="Coverage Radius" value={radius} setValue={setRadius} options={coverageRadius} />
          <SelectRow label="Coverage Map Mode" value={mapMode} setValue={setMapMode} options={mapModes} />
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <Users className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Project Team</h2>
              <p className="text-sm text-slate-400">Core development responsibility for the platform.</p>
            </div>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            {team.map((member) => (
              <div key={member.name} className="rounded-2xl border border-slate-800 bg-slate-950 p-5">
                <p className="text-xl font-black text-white">{member.name}</p>
                <p className="mt-1 font-bold text-cyan-300">{member.role}</p>
                <p className="mt-3 text-sm leading-relaxed text-slate-400">{member.responsibility}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <BookOpen className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Project Reference Model</h2>
              <p className="text-sm text-slate-400">Technical inspiration and implementation references used by the project.</p>
            </div>
          </div>

          <div className="space-y-3">
            {references.map((item, index) => (
              <div key={item} className="rounded-xl border border-slate-800 bg-slate-950 p-4">
                <p className="text-sm leading-relaxed text-slate-300">
                  <span className="mr-2 font-black text-cyan-300">{index + 1}.</span>
                  {item}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
        <div className="mb-5 flex items-center gap-3">
          <Settings className="h-6 w-6 text-cyan-300" />
          <div>
            <h2 className="text-xl font-black">System Configuration</h2>
            <p className="text-sm text-slate-400">
              Current platform configuration remains connected to backend telemetry and browser runtime state.
            </p>
          </div>
        </div>

        <div className="grid gap-3 md:grid-cols-3">
          {[
            ["Backend API", "operational", Database],
            ["Database", "operational", Database],
            ["ML Service", "operational", SlidersHorizontal],
            ["Deployment", "Google Cloud Run", Globe2],
            ["Telemetry Source", telemetrySource, Wifi],
            ["Report Export", "Server-side PDF / CSV", Monitor],
          ].map(([label, value, Icon]: any) => (
            <div key={label} className="flex items-center justify-between rounded-xl border border-slate-800 bg-slate-950 p-4">
              <div className="flex items-center gap-3">
                <Icon className="h-4 w-4 text-cyan-300" />
                <span className="font-bold text-slate-300">{label}</span>
              </div>
              <span className="font-black text-emerald-300">{value}</span>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
TSX

cat > app/api/auth/google-finalize/route.js <<JS
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "$API_URL";

const TEAM_EMAILS = [
  "febriyadi845@gmail.com",
  "muhammad.febryadi.te23@stu.pnj.ac.id"
];

const TEAM_PHONE_SUFFIX = [
  "1027",
  "845"
];

function normalizePhone(phone) {
  return String(phone || "").replace(/[^0-9]/g, "");
}

function isTeamAccess(email, phone, isTeam) {
  const e = String(email || "").toLowerCase().trim();
  const p = normalizePhone(phone);

  if (!isTeam) return false;
  if (TEAM_EMAILS.includes(e)) return true;
  if (TEAM_PHONE_SUFFIX.some((suffix) => p.endsWith(suffix))) return true;

  return false;
}

export async function POST(req) {
  try {
    const body = await req.json();
    const email = String(body.email || "").toLowerCase().trim();
    const phone = normalizePhone(body.phone);
    const isTeam = Boolean(body.isTeam);
    const adminAccess = isTeamAccess(email, phone, isTeam);

    if (!email) {
      return Response.json({ error: "Email is required" }, { status: 400 });
    }

    let backend = null;

    try {
      const res = await fetch(`${API_URL}/api/auth/google/token`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        cache: "no-store",
        body: JSON.stringify({
          email,
          phone,
          is_team: isTeam,
          role_hint: adminAccess ? "Admin" : "Viewer"
        }),
      });

      if (res.ok) {
        backend = await res.json();
      } else {
        const fallback = await fetch(`${API_URL}/api/auth/google/token`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          cache: "no-store",
          body: JSON.stringify({ email }),
        });
        if (fallback.ok) backend = await fallback.json();
      }
    } catch {
      backend = null;
    }

    const role = adminAccess ? "Admin" : (backend?.role || "Viewer");
    const username =
      backend?.username ||
      email.split("@")[0].replace(/[^a-zA-Z0-9_-]/g, "_") ||
      "google_user";

    const response = {
      access_token:
        backend?.access_token ||
        Buffer.from(JSON.stringify({ sub: username, role, email, source: "frontend-session" })).toString("base64"),
      token_type: backend?.token_type || "bearer",
      id: backend?.id || Date.now(),
      username,
      role,
      email,
      phone_verified_for_team: adminAccess,
      source: backend ? "backend-google-token" : "frontend-session-fallback",
    };

    return Response.json(response, {
      status: 200,
      headers: { "Cache-Control": "no-store" },
    });
  } catch (error) {
    return Response.json(
      {
        error: "Google finalize failed",
        detail: String(error?.message || error),
      },
      { status: 500 }
    );
  }
}
JS

cat > app/auth/google-success/page.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { CheckCircle2, Loader2, Phone, ShieldCheck, UserCircle2 } from "lucide-react";

function getEmailFromUrl(params: URLSearchParams) {
  return (
    params.get("email") ||
    params.get("account") ||
    params.get("user") ||
    params.get("login_hint") ||
    localStorage.getItem("pending_google_email") ||
    localStorage.getItem("google_email") ||
    "febriyadi845@gmail.com"
  );
}

export default function GoogleSuccessPage() {
  const router = useRouter();
  const params = useSearchParams();

  const [email, setEmail] = useState("");
  const [isTeam, setIsTeam] = useState(false);
  const [phone, setPhone] = useState("");
  const [accessCode, setAccessCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");
  const [rolePreview, setRolePreview] = useState("Viewer");

  useEffect(() => {
    const e = getEmailFromUrl(params);
    setEmail(e);
  }, [params]);

  useEffect(() => {
    const digits = phone.replace(/[^0-9]/g, "");
    const emailAllowed =
      email.toLowerCase() === "febriyadi845@gmail.com" ||
      email.toLowerCase() === "muhammad.febryadi.te23@stu.pnj.ac.id";
    const phoneAllowed = digits.endsWith("1027") || digits.endsWith("845");
    setRolePreview(isTeam && (emailAllowed || phoneAllowed) ? "Admin" : "Viewer");
  }, [email, phone, isTeam]);

  const canSubmit = useMemo(() => {
    if (!email) return false;
    if (isTeam && phone.replace(/[^0-9]/g, "").length < 4) return false;
    return true;
  }, [email, phone, isTeam]);

  async function finalizeLogin() {
    if (!canSubmit) {
      setMessage("Masukkan nomor telepon tim terlebih dahulu.");
      return;
    }

    setLoading(true);
    setMessage("");

    try {
      const res = await fetch("/api/auth/google-finalize", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        cache: "no-store",
        body: JSON.stringify({
          email,
          isTeam,
          phone,
          accessCode,
        }),
      });

      const data = await res.json();

      if (!res.ok) {
        setMessage(data?.detail || data?.error || "Failed to finalize Google Sign-In.");
        setLoading(false);
        return;
      }

      localStorage.setItem("token", data.access_token || "");
      localStorage.setItem("access_token", data.access_token || "");
      localStorage.setItem("username", data.username || email.split("@")[0]);
      localStorage.setItem("email", data.email || email);
      localStorage.setItem("role", data.role || "Viewer");
      localStorage.setItem(
        "user",
        JSON.stringify({
          id: data.id,
          username: data.username || email.split("@")[0],
          email: data.email || email,
          role: data.role || "Viewer",
        })
      );

      setMessage(`Login completed as ${data.role || "Viewer"}. Redirecting...`);
      setTimeout(() => router.push("/"), 700);
    } catch {
      setMessage("Failed to fetch. Check frontend API route or backend service.");
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950 p-6 text-white">
      <section className="w-full max-w-xl rounded-3xl border border-cyan-500/30 bg-slate-900/80 p-8 shadow-2xl">
        <div className="text-center">
          <div className="mx-auto mb-5 flex h-16 w-16 items-center justify-center rounded-2xl border border-cyan-500/30 bg-cyan-500/10">
            <ShieldCheck className="h-8 w-8 text-cyan-300" />
          </div>

          <h1 className="text-3xl font-black text-cyan-300">Complete Google Sign-In</h1>
          <p className="mt-3 text-slate-400">
            Google account will be finalized into the AKSARA Union platform session.
          </p>
        </div>

        <div className="mt-8 space-y-5">
          <div className="rounded-2xl border border-slate-700 bg-slate-950 p-5">
            <div className="mb-2 flex items-center gap-2 text-slate-400">
              <UserCircle2 className="h-4 w-4" />
              <p className="text-sm">Google Account</p>
            </div>
            <input
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-xl border border-slate-800 bg-slate-900 px-4 py-3 font-bold text-white"
              placeholder="name@example.com"
            />
          </div>

          <label className="block cursor-pointer rounded-2xl border border-slate-700 bg-slate-950 p-5">
            <div className="flex items-start gap-4">
              <input
                type="checkbox"
                checked={isTeam}
                onChange={(e) => setIsTeam(e.target.checked)}
                className="mt-1 h-5 w-5"
              />
              <div>
                <p className="font-black text-white">Are you AKSARA Team?</p>
                <p className="mt-1 text-sm text-slate-400">
                  Team access requires registered email or phone verification.
                </p>
              </div>
            </div>
          </label>

          {isTeam ? (
            <div className="space-y-4 rounded-2xl border border-cyan-500/30 bg-cyan-500/10 p-5">
              <div>
                <div className="mb-2 flex items-center gap-2 text-cyan-300">
                  <Phone className="h-4 w-4" />
                  <p className="text-sm font-bold">Team Phone Number</p>
                </div>
                <input
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="w-full rounded-xl border border-cyan-500/30 bg-slate-950 px-4 py-3 text-white"
                  placeholder="Contoh: 08xxxxxxxxxx"
                />
                <p className="mt-2 text-xs text-slate-400">
                  Untuk demo saat ini, email Febryadi atau nomor berakhiran 1027 / 845 akan mendapat Admin.
                </p>
              </div>

              <div>
                <p className="mb-2 text-sm font-bold text-cyan-300">Optional Access Note</p>
                <input
                  value={accessCode}
                  onChange={(e) => setAccessCode(e.target.value)}
                  className="w-full rounded-xl border border-cyan-500/30 bg-slate-950 px-4 py-3 text-white"
                  placeholder="Contoh: AKSARA internal team"
                />
              </div>
            </div>
          ) : null}

          <div className="rounded-2xl border border-slate-700 bg-slate-950 p-5">
            <p className="text-sm text-slate-400">Role Preview</p>
            <p className={rolePreview === "Admin" ? "mt-1 text-2xl font-black text-emerald-300" : "mt-1 text-2xl font-black text-cyan-300"}>
              {rolePreview}
            </p>
          </div>

          <button
            onClick={finalizeLogin}
            disabled={loading}
            className="w-full rounded-2xl bg-cyan-400 px-5 py-4 font-black text-slate-950 hover:bg-cyan-300 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? (
              <>
                <Loader2 className="mr-2 inline h-5 w-5 animate-spin" />
                Finalizing...
              </>
            ) : (
              <>
                <CheckCircle2 className="mr-2 inline h-5 w-5" />
                Continue to Dashboard
              </>
            )}
          </button>

          {message ? (
            <div className="rounded-2xl border border-slate-700 bg-slate-950 p-4 text-center text-sm text-slate-300">
              {message}
            </div>
          ) : null}
        </div>
      </section>
    </main>
  );
}
TSX

echo "=================================================="
echo "SCAN ACTIVE WORDS"
echo "=================================================="
grep -Rni "Lecturer Evidence\|dosen" app components --exclude-dir=node_modules --exclude-dir=.next || true

echo "=================================================="
echo "DONE"
echo "=================================================="
