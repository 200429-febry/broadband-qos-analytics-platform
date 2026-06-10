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
