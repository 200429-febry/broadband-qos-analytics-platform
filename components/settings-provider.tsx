"use client";

import { useEffect } from "react";

export function SettingsProvider() {
  useEffect(() => {
    const applySettings = () => {
      const theme = localStorage.getItem("themeMode") || "Dark";
      const fontSize = localStorage.getItem("fontSize") || "Medium";
      const sidebarMode = localStorage.getItem("sidebarMode") || "Expanded";

      document.documentElement.setAttribute("data-theme", theme.toLowerCase());
      document.documentElement.setAttribute("data-font", fontSize.toLowerCase());
      document.documentElement.setAttribute("data-sidebar", sidebarMode.toLowerCase());
    };

    applySettings();

    window.addEventListener("storage", applySettings);
    window.addEventListener("app-settings-changed", applySettings);

    return () => {
      window.removeEventListener("storage", applySettings);
      window.removeEventListener("app-settings-changed", applySettings);
    };
  }, []);

  return null;
}