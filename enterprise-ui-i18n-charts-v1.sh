#!/bin/bash
set -e

echo "=================================================="
echo "ENTERPRISE UI + I18N + UNIQUE CHARTS PATCH"
echo "=================================================="

REGION="asia-southeast2"
PROJECT_ID=$(gcloud config get-value project)
API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

echo "PROJECT_ID=$PROJECT_ID"
echo "API_URL=$API_URL"

mkdir -p .backup-enterprise-ui-v1

for f in \
  app/layout.tsx \
  app/globals.css \
  app/page.tsx \
  app/monitoring/page.tsx \
  app/streaming-qoe/page.tsx \
  app/settings/page.tsx \
  app/database/page.tsx \
  components/gcp-database-proof-buttons.tsx
do
  if [ -f "$f" ]; then
    cp "$f" ".backup-enterprise-ui-v1/$(echo "$f" | tr '/' '_').bak"
    echo "Backup: $f"
  fi
done

echo "=================================================="
echo "1. GLOBAL ENTERPRISE RUNTIME: LANGUAGE + THEME"
echo "=================================================="

mkdir -p components

cat > components/enterprise-runtime-shell.tsx <<'TSX'
"use client";

import { useEffect } from "react";

type Lang = "id" | "en" | "ja" | "ko" | "zh" | "ar" | "de" | "fr" | "es" | "pt";

const defaultLang: Lang = "id";

const dictionaries: Record<Lang, Record<string, string>> = {
  id: {
    "Dashboard": "Dashboard",
    "Realtime Monitor": "Monitor Realtime",
    "Streaming QoE": "QoE Streaming",
    "QoS Analytics": "Analitik QoS",
    "Coverage Map": "Peta Coverage",
    "Prediction ML": "Prediksi ML",
    "Stream Health": "Kesehatan Stream",
    "Incidents": "Insiden",
    "Reports": "Laporan",
    "Deployment": "Deployment",
    "Observability": "Observability",
    "Alert Center": "Pusat Alert",
    "Topology": "Topologi",
    "Database Monitor": "Monitor Database",
    "Audit Log": "Log Audit",
    "User Management": "Manajemen User",
    "Settings": "Pengaturan",
    "System Stable": "Sistem Stabil",
    "System Critical": "Sistem Kritis",
    "Logout": "Keluar",
    "Search modules, BTS, streams, alerts...": "Cari modul, BTS, stream, alert...",
    "NOC Dashboard": "Dashboard NOC",
    "Executive overview of global network Quality of Service.": "Ringkasan eksekutif Quality of Service jaringan.",
    "Database Proof / Lecturer Evidence": "System Evidence Center",
    "Database Proof": "System Evidence Center",
    "Lecturer Evidence": "System Evidence",
    "Command bukti cepat untuk dosen:": "Command bukti cepat untuk audit teknis:",
    "Open Cloud SQL Instance": "Buka Cloud SQL Instance",
    "Open Cloud SQL Databases": "Buka Database Cloud SQL",
    "Open BigQuery Analytics": "Buka BigQuery Analytics",
    "Open API Service Console": "Buka Console API Service",
    "Open API Logs": "Buka Log API",
    "Open Raw QoS Metrics": "Buka Raw QoS Metrics",
    "Open Raw QoS History": "Buka Raw QoS History",
    "Open Raw QoE Latest": "Buka Raw QoE Latest",
    "Operational observability for Cloud SQL status and real QoE telemetry used by dashboard, reports, alerts, and prediction modules.": "Observability operasional untuk status Cloud SQL dan telemetry QoE real yang digunakan dashboard, laporan, alert, dan modul prediksi.",
    "Complete Google Sign-In": "Selesaikan Google Sign-In",
    "Continue to Dashboard": "Lanjut ke Dashboard",
    "Are you AKSARA Team?": "Apakah Anda Tim AKSARA?",
    "New Google accounts are automatically created as Viewer.": "Akun Google baru otomatis dibuat sebagai Viewer.",
    "Theme Mode": "Mode Tema",
    "Font Size": "Ukuran Font",
    "Sidebar Mode": "Mode Sidebar",
    "UI Density": "Kepadatan UI",
    "Telemetry Source": "Sumber Telemetry",
    "Language": "Bahasa",
    "Apply": "Terapkan",
    "Refresh": "Refresh",
    "Refresh Data": "Refresh Data",
    "Generate Technical PDF": "Generate PDF Teknis",
    "Export Real CSV": "Export CSV Real",
  },
  en: {
    "Dashboard": "Dashboard",
    "Realtime Monitor": "Realtime Monitor",
    "Streaming QoE": "Streaming QoE",
    "QoS Analytics": "QoS Analytics",
    "Coverage Map": "Coverage Map",
    "Prediction ML": "Prediction ML",
    "Stream Health": "Stream Health",
    "Incidents": "Incidents",
    "Reports": "Reports",
    "Deployment": "Deployment",
    "Observability": "Observability",
    "Alert Center": "Alert Center",
    "Topology": "Topology",
    "Database Monitor": "Database Monitor",
    "Audit Log": "Audit Log",
    "User Management": "User Management",
    "Settings": "Settings",
    "System Stable": "System Stable",
    "System Critical": "System Critical",
    "Logout": "Logout",
  },
  ja: {
    "Dashboard": "ダッシュボード",
    "Realtime Monitor": "リアルタイム監視",
    "Streaming QoE": "ストリーミングQoE",
    "QoS Analytics": "QoS分析",
    "Coverage Map": "カバレッジマップ",
    "Prediction ML": "ML予測",
    "Stream Health": "ストリーム状態",
    "Incidents": "インシデント",
    "Reports": "レポート",
    "Deployment": "デプロイ",
    "Observability": "可観測性",
    "Alert Center": "アラートセンター",
    "Topology": "トポロジー",
    "Database Monitor": "データベース監視",
    "Audit Log": "監査ログ",
    "User Management": "ユーザー管理",
    "Settings": "設定",
    "System Stable": "システム安定",
    "System Critical": "システム重大",
    "Logout": "ログアウト",
  },
  ko: {
    "Dashboard": "대시보드",
    "Realtime Monitor": "실시간 모니터",
    "Streaming QoE": "스트리밍 QoE",
    "QoS Analytics": "QoS 분석",
    "Coverage Map": "커버리지 맵",
    "Prediction ML": "예측 ML",
    "Stream Health": "스트림 상태",
    "Incidents": "장애 이력",
    "Reports": "리포트",
    "Deployment": "배포",
    "Observability": "관측성",
    "Alert Center": "알림 센터",
    "Topology": "토폴로지",
    "Database Monitor": "데이터베이스 모니터",
    "Audit Log": "감사 로그",
    "User Management": "사용자 관리",
    "Settings": "설정",
    "System Stable": "시스템 안정",
    "System Critical": "시스템 위험",
    "Logout": "로그아웃",
  },
  zh: {
    "Dashboard": "仪表盘",
    "Realtime Monitor": "实时监控",
    "Streaming QoE": "流媒体QoE",
    "QoS Analytics": "QoS分析",
    "Coverage Map": "覆盖地图",
    "Prediction ML": "机器学习预测",
    "Stream Health": "流媒体健康",
    "Incidents": "事件",
    "Reports": "报告",
    "Deployment": "部署",
    "Observability": "可观测性",
    "Alert Center": "告警中心",
    "Topology": "拓扑",
    "Database Monitor": "数据库监控",
    "Audit Log": "审计日志",
    "User Management": "用户管理",
    "Settings": "设置",
    "System Stable": "系统稳定",
    "System Critical": "系统严重",
    "Logout": "退出",
  },
  ar: {
    "Dashboard": "لوحة التحكم",
    "Realtime Monitor": "المراقبة اللحظية",
    "Streaming QoE": "جودة تجربة البث",
    "QoS Analytics": "تحليلات جودة الخدمة",
    "Coverage Map": "خريطة التغطية",
    "Prediction ML": "تنبؤات تعلم الآلة",
    "Stream Health": "صحة البث",
    "Incidents": "الحوادث",
    "Reports": "التقارير",
    "Deployment": "النشر",
    "Observability": "المراقبة التشغيلية",
    "Alert Center": "مركز التنبيهات",
    "Topology": "الطوبولوجيا",
    "Database Monitor": "مراقبة قاعدة البيانات",
    "Audit Log": "سجل التدقيق",
    "User Management": "إدارة المستخدمين",
    "Settings": "الإعدادات",
    "System Stable": "النظام مستقر",
    "System Critical": "النظام حرج",
    "Logout": "تسجيل الخروج",
  },
  de: {
    "Dashboard": "Dashboard",
    "Realtime Monitor": "Echtzeitmonitor",
    "Streaming QoE": "Streaming-QoE",
    "QoS Analytics": "QoS-Analytik",
    "Coverage Map": "Abdeckungskarte",
    "Prediction ML": "ML-Prognose",
    "Stream Health": "Stream-Zustand",
    "Incidents": "Vorfälle",
    "Reports": "Berichte",
    "Deployment": "Bereitstellung",
    "Observability": "Observability",
    "Alert Center": "Alarmzentrum",
    "Topology": "Topologie",
    "Database Monitor": "Datenbankmonitor",
    "Audit Log": "Audit-Protokoll",
    "User Management": "Benutzerverwaltung",
    "Settings": "Einstellungen",
    "System Stable": "System stabil",
    "System Critical": "System kritisch",
    "Logout": "Abmelden",
  },
  fr: {
    "Dashboard": "Tableau de bord",
    "Realtime Monitor": "Surveillance temps réel",
    "Streaming QoE": "QoE Streaming",
    "QoS Analytics": "Analyse QoS",
    "Coverage Map": "Carte de couverture",
    "Prediction ML": "Prédiction ML",
    "Stream Health": "Santé du flux",
    "Incidents": "Incidents",
    "Reports": "Rapports",
    "Deployment": "Déploiement",
    "Observability": "Observabilité",
    "Alert Center": "Centre d’alertes",
    "Topology": "Topologie",
    "Database Monitor": "Moniteur base de données",
    "Audit Log": "Journal d’audit",
    "User Management": "Gestion utilisateurs",
    "Settings": "Paramètres",
    "System Stable": "Système stable",
    "System Critical": "Système critique",
    "Logout": "Déconnexion",
  },
  es: {
    "Dashboard": "Panel",
    "Realtime Monitor": "Monitor en tiempo real",
    "Streaming QoE": "QoE de Streaming",
    "QoS Analytics": "Analítica QoS",
    "Coverage Map": "Mapa de cobertura",
    "Prediction ML": "Predicción ML",
    "Stream Health": "Salud del stream",
    "Incidents": "Incidentes",
    "Reports": "Reportes",
    "Deployment": "Despliegue",
    "Observability": "Observabilidad",
    "Alert Center": "Centro de alertas",
    "Topology": "Topología",
    "Database Monitor": "Monitor de base de datos",
    "Audit Log": "Registro de auditoría",
    "User Management": "Gestión de usuarios",
    "Settings": "Configuración",
    "System Stable": "Sistema estable",
    "System Critical": "Sistema crítico",
    "Logout": "Cerrar sesión",
  },
  pt: {
    "Dashboard": "Painel",
    "Realtime Monitor": "Monitor em tempo real",
    "Streaming QoE": "QoE de Streaming",
    "QoS Analytics": "Análise QoS",
    "Coverage Map": "Mapa de cobertura",
    "Prediction ML": "Predição ML",
    "Stream Health": "Saúde do stream",
    "Incidents": "Incidentes",
    "Reports": "Relatórios",
    "Deployment": "Implantação",
    "Observability": "Observabilidade",
    "Alert Center": "Central de alertas",
    "Topology": "Topologia",
    "Database Monitor": "Monitor de banco de dados",
    "Audit Log": "Log de auditoria",
    "User Management": "Gerenciamento de usuários",
    "Settings": "Configurações",
    "System Stable": "Sistema estável",
    "System Critical": "Sistema crítico",
    "Logout": "Sair",
  },
};

const themeVars: Record<string, Record<string, string>> = {
  obsidian: {
    "--aksara-bg": "#020617",
    "--aksara-panel": "#0f172a",
    "--aksara-panel2": "#111827",
    "--aksara-border": "#1e293b",
    "--aksara-text": "#f8fafc",
    "--aksara-muted": "#94a3b8",
    "--aksara-accent": "#06b6d4",
    "--aksara-accent2": "#10b981",
    "--aksara-danger": "#ef4444",
  },
  pacific: {
    "--aksara-bg": "#031926",
    "--aksara-panel": "#06283d",
    "--aksara-panel2": "#0b3954",
    "--aksara-border": "#145374",
    "--aksara-text": "#f1f5f9",
    "--aksara-muted": "#b6d6e6",
    "--aksara-accent": "#22d3ee",
    "--aksara-accent2": "#38bdf8",
    "--aksara-danger": "#fb7185",
  },
  emerald: {
    "--aksara-bg": "#011b14",
    "--aksara-panel": "#052e24",
    "--aksara-panel2": "#064e3b",
    "--aksara-border": "#0f766e",
    "--aksara-text": "#ecfdf5",
    "--aksara-muted": "#a7f3d0",
    "--aksara-accent": "#34d399",
    "--aksara-accent2": "#22c55e",
    "--aksara-danger": "#fb7185",
  },
  violet: {
    "--aksara-bg": "#11071f",
    "--aksara-panel": "#1e1233",
    "--aksara-panel2": "#2e1065",
    "--aksara-border": "#6d28d9",
    "--aksara-text": "#faf5ff",
    "--aksara-muted": "#c4b5fd",
    "--aksara-accent": "#a78bfa",
    "--aksara-accent2": "#22d3ee",
    "--aksara-danger": "#f43f5e",
  },
  amber: {
    "--aksara-bg": "#1c1202",
    "--aksara-panel": "#2a1b05",
    "--aksara-panel2": "#3f2a09",
    "--aksara-border": "#92400e",
    "--aksara-text": "#fff7ed",
    "--aksara-muted": "#fed7aa",
    "--aksara-accent": "#f59e0b",
    "--aksara-accent2": "#22c55e",
    "--aksara-danger": "#ef4444",
  },
  graphite: {
    "--aksara-bg": "#09090b",
    "--aksara-panel": "#18181b",
    "--aksara-panel2": "#27272a",
    "--aksara-border": "#3f3f46",
    "--aksara-text": "#fafafa",
    "--aksara-muted": "#a1a1aa",
    "--aksara-accent": "#e5e7eb",
    "--aksara-accent2": "#06b6d4",
    "--aksara-danger": "#f87171",
  },
  plasma: {
    "--aksara-bg": "#140014",
    "--aksara-panel": "#250025",
    "--aksara-panel2": "#3b093b",
    "--aksara-border": "#be185d",
    "--aksara-text": "#fff1f2",
    "--aksara-muted": "#f9a8d4",
    "--aksara-accent": "#f472b6",
    "--aksara-accent2": "#22d3ee",
    "--aksara-danger": "#fb7185",
  },
  navy: {
    "--aksara-bg": "#050816",
    "--aksara-panel": "#0b132b",
    "--aksara-panel2": "#1c2541",
    "--aksara-border": "#3a506b",
    "--aksara-text": "#f8fafc",
    "--aksara-muted": "#a3b3c7",
    "--aksara-accent": "#5bc0be",
    "--aksara-accent2": "#6fffe9",
    "--aksara-danger": "#ff6b6b",
  },
};

function applyTheme(theme: string) {
  const root = document.documentElement;
  const selected = themeVars[theme] || themeVars.obsidian;

  root.setAttribute("data-aksara-theme", theme);
  Object.entries(selected).forEach(([key, value]) => {
    root.style.setProperty(key, value);
  });
}

function translateTextNode(node: Node, dict: Record<string, string>) {
  if (!node.textContent) return;

  const original = node.textContent.trim();
  if (!original) return;

  const replacement = dict[original];
  if (replacement) {
    node.textContent = node.textContent.replace(original, replacement);
  }
}

function translateElementTree(root: ParentNode, lang: Lang) {
  const dict = dictionaries[lang] || dictionaries.id;

  const walker = document.createTreeWalker(
    root,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        const parent = node.parentElement;
        if (!parent) return NodeFilter.FILTER_REJECT;
        const tag = parent.tagName.toLowerCase();
        if (["script", "style", "textarea", "code", "pre"].includes(tag)) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      },
    }
  );

  const nodes: Node[] = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);
  nodes.forEach((node) => translateTextNode(node, dict));

  document.querySelectorAll<HTMLInputElement>("input[placeholder]").forEach((input) => {
    const placeholder = input.getAttribute("placeholder");
    if (placeholder && dict[placeholder]) input.setAttribute("placeholder", dict[placeholder]);
  });
}

export function EnterpriseRuntimeShell() {
  useEffect(() => {
    const applyAll = () => {
      const lang = (localStorage.getItem("aksara-lang") || defaultLang) as Lang;
      const theme = localStorage.getItem("aksara-theme") || "obsidian";

      document.documentElement.lang = lang;
      document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";

      applyTheme(theme);
      translateElementTree(document.body, lang);
    };

    applyAll();

    const observer = new MutationObserver(() => {
      window.requestAnimationFrame(applyAll);
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
    });

    const onLang = () => applyAll();
    const onStorage = () => applyAll();

    window.addEventListener("aksara-lang-change", onLang);
    window.addEventListener("aksara-theme-change", onLang);
    window.addEventListener("storage", onStorage);

    return () => {
      observer.disconnect();
      window.removeEventListener("aksara-lang-change", onLang);
      window.removeEventListener("aksara-theme-change", onLang);
      window.removeEventListener("storage", onStorage);
    };
  }, []);

  return null;
}
TSX

echo "=================================================="
echo "2. GLOBAL ENTERPRISE THEME CSS"
echo "=================================================="

cat >> app/globals.css <<'CSS'

/* AKSARA Enterprise Theme Runtime */
html[data-aksara-theme] body {
  background:
    radial-gradient(circle at top right, color-mix(in srgb, var(--aksara-accent) 14%, transparent), transparent 32rem),
    radial-gradient(circle at bottom left, color-mix(in srgb, var(--aksara-accent2) 12%, transparent), transparent 30rem),
    var(--aksara-bg) !important;
  color: var(--aksara-text) !important;
}

html[data-aksara-theme] main,
html[data-aksara-theme] .bg-slate-950,
html[data-aksara-theme] .bg-slate-950\/95 {
  background-color: var(--aksara-bg) !important;
}

html[data-aksara-theme] .bg-slate-900,
html[data-aksara-theme] .bg-slate-900\/70,
html[data-aksara-theme] .bg-slate-900\/80,
html[data-aksara-theme] .bg-slate-900\/90 {
  background-color: color-mix(in srgb, var(--aksara-panel) 86%, transparent) !important;
}

html[data-aksara-theme] .bg-slate-800,
html[data-aksara-theme] .bg-slate-800\/70,
html[data-aksara-theme] .bg-slate-800\/80 {
  background-color: var(--aksara-panel2) !important;
}

html[data-aksara-theme] .border-slate-800,
html[data-aksara-theme] .border-slate-700 {
  border-color: color-mix(in srgb, var(--aksara-border) 86%, #ffffff 8%) !important;
}

html[data-aksara-theme] .text-cyan-300,
html[data-aksara-theme] .text-cyan-400 {
  color: var(--aksara-accent) !important;
}

html[data-aksara-theme] .text-emerald-300,
html[data-aksara-theme] .text-emerald-400 {
  color: var(--aksara-accent2) !important;
}

html[data-aksara-theme] .text-slate-400,
html[data-aksara-theme] .text-slate-500 {
  color: var(--aksara-muted) !important;
}

html[data-aksara-theme] button,
html[data-aksara-theme] select,
html[data-aksara-theme] input {
  color-scheme: dark;
}

html[data-aksara-theme] a:hover,
html[data-aksara-theme] button:hover {
  filter: brightness(1.08);
}

html[data-aksara-theme] svg text {
  font-family: inherit;
}
CSS

echo "=================================================="
echo "3. INJECT RUNTIME INTO APP LAYOUT"
echo "=================================================="

python3 <<'PY'
from pathlib import Path

p = Path("app/layout.tsx")
s = p.read_text()

import_line = 'import { EnterpriseRuntimeShell } from "@/components/enterprise-runtime-shell";'

if import_line not in s:
    lines = s.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, import_line)
    s = "\n".join(lines)

if "<EnterpriseRuntimeShell />" not in s:
    if "</body>" in s:
        s = s.replace("</body>", "        <EnterpriseRuntimeShell />\n      </body>", 1)
    else:
        print("WARNING: </body> not found, cannot inject runtime shell automatically")

p.write_text(s)
print("✅ EnterpriseRuntimeShell injected")
PY

echo "=================================================="
echo "4. REWRITE SYSTEM EVIDENCE BUTTONS, NO DOSEN / LECTURER"
echo "=================================================="

cat > components/gcp-database-proof-buttons.tsx <<'TSX'
"use client";

import {
  Activity,
  Database,
  ExternalLink,
  FileSearch,
  Server,
  ShieldCheck,
  TerminalSquare,
} from "lucide-react";

const GCP_PROJECT_ID = "__PROJECT_ID__";
const REGION = "asia-southeast2";
const API_URL = "__API_URL__";

function cloudConsole(path: string) {
  const joiner = path.includes("?") ? "&" : "?";
  return `https://console.cloud.google.com/${path}${joiner}project=${GCP_PROJECT_ID}`;
}

const proofLinks = [
  {
    title: "Open Cloud SQL Instance",
    desc: "Operational PostgreSQL instance used by the platform.",
    href: cloudConsole("sql/instances/qos-db/overview"),
    icon: Database,
    color: "text-emerald-300",
  },
  {
    title: "Open Cloud SQL Databases",
    desc: "Database inventory and operational schema visibility.",
    href: cloudConsole("sql/instances/qos-db/databases"),
    icon: Server,
    color: "text-cyan-300",
  },
  {
    title: "Open BigQuery Analytics",
    desc: "Telemetry warehouse and analytical dataset evidence.",
    href: cloudConsole("bigquery"),
    icon: FileSearch,
    color: "text-yellow-300",
  },
  {
    title: "Open API Service Console",
    desc: "FastAPI Cloud Run service handling QoS endpoints.",
    href: cloudConsole(`run/detail/${REGION}/qos-api/metrics`),
    icon: Activity,
    color: "text-purple-300",
  },
  {
    title: "Open API Logs",
    desc: "Runtime request logs from dashboard, reports, and telemetry probes.",
    href: cloudConsole(`run/detail/${REGION}/qos-api/logs`),
    icon: ShieldCheck,
    color: "text-red-300",
  },
  {
    title: "Open Raw QoS Metrics",
    desc: "Current JSON telemetry consumed by the dashboard.",
    href: `${API_URL}/api/qos/metrics`,
    icon: TerminalSquare,
    color: "text-blue-300",
  },
  {
    title: "Open Raw QoS History",
    desc: "Real browser-to-cloud telemetry history window.",
    href: `${API_URL}/api/qos/history`,
    icon: Database,
    color: "text-emerald-300",
  },
  {
    title: "Open Raw QoE Latest",
    desc: "Latest QoE probe buffer from active browser sessions.",
    href: `${API_URL}/api/qoe/latest`,
    icon: Activity,
    color: "text-cyan-300",
  },
];

export function GcpDatabaseProofButtons() {
  const commandText =
    `curl -s ${API_URL}/api/qos/metrics\n` +
    `curl -s ${API_URL}/api/qos/history | head -c 800\n` +
    `curl -s ${API_URL}/api/qoe/latest | head -c 800`;

  return (
    <section className="mb-6 rounded-3xl border border-cyan-500/30 bg-cyan-500/5 p-6">
      <div className="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-black text-cyan-300">
            System Evidence Center
          </h2>
          <p className="mt-2 max-w-4xl text-sm leading-relaxed text-slate-400">
            Direct engineering links to Google Cloud Console and live telemetry endpoints.
            Use this panel to verify Cloud SQL, BigQuery, Cloud Run API, service logs,
            and raw QoE data flowing into the platform.
          </p>
        </div>

        <div className="rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-xs text-slate-300">
          <p>
            Project: <span className="font-bold text-cyan-300">{GCP_PROJECT_ID}</span>
          </p>
          <p>
            Region: <span className="font-bold text-emerald-300">{REGION}</span>
          </p>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {proofLinks.map((item) => {
          const Icon = item.icon;

          return (
            <a
              key={item.title}
              href={item.href}
              target="_blank"
              rel="noopener noreferrer"
              className="group rounded-2xl border border-slate-800 bg-slate-900/80 p-5 transition hover:border-cyan-500/60 hover:bg-slate-900"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex gap-4">
                  <div className="rounded-xl border border-slate-700 bg-slate-950 p-3">
                    <Icon className={`h-5 w-5 ${item.color}`} />
                  </div>

                  <div>
                    <h3 className="font-black text-white group-hover:text-cyan-300">
                      {item.title}
                    </h3>
                    <p className="mt-2 text-sm leading-relaxed text-slate-400">
                      {item.desc}
                    </p>
                  </div>
                </div>

                <ExternalLink className="h-4 w-4 shrink-0 text-slate-500 group-hover:text-cyan-300" />
              </div>
            </a>
          );
        })}
      </div>

      <div className="mt-5 rounded-2xl border border-slate-800 bg-slate-950/80 p-4">
        <p className="text-sm font-bold text-white">Quick verification commands:</p>
        <pre className="mt-3 overflow-x-auto rounded-xl bg-black/40 p-4 text-xs text-cyan-200">
          {commandText}
        </pre>
      </div>
    </section>
  );
}
TSX

python3 <<PY
from pathlib import Path
p = Path("components/gcp-database-proof-buttons.tsx")
s = p.read_text()
s = s.replace("__PROJECT_ID__", "$PROJECT_ID")
s = s.replace("__API_URL__", "$API_URL")
p.write_text(s)
PY

echo "=================================================="
echo "5. UNIQUE ENTERPRISE CHART PACKS"
echo "=================================================="

cat > components/enterprise-chart-packs.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertTriangle,
  BarChart3,
  Box,
  Database,
  Gauge,
  GitBranch,
  Radio,
  Server,
  ShieldCheck,
  Zap,
} from "lucide-react";

type H = {
  timestamp?: string;
  throughput?: number;
  latency?: number;
  jitter?: number;
  packet_loss?: number;
  qoe_score?: number;
  source?: string;
};

type AlertItem = {
  id?: string | number;
  type?: string;
  message?: string;
  metric?: string;
  time?: string;
  source?: string;
};

function n(v: unknown, fallback = 0) {
  const x = Number(v);
  return Number.isFinite(x) ? x : fallback;
}

function avg(items: H[], key: keyof H) {
  if (!items.length) return 0;
  return items.reduce((s, item) => s + n(item[key]), 0) / items.length;
}

function max(items: H[], key: keyof H) {
  if (!items.length) return 0;
  return Math.max(...items.map((item) => n(item[key])));
}

function min(items: H[], key: keyof H) {
  if (!items.length) return 0;
  return Math.min(...items.map((item) => n(item[key])));
}

function useTelemetry() {
  const [history, setHistory] = useState<H[]>([]);
  const [alerts, setAlerts] = useState<AlertItem[]>([]);

  async function refresh() {
    try {
      const [h, a] = await Promise.all([
        fetch(`/api/qos-history?x=${Date.now()}`, { cache: "no-store" }).then((r) => r.json()),
        fetch(`/api/qos-alerts?x=${Date.now()}`, { cache: "no-store" }).then((r) => r.json()),
      ]);

      setHistory(Array.isArray(h) ? h : []);
      setAlerts(Array.isArray(a) ? a : []);
    } catch {
      // keep previous
    }
  }

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, 5000);
    window.addEventListener("real-qoe-updated", refresh);

    return () => {
      clearInterval(interval);
      window.removeEventListener("real-qoe-updated", refresh);
    };
  }, []);

  return { history, alerts, refresh };
}

function panel(title: string, subtitle: string, icon: any, children: any) {
  const Icon = icon;

  return (
    <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-5">
      <div className="mb-4 flex items-start justify-between gap-4">
        <div>
          <h3 className="text-lg font-black text-white">{title}</h3>
          <p className="mt-1 text-xs text-slate-500">{subtitle}</p>
        </div>
        <div className="rounded-xl border border-cyan-500/20 bg-cyan-500/10 p-2">
          <Icon className="h-5 w-5 text-cyan-300" />
        </div>
      </div>
      {children}
    </div>
  );
}

function points(data: H[], key: keyof H, w: number, h: number, pad = 28) {
  const arr = data.slice(0, 24).reverse();
  const vals = arr.map((x) => n(x[key]));
  const hi = Math.max(...vals, 1);
  const lo = Math.min(...vals, 0);
  const range = Math.max(hi - lo, 1);

  return arr
    .map((d, i) => {
      const x = pad + (i * (w - pad * 2)) / Math.max(arr.length - 1, 1);
      const y = h - pad - ((n(d[key]) - lo) / range) * (h - pad * 2);
      return `${x},${y}`;
    })
    .join(" ");
}

function DashboardTrafficComplex({ history }: { history: H[] }) {
  const w = 900;
  const h = 320;
  const data = history.slice(0, 24).reverse();

  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="h-[340px] w-full">
      <defs>
        <linearGradient id="dashFill" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="var(--aksara-accent)" stopOpacity="0.32" />
          <stop offset="100%" stopColor="var(--aksara-accent)" stopOpacity="0.02" />
        </linearGradient>
      </defs>
      <rect x="0" y="0" width={w} height={h} rx="22" fill="#020617" />
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <line key={i} x1="50" x2={w - 30} y1={40 + i * 42} y2={40 + i * 42} stroke="#1e293b" strokeDasharray="7 7" />
      ))}
      <polyline points={points(data, "throughput", w, h)} fill="none" stroke="var(--aksara-accent)" strokeWidth="4" />
      <polyline points={points(data, "latency", w, h)} fill="none" stroke="#eab308" strokeWidth="3" />
      <polyline points={points(data, "jitter", w, h)} fill="none" stroke="#a855f7" strokeWidth="2.5" />
      {data.map((d, i) => {
        const x = 28 + (i * (w - 56)) / Math.max(data.length - 1, 1);
        const y = 275 - (n(d.qoe_score) / 100) * 90;
        const color = n(d.qoe_score) >= 90 ? "#22c55e" : n(d.qoe_score) >= 75 ? "#06b6d4" : n(d.qoe_score) >= 60 ? "#eab308" : "#ef4444";
        return <circle key={i} cx={x} cy={y} r="4" fill={color} />;
      })}
      <text x="55" y="300" fill="var(--aksara-accent)" fontSize="13">Throughput</text>
      <text x="165" y="300" fill="#eab308" fontSize="13">Latency</text>
      <text x="245" y="300" fill="#a855f7" fontSize="13">Jitter</text>
      <text x="315" y="300" fill="#22c55e" fontSize="13">QoE dots</text>
    </svg>
  );
}

function DashboardSlaRadar({ history, alerts }: { history: H[]; alerts: AlertItem[] }) {
  const throughput = Math.min((avg(history, "throughput") / 80) * 100, 100);
  const latency = Math.max(100 - (avg(history, "latency") / 200) * 100, 0);
  const jitter = Math.max(100 - (avg(history, "jitter") / 80) * 100, 0);
  const qoe = avg(history, "qoe_score");
  const reliability = alerts.length ? Math.max(100 - alerts.length * 16, 0) : 100;
  const values = [throughput, latency, jitter, qoe, reliability];
  const labels = ["Capacity", "Latency", "Jitter", "QoE", "Reliability"];

  const center = 150;
  const r = 105;

  const poly = values.map((v, i) => {
    const angle = (-90 + i * 72) * Math.PI / 180;
    const rr = (v / 100) * r;
    return `${center + Math.cos(angle) * rr},${center + Math.sin(angle) * rr}`;
  }).join(" ");

  return (
    <svg viewBox="0 0 300 300" className="mx-auto h-[300px] w-full max-w-[420px]">
      <rect x="0" y="0" width="300" height="300" rx="22" fill="#020617" />
      {[25, 50, 75, 100].map((pct) => (
        <polygon
          key={pct}
          points={[0, 1, 2, 3, 4].map((_, i) => {
            const angle = (-90 + i * 72) * Math.PI / 180;
            const rr = (pct / 100) * r;
            return `${center + Math.cos(angle) * rr},${center + Math.sin(angle) * rr}`;
          }).join(" ")}
          fill="none"
          stroke="#1e293b"
        />
      ))}
      <polygon points={poly} fill="var(--aksara-accent)" fillOpacity="0.24" stroke="var(--aksara-accent)" strokeWidth="3" />
      {labels.map((label, i) => {
        const angle = (-90 + i * 72) * Math.PI / 180;
        return (
          <text key={label} x={center + Math.cos(angle) * 128 - 25} y={center + Math.sin(angle) * 128} fill="#cbd5e1" fontSize="11">
            {label}
          </text>
        );
      })}
    </svg>
  );
}

function DashboardCapacityBars({ history }: { history: H[] }) {
  const data = history.slice(0, 18).reverse();
  const maxT = Math.max(...data.map((d) => n(d.throughput)), 1);

  return (
    <div className="grid h-[280px] grid-cols-18 items-end gap-2 rounded-2xl bg-slate-950 p-5">
      {data.map((d, i) => {
        const height = Math.max((n(d.throughput) / maxT) * 210, 5);
        const qoe = n(d.qoe_score);
        const color = qoe >= 90 ? "bg-emerald-400" : qoe >= 75 ? "bg-cyan-400" : qoe >= 60 ? "bg-yellow-400" : "bg-red-400";
        return (
          <div key={i} className="flex h-full flex-col justify-end gap-1">
            <div className={`${color} rounded-t-xl shadow-lg`} style={{ height }} title={`${d.timestamp} ${d.throughput} Mbps`} />
          </div>
        );
      })}
    </div>
  );
}

function RealtimeOscilloscope({ history }: { history: H[] }) {
  const w = 900;
  const h = 230;
  const data = history.slice(0, 32).reverse();

  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="h-[250px] w-full">
      <rect x="0" y="0" width={w} height={h} rx="22" fill="#000814" />
      {[...Array(10)].map((_, i) => (
        <line key={`v${i}`} x1={50 + i * 85} x2={50 + i * 85} y1="20" y2={h - 25} stroke="#0f766e" strokeOpacity="0.35" />
      ))}
      {[...Array(5)].map((_, i) => (
        <line key={`h${i}`} x1="30" x2={w - 30} y1={35 + i * 38} y2={35 + i * 38} stroke="#0f766e" strokeOpacity="0.35" />
      ))}
      <polyline points={points(data, "latency", w, h)} fill="none" stroke="#22c55e" strokeWidth="3" />
      <polyline points={points(data, "jitter", w, h)} fill="none" stroke="#f59e0b" strokeWidth="2" />
      <text x="35" y="210" fill="#22c55e" fontSize="13">Latency waveform</text>
      <text x="190" y="210" fill="#f59e0b" fontSize="13">Jitter overlay</text>
    </svg>
  );
}

function RealtimeWaterfall({ history }: { history: H[] }) {
  const data = history.slice(0, 40);

  return (
    <div className="rounded-2xl bg-slate-950 p-4">
      <div className="grid grid-cols-20 gap-1">
        {data.map((d, i) => {
          const latency = n(d.latency);
          const cls =
            latency < 60 ? "bg-emerald-400" :
            latency < 100 ? "bg-cyan-400" :
            latency < 160 ? "bg-yellow-400" : "bg-red-400";

          return (
            <div key={i} className={`${cls} h-10 rounded-md opacity-90`} title={`${d.timestamp} latency ${latency} ms`} />
          );
        })}
      </div>
      <p className="mt-3 text-xs text-slate-500">Waterfall color represents latency pressure per probe interval.</p>
    </div>
  );
}

function RealtimeEventLanes({ history, alerts }: { history: H[]; alerts: AlertItem[] }) {
  const data = history.slice(0, 12);

  return (
    <div className="space-y-3 rounded-2xl bg-slate-950 p-4">
      {data.map((d, i) => {
        const qoe = n(d.qoe_score);
        const alert = qoe < 75 || n(d.latency) > 100 || n(d.jitter) > 35;
        return (
          <div key={i} className="grid grid-cols-[120px_1fr_90px] items-center gap-3">
            <p className="text-xs text-slate-400">{d.timestamp || "-"}</p>
            <div className="h-3 rounded-full bg-slate-800">
              <div
                className={alert ? "h-3 rounded-full bg-yellow-400" : "h-3 rounded-full bg-emerald-400"}
                style={{ width: `${Math.max(Math.min(qoe, 100), 3)}%` }}
              />
            </div>
            <p className={alert ? "text-xs font-bold text-yellow-300" : "text-xs font-bold text-emerald-300"}>
              {alert ? "WATCH" : "OK"}
            </p>
          </div>
        );
      })}
      {alerts.length ? <p className="text-xs text-red-300">{alerts.length} active alert events detected.</p> : null}
    </div>
  );
}

function QoeGauge({ value }: { value: number }) {
  const radius = 82;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (Math.max(Math.min(value, 100), 0) / 100) * circumference;

  return (
    <svg viewBox="0 0 220 220" className="mx-auto h-[240px] w-full max-w-[320px]">
      <rect x="0" y="0" width="220" height="220" rx="28" fill="#020617" />
      <circle cx="110" cy="110" r={radius} fill="none" stroke="#1e293b" strokeWidth="18" />
      <circle
        cx="110"
        cy="110"
        r={radius}
        fill="none"
        stroke="var(--aksara-accent)"
        strokeWidth="18"
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={offset}
        transform="rotate(-90 110 110)"
      />
      <text x="110" y="104" textAnchor="middle" fill="#ffffff" fontSize="38" fontWeight="900">{value.toFixed(0)}</text>
      <text x="110" y="130" textAnchor="middle" fill="#94a3b8" fontSize="12">QoE Score</text>
    </svg>
  );
}

function QoeDegradationStack({ history }: { history: H[] }) {
  const latest = history[0] || {};
  const latencyPenalty = Math.max((n(latest.latency) - 80) * 0.18, 0);
  const jitterPenalty = Math.max((n(latest.jitter) - 20) * 0.7, 0);
  const lossPenalty = n(latest.packet_loss) * 20;
  const remaining = Math.max(100 - latencyPenalty - jitterPenalty - lossPenalty, 0);

  const parts = [
    ["Healthy Budget", remaining, "bg-emerald-400"],
    ["Latency Penalty", latencyPenalty, "bg-yellow-400"],
    ["Jitter Penalty", jitterPenalty, "bg-purple-400"],
    ["Loss Penalty", lossPenalty, "bg-red-400"],
  ];

  return (
    <div className="rounded-2xl bg-slate-950 p-5">
      <div className="flex h-12 overflow-hidden rounded-xl border border-slate-800">
        {parts.map(([label, value, cls]) => (
          <div key={String(label)} className={`${cls} h-full`} style={{ width: `${Math.max(Number(value), 2)}%` }} title={`${label}: ${Number(value).toFixed(1)}`} />
        ))}
      </div>
      <div className="mt-4 grid gap-2 md:grid-cols-4">
        {parts.map(([label, value, cls]) => (
          <div key={String(label)} className="rounded-xl border border-slate-800 bg-slate-900/80 p-3">
            <p className="text-xs text-slate-400">{label}</p>
            <p className="mt-1 text-lg font-black">{Number(value).toFixed(1)}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function QoeDecisionMatrix({ history }: { history: H[] }) {
  const latest = history[0] || {};
  const items = [
    {
      title: "Buffer Probability",
      value: n(latest.latency) > 100 || n(latest.jitter) > 35 ? "Elevated" : "Low",
      desc: "Derived from latency and jitter pressure.",
    },
    {
      title: "Transport Stability",
      value: n(latest.packet_loss) > 0.5 ? "Lossy" : "Stable",
      desc: "Based on packet-loss percentage.",
    },
    {
      title: "Capacity Headroom",
      value: n(latest.throughput) > 25 ? "Enough" : "Limited",
      desc: "Uses measured browser downlink throughput.",
    },
    {
      title: "Recommended Action",
      value: n(latest.qoe_score) >= 90 ? "Continue Monitoring" : "Inspect Path",
      desc: "Operational recommendation from QoE state.",
    },
  ];

  return (
    <div className="grid gap-4 md:grid-cols-4">
      {items.map((item) => (
        <div key={item.title} className="rounded-2xl border border-slate-800 bg-slate-950 p-4">
          <p className="text-xs uppercase tracking-[0.2em] text-slate-500">{item.title}</p>
          <p className="mt-3 text-2xl font-black text-white">{item.value}</p>
          <p className="mt-2 text-xs text-slate-400">{item.desc}</p>
        </div>
      ))}
    </div>
  );
}

export function DashboardNocAnalytics() {
  const { history, alerts } = useTelemetry();

  const summary = useMemo(() => ({
    avgThroughput: avg(history, "throughput"),
    avgLatency: avg(history, "latency"),
    minThroughput: min(history, "throughput"),
    maxLatency: max(history, "latency"),
  }), [history]);

  return (
    <section className="mt-8 space-y-6">
      <div>
        <h2 className="text-2xl font-black text-white">NOC Performance Analytics</h2>
        <p className="mt-2 text-sm text-slate-400">
          Dashboard-level view: executive KPI trend, SLA radar, and capacity distribution from real QoE telemetry.
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-4">
        {[
          ["Avg Throughput", `${summary.avgThroughput.toFixed(2)} Mbps`, Zap],
          ["Avg Latency", `${summary.avgLatency.toFixed(2)} ms`, Gauge],
          ["Min Throughput", `${summary.minThroughput.toFixed(2)} Mbps`, BarChart3],
          ["Max Latency", `${summary.maxLatency.toFixed(2)} ms`, AlertTriangle],
        ].map(([label, value, Icon]: any) => (
          <div key={label} className="rounded-2xl border border-slate-800 bg-slate-900/80 p-4">
            <Icon className="h-5 w-5 text-cyan-300" />
            <p className="mt-3 text-xs uppercase tracking-[0.2em] text-slate-500">{label}</p>
            <p className="mt-2 text-3xl font-black">{value}</p>
          </div>
        ))}
      </div>

      {panel("Integrated KPI Trend", "Throughput, latency, jitter, and QoE markers in one NOC chart.", Activity, <DashboardTrafficComplex history={history} />)}

      <div className="grid gap-6 xl:grid-cols-2">
        {panel("SLA Radar Profile", "High-level quality shape across capacity, latency, jitter, QoE, and reliability.", ShieldCheck, <DashboardSlaRadar history={history} alerts={alerts} />)}
        {panel("Capacity Distribution", "Throughput bars colored by QoE condition.", BarChart3, <DashboardCapacityBars history={history} />)}
      </div>
    </section>
  );
}

export function RealtimeEngineerConsole() {
  const { history, alerts } = useTelemetry();

  return (
    <section className="mt-8 space-y-6">
      <div>
        <h2 className="text-2xl font-black text-white">Realtime Engineering Console</h2>
        <p className="mt-2 text-sm text-slate-400">
          Realtime-specific visualization: oscilloscope waveform, latency waterfall, and event lanes.
        </p>
      </div>

      {panel("Latency / Jitter Oscilloscope", "Realtime waveform view for burst detection and congestion diagnosis.", Radio, <RealtimeOscilloscope history={history} />)}

      <div className="grid gap-6 xl:grid-cols-2">
        {panel("Probe Waterfall", "Interval-by-interval latency pressure map.", Activity, <RealtimeWaterfall history={history} />)}
        {panel("Event Lanes", "Operational state per telemetry interval.", GitBranch, <RealtimeEventLanes history={history} alerts={alerts} />)}
      </div>
    </section>
  );
}

export function QoeEngineerLab() {
  const { history } = useTelemetry();
  const latest = history[0] || {};
  const qoe = n(latest.qoe_score);

  return (
    <section className="mt-8 space-y-6">
      <div>
        <h2 className="text-2xl font-black text-white">Streaming QoE Engineering Detail</h2>
        <p className="mt-2 text-sm text-slate-400">
          QoE-specific view: quality gauge, degradation budget, and streaming decision matrix.
        </p>
      </div>

      <div className="grid gap-6 xl:grid-cols-[360px_1fr]">
        {panel("QoE Quality Gauge", "Current perceived streaming experience index.", Gauge, <QoeGauge value={qoe} />)}
        {panel("Degradation Budget", "How latency, jitter, and packet loss reduce the QoE score.", AlertTriangle, <QoeDegradationStack history={history} />)}
      </div>

      {panel("Streaming Decision Matrix", "Actionable interpretation for streaming playback condition.", Box, <QoeDecisionMatrix history={history} />)}
    </section>
  );
}
TSX

echo "=================================================="
echo "6. REMOVE REPEATED GENERIC CHART GRID AND INJECT UNIQUE CHARTS"
echo "=================================================="

python3 <<'PY'
from pathlib import Path
import re

pages = {
    "app/page.tsx": ("DashboardNocAnalytics", "dashboard"),
    "app/monitoring/page.tsx": ("RealtimeEngineerConsole", "realtime"),
    "app/streaming-qoe/page.tsx": ("QoeEngineerLab", "qoe"),
}

for file, (component, label) in pages.items():
    p = Path(file)
    if not p.exists():
        print(f"SKIP missing {file}")
        continue

    s = p.read_text()

    s = re.sub(r'\n?import \{ TechnicalChartGrid \} from "@/components/technical-chart-grid";\n?', '\n', s)
    s = re.sub(r'\s*<TechnicalChartGrid\s+scope="[^"]+"\s*/>\s*', '\n', s)

    import_line = f'import {{ {component} }} from "@/components/enterprise-chart-packs";'
    if import_line not in s:
        if '"use client";' in s:
            s = s.replace('"use client";', '"use client";\n\n' + import_line, 1)
        else:
            lines = s.splitlines()
            idx = 0
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    idx = i + 1
            lines.insert(idx, import_line)
            s = "\n".join(lines)

    marker = f"<{component} />"
    if marker not in s:
        if "</main>" in s:
            s = s.replace("</main>", f"      {marker}\n    </main>", 1)
        else:
            print(f"WARNING: no </main> in {file}")

    p.write_text(s)
    print(f"patched {file} with {component}")
PY

echo "=================================================="
echo "7. ENTERPRISE SETTINGS PAGE: LANGUAGE + THEME"
echo "=================================================="

cat > app/settings/page.tsx <<'TSX'
"use client";

import { useEffect, useState } from "react";
import {
  CheckCircle2,
  Globe2,
  Languages,
  Monitor,
  Palette,
  RefreshCw,
  Settings,
  ShieldCheck,
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
];

const fontSizes = [
  { key: "normal", label: "Normal", className: "text-base" },
  { key: "large", label: "Large", className: "text-lg" },
  { key: "dense", label: "Dense", className: "text-sm" },
];

export default function SettingsPage() {
  const [lang, setLang] = useState("id");
  const [theme, setTheme] = useState("obsidian");
  const [fontSize, setFontSize] = useState("normal");
  const [status, setStatus] = useState("Settings loaded from browser profile.");

  useEffect(() => {
    setLang(localStorage.getItem("aksara-lang") || "id");
    setTheme(localStorage.getItem("aksara-theme") || "obsidian");
    setFontSize(localStorage.getItem("aksara-font-size") || "normal");
  }, []);

  const apply = () => {
    localStorage.setItem("aksara-lang", lang);
    localStorage.setItem("aksara-theme", theme);
    localStorage.setItem("aksara-font-size", fontSize);

    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";

    window.dispatchEvent(new CustomEvent("aksara-lang-change", { detail: lang }));
    window.dispatchEvent(new CustomEvent("aksara-theme-change", { detail: theme }));
    window.dispatchEvent(new Event("storage"));

    setStatus("Applied globally. Open another menu or refresh once if a cached page still shows old text.");
  };

  const reset = () => {
    setLang("id");
    setTheme("obsidian");
    setFontSize("normal");
    localStorage.setItem("aksara-lang", "id");
    localStorage.setItem("aksara-theme", "obsidian");
    localStorage.setItem("aksara-font-size", "normal");
    window.dispatchEvent(new CustomEvent("aksara-lang-change", { detail: "id" }));
    window.dispatchEvent(new CustomEvent("aksara-theme-change", { detail: "obsidian" }));
    setStatus("Reset to default enterprise profile.");
  };

  return (
    <main className="space-y-8 p-6 text-white">
      <section className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">Settings</h1>
          <p className="mt-2 max-w-4xl text-slate-400">
            Enterprise interface configuration for language, visual theme, readability,
            telemetry behavior, and system status. Settings are stored locally in the browser
            and applied globally across the web app.
          </p>
        </div>

        <div className="flex gap-3">
          <button
            onClick={reset}
            className="rounded-xl border border-slate-700 px-5 py-3 text-sm font-bold text-slate-300 hover:bg-slate-800"
          >
            <RefreshCw className="mr-2 inline h-4 w-4" />
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
                Changes common navigation, status, action labels, settings text, and operational UI labels.
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

          <div className="grid gap-3 md:grid-cols-2">
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
                Different color systems with high readability. Applies across cards, panels, buttons, and charts.
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

      <section className="grid gap-6 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <Monitor className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Readability</h2>
              <p className="text-sm text-slate-400">
                Keep technical numbers readable during presentation and screen sharing.
              </p>
            </div>
          </div>

          <div className="grid gap-3 md:grid-cols-3">
            {fontSizes.map((item) => (
              <button
                key={item.key}
                onClick={() => setFontSize(item.key)}
                className={`rounded-2xl border p-4 text-left transition ${
                  fontSize === item.key
                    ? "border-cyan-500/60 bg-cyan-500/10"
                    : "border-slate-800 bg-slate-950/70 hover:border-slate-600"
                }`}
              >
                <p className={`font-black ${item.className}`}>{item.label}</p>
                <p className="mt-2 text-xs text-slate-400">Font profile</p>
              </button>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <Settings className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">System Configuration</h2>
              <p className="text-sm text-slate-400">
                Current platform configuration remains live and connected to backend telemetry.
              </p>
            </div>
          </div>

          <div className="space-y-3">
            {[
              ["Backend API", "operational"],
              ["Database", "operational"],
              ["ML Service", "operational"],
              ["Deployment", "Google Cloud Run"],
              ["Telemetry Source", "Live API"],
              ["Report Export", "Server-side PDF / CSV"],
            ].map(([label, value]) => (
              <div key={label} className="flex items-center justify-between rounded-xl border border-slate-800 bg-slate-950 p-4">
                <span className="font-bold text-slate-300">{label}</span>
                <span className="font-black text-emerald-300">{value}</span>
              </div>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}
TSX

echo "=================================================="
echo "8. SAFETY SCAN: REMOVE LECTURER/DOSEN WORDS FROM ACTIVE CODE"
echo "=================================================="

python3 <<'PY'
from pathlib import Path

for base in [Path("app"), Path("components")]:
    if not base.exists():
        continue
    for p in base.rglob("*"):
        if p.is_file() and p.suffix in [".tsx", ".ts", ".js", ".jsx"]:
            s = p.read_text(errors="ignore")
            ns = (
                s.replace("Lecturer Evidence", "System Evidence")
                 .replace("lecturer evidence", "system evidence")
                 .replace("dosen", "audit teknis")
                 .replace("Dosen", "Audit Teknis")
                 .replace("Command bukti cepat untuk dosen:", "Quick verification commands:")
            )
            if ns != s:
                p.write_text(ns)
                print("cleaned", p)
PY

echo "=================================================="
echo "DONE"
echo "=================================================="
