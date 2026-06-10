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
