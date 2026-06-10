#!/bin/bash
set -e

echo "=================================================="
echo "FIX SETTINGS + GLOBAL I18N + CLEAR CACHE"
echo "=================================================="

mkdir -p .backup-settings-i18n-v2
[ -f components/enterprise-runtime-shell.tsx ] && cp components/enterprise-runtime-shell.tsx .backup-settings-i18n-v2/enterprise-runtime-shell.tsx.bak
[ -f app/settings/page.tsx ] && cp app/settings/page.tsx .backup-settings-i18n-v2/settings-page.tsx.bak

cat > components/enterprise-runtime-shell.tsx <<'TSX'
"use client";

import { useEffect } from "react";

type Lang =
  | "id"
  | "en"
  | "ja"
  | "ko"
  | "zh"
  | "ar"
  | "de"
  | "fr"
  | "es"
  | "pt"
  | "ms"
  | "tr"
  | "it"
  | "nl"
  | "ru";

const phrases = {
  Dashboard: {
    id: "Dashboard",
    en: "Dashboard",
    ja: "ダッシュボード",
    ko: "대시보드",
    zh: "仪表盘",
    ar: "لوحة التحكم",
    de: "Dashboard",
    fr: "Tableau de bord",
    es: "Panel",
    pt: "Painel",
    ms: "Papan Pemuka",
    tr: "Kontrol Paneli",
    it: "Dashboard",
    nl: "Dashboard",
    ru: "Панель",
  },
  "Realtime Monitor": {
    id: "Monitor Realtime",
    en: "Realtime Monitor",
    ja: "リアルタイム監視",
    ko: "실시간 모니터",
    zh: "实时监控",
    ar: "المراقبة اللحظية",
    de: "Echtzeitmonitor",
    fr: "Surveillance temps réel",
    es: "Monitor en tiempo real",
    pt: "Monitor em tempo real",
    ms: "Monitor Masa Nyata",
    tr: "Gerçek Zamanlı İzleme",
    it: "Monitor in tempo reale",
    nl: "Realtime monitor",
    ru: "Мониторинг",
  },
  "Streaming QoE": {
    id: "QoE Streaming",
    en: "Streaming QoE",
    ja: "ストリーミングQoE",
    ko: "스트리밍 QoE",
    zh: "流媒体QoE",
    ar: "جودة تجربة البث",
    de: "Streaming-QoE",
    fr: "QoE Streaming",
    es: "QoE de Streaming",
    pt: "QoE de Streaming",
    ms: "QoE Penstriman",
    tr: "Yayın QoE",
    it: "QoE Streaming",
    nl: "Streaming QoE",
    ru: "QoE стриминга",
  },
  "QoS Analytics": {
    id: "Analitik QoS",
    en: "QoS Analytics",
    ja: "QoS分析",
    ko: "QoS 분석",
    zh: "QoS分析",
    ar: "تحليلات جودة الخدمة",
    de: "QoS-Analytik",
    fr: "Analyse QoS",
    es: "Analítica QoS",
    pt: "Análise QoS",
    ms: "Analitik QoS",
    tr: "QoS Analitiği",
    it: "Analisi QoS",
    nl: "QoS-analyse",
    ru: "Аналитика QoS",
  },
  "Coverage Map": {
    id: "Peta Coverage",
    en: "Coverage Map",
    ja: "カバレッジマップ",
    ko: "커버리지 맵",
    zh: "覆盖地图",
    ar: "خريطة التغطية",
    de: "Abdeckungskarte",
    fr: "Carte de couverture",
    es: "Mapa de cobertura",
    pt: "Mapa de cobertura",
    ms: "Peta Liputan",
    tr: "Kapsama Haritası",
    it: "Mappa copertura",
    nl: "Dekkingskaart",
    ru: "Карта покрытия",
  },
  "Prediction ML": {
    id: "Prediksi ML",
    en: "Prediction ML",
    ja: "ML予測",
    ko: "예측 ML",
    zh: "机器学习预测",
    ar: "تنبؤات تعلم الآلة",
    de: "ML-Prognose",
    fr: "Prédiction ML",
    es: "Predicción ML",
    pt: "Predição ML",
    ms: "Ramalan ML",
    tr: "ML Tahmini",
    it: "Predizione ML",
    nl: "ML-voorspelling",
    ru: "ML прогноз",
  },
  "Stream Health": {
    id: "Kesehatan Stream",
    en: "Stream Health",
    ja: "ストリーム状態",
    ko: "스트림 상태",
    zh: "流媒体健康",
    ar: "صحة البث",
    de: "Stream-Zustand",
    fr: "Santé du flux",
    es: "Salud del stream",
    pt: "Saúde do stream",
    ms: "Kesihatan Stream",
    tr: "Yayın Sağlığı",
    it: "Stato stream",
    nl: "Streamstatus",
    ru: "Состояние стрима",
  },
  Incidents: {
    id: "Insiden",
    en: "Incidents",
    ja: "インシデント",
    ko: "장애 이력",
    zh: "事件",
    ar: "الحوادث",
    de: "Vorfälle",
    fr: "Incidents",
    es: "Incidentes",
    pt: "Incidentes",
    ms: "Insiden",
    tr: "Olaylar",
    it: "Incidenti",
    nl: "Incidenten",
    ru: "Инциденты",
  },
  Reports: {
    id: "Laporan",
    en: "Reports",
    ja: "レポート",
    ko: "리포트",
    zh: "报告",
    ar: "التقارير",
    de: "Berichte",
    fr: "Rapports",
    es: "Reportes",
    pt: "Relatórios",
    ms: "Laporan",
    tr: "Raporlar",
    it: "Report",
    nl: "Rapporten",
    ru: "Отчеты",
  },
  Deployment: {
    id: "Deployment",
    en: "Deployment",
    ja: "デプロイ",
    ko: "배포",
    zh: "部署",
    ar: "النشر",
    de: "Bereitstellung",
    fr: "Déploiement",
    es: "Despliegue",
    pt: "Implantação",
    ms: "Deployment",
    tr: "Dağıtım",
    it: "Distribuzione",
    nl: "Implementatie",
    ru: "Развертывание",
  },
  Observability: {
    id: "Observability",
    en: "Observability",
    ja: "可観測性",
    ko: "관측성",
    zh: "可观测性",
    ar: "المراقبة التشغيلية",
    de: "Observability",
    fr: "Observabilité",
    es: "Observabilidad",
    pt: "Observabilidade",
    ms: "Observability",
    tr: "Gözlemlenebilirlik",
    it: "Osservabilità",
    nl: "Observeerbaarheid",
    ru: "Наблюдаемость",
  },
  "Alert Center": {
    id: "Pusat Alert",
    en: "Alert Center",
    ja: "アラートセンター",
    ko: "알림 센터",
    zh: "告警中心",
    ar: "مركز التنبيهات",
    de: "Alarmzentrum",
    fr: "Centre d’alertes",
    es: "Centro de alertas",
    pt: "Central de alertas",
    ms: "Pusat Amaran",
    tr: "Uyarı Merkezi",
    it: "Centro avvisi",
    nl: "Alarmcentrum",
    ru: "Центр оповещений",
  },
  Topology: {
    id: "Topologi",
    en: "Topology",
    ja: "トポロジー",
    ko: "토폴로지",
    zh: "拓扑",
    ar: "الطوبولوجيا",
    de: "Topologie",
    fr: "Topologie",
    es: "Topología",
    pt: "Topologia",
    ms: "Topologi",
    tr: "Topoloji",
    it: "Topologia",
    nl: "Topologie",
    ru: "Топология",
  },
  "Database Monitor": {
    id: "Monitor Database",
    en: "Database Monitor",
    ja: "データベース監視",
    ko: "데이터베이스 모니터",
    zh: "数据库监控",
    ar: "مراقبة قاعدة البيانات",
    de: "Datenbankmonitor",
    fr: "Moniteur base de données",
    es: "Monitor de base de datos",
    pt: "Monitor de banco de dados",
    ms: "Monitor Pangkalan Data",
    tr: "Veritabanı Monitörü",
    it: "Monitor database",
    nl: "Databasemonitor",
    ru: "Монитор БД",
  },
  "Audit Log": {
    id: "Log Audit",
    en: "Audit Log",
    ja: "監査ログ",
    ko: "감사 로그",
    zh: "审计日志",
    ar: "سجل التدقيق",
    de: "Audit-Protokoll",
    fr: "Journal d’audit",
    es: "Registro de auditoría",
    pt: "Log de auditoria",
    ms: "Log Audit",
    tr: "Denetim Günlüğü",
    it: "Log audit",
    nl: "Auditlog",
    ru: "Журнал аудита",
  },
  "User Management": {
    id: "Manajemen User",
    en: "User Management",
    ja: "ユーザー管理",
    ko: "사용자 관리",
    zh: "用户管理",
    ar: "إدارة المستخدمين",
    de: "Benutzerverwaltung",
    fr: "Gestion utilisateurs",
    es: "Gestión de usuarios",
    pt: "Gerenciamento de usuários",
    ms: "Pengurusan Pengguna",
    tr: "Kullanıcı Yönetimi",
    it: "Gestione utenti",
    nl: "Gebruikersbeheer",
    ru: "Пользователи",
  },
  Settings: {
    id: "Pengaturan",
    en: "Settings",
    ja: "設定",
    ko: "설정",
    zh: "设置",
    ar: "الإعدادات",
    de: "Einstellungen",
    fr: "Paramètres",
    es: "Configuración",
    pt: "Configurações",
    ms: "Tetapan",
    tr: "Ayarlar",
    it: "Impostazioni",
    nl: "Instellingen",
    ru: "Настройки",
  },
  Logout: {
    id: "Keluar",
    en: "Logout",
    ja: "ログアウト",
    ko: "로그아웃",
    zh: "退出",
    ar: "تسجيل الخروج",
    de: "Abmelden",
    fr: "Déconnexion",
    es: "Cerrar sesión",
    pt: "Sair",
    ms: "Log Keluar",
    tr: "Çıkış",
    it: "Esci",
    nl: "Uitloggen",
    ru: "Выйти",
  },
  "System Stable": {
    id: "Sistem Stabil",
    en: "System Stable",
    ja: "システム安定",
    ko: "시스템 안정",
    zh: "系统稳定",
    ar: "النظام مستقر",
    de: "System stabil",
    fr: "Système stable",
    es: "Sistema estable",
    pt: "Sistema estável",
    ms: "Sistem Stabil",
    tr: "Sistem Stabil",
    it: "Sistema stabile",
    nl: "Systeem stabiel",
    ru: "Система стабильна",
  },
  "System Critical": {
    id: "Sistem Kritis",
    en: "System Critical",
    ja: "システム重大",
    ko: "시스템 위험",
    zh: "系统严重",
    ar: "النظام حرج",
    de: "System kritisch",
    fr: "Système critique",
    es: "Sistema crítico",
    pt: "Sistema crítico",
    ms: "Sistem Kritikal",
    tr: "Sistem Kritik",
    it: "Sistema critico",
    nl: "Systeem kritiek",
    ru: "Критическое состояние",
  },
  "Apply Settings": {
    id: "Terapkan Pengaturan",
    en: "Apply Settings",
    ja: "設定を適用",
    ko: "설정 적용",
    zh: "应用设置",
    ar: "تطبيق الإعدادات",
    de: "Einstellungen anwenden",
    fr: "Appliquer",
    es: "Aplicar ajustes",
    pt: "Aplicar configurações",
    ms: "Guna Tetapan",
    tr: "Ayarları Uygula",
    it: "Applica impostazioni",
    nl: "Instellingen toepassen",
    ru: "Применить",
  },
  Reset: {
    id: "Reset",
    en: "Reset",
    ja: "リセット",
    ko: "초기화",
    zh: "重置",
    ar: "إعادة ضبط",
    de: "Zurücksetzen",
    fr: "Réinitialiser",
    es: "Restablecer",
    pt: "Redefinir",
    ms: "Tetapkan Semula",
    tr: "Sıfırla",
    it: "Ripristina",
    nl: "Resetten",
    ru: "Сброс",
  },
  "Clear UI Cache": {
    id: "Bersihkan Cache UI",
    en: "Clear UI Cache",
    ja: "UIキャッシュ削除",
    ko: "UI 캐시 삭제",
    zh: "清除界面缓存",
    ar: "مسح ذاكرة الواجهة",
    de: "UI-Cache leeren",
    fr: "Vider le cache UI",
    es: "Limpiar caché UI",
    pt: "Limpar cache UI",
    ms: "Kosongkan Cache UI",
    tr: "UI Önbelleğini Temizle",
    it: "Pulisci cache UI",
    nl: "UI-cache wissen",
    ru: "Очистить кэш UI",
  },
  "Language Runtime": {
    id: "Runtime Bahasa",
    en: "Language Runtime",
    ja: "言語ランタイム",
    ko: "언어 런타임",
    zh: "语言运行时",
    ar: "محرك اللغة",
    de: "Sprachlaufzeit",
    fr: "Runtime langue",
    es: "Motor de idioma",
    pt: "Runtime de idioma",
    ms: "Runtime Bahasa",
    tr: "Dil Çalışma Zamanı",
    it: "Runtime lingua",
    nl: "Taalruntime",
    ru: "Языковой режим",
  },
  "Enterprise Theme Profile": {
    id: "Profil Tema Enterprise",
    en: "Enterprise Theme Profile",
    ja: "エンタープライズテーマ",
    ko: "엔터프라이즈 테마",
    zh: "企业主题配置",
    ar: "سمة المؤسسة",
    de: "Enterprise-Designprofil",
    fr: "Profil thème entreprise",
    es: "Perfil de tema empresarial",
    pt: "Perfil de tema empresarial",
    ms: "Profil Tema Enterprise",
    tr: "Kurumsal Tema Profili",
    it: "Profilo tema enterprise",
    nl: "Enterprise themaprofiel",
    ru: "Корпоративная тема",
  },
  Readability: {
    id: "Keterbacaan",
    en: "Readability",
    ja: "可読性",
    ko: "가독성",
    zh: "可读性",
    ar: "قابلية القراءة",
    de: "Lesbarkeit",
    fr: "Lisibilité",
    es: "Legibilidad",
    pt: "Legibilidade",
    ms: "Kebolehbacaan",
    tr: "Okunabilirlik",
    it: "Leggibilità",
    nl: "Leesbaarheid",
    ru: "Читаемость",
  },
  "System Configuration": {
    id: "Konfigurasi Sistem",
    en: "System Configuration",
    ja: "システム設定",
    ko: "시스템 구성",
    zh: "系统配置",
    ar: "إعدادات النظام",
    de: "Systemkonfiguration",
    fr: "Configuration système",
    es: "Configuración del sistema",
    pt: "Configuração do sistema",
    ms: "Konfigurasi Sistem",
    tr: "Sistem Yapılandırması",
    it: "Configurazione sistema",
    nl: "Systeemconfiguratie",
    ru: "Конфигурация системы",
  },
  "Configuration Status": {
    id: "Status Konfigurasi",
    en: "Configuration Status",
    ja: "設定状態",
    ko: "구성 상태",
    zh: "配置状态",
    ar: "حالة الإعداد",
    de: "Konfigurationsstatus",
    fr: "État de configuration",
    es: "Estado de configuración",
    pt: "Status da configuração",
    ms: "Status Konfigurasi",
    tr: "Yapılandırma Durumu",
    it: "Stato configurazione",
    nl: "Configuratiestatus",
    ru: "Статус конфигурации",
  },
  "Show Live": {
    id: "Tampilkan Live",
    en: "Show Live",
    ja: "ライブ表示",
    ko: "라이브 표시",
    zh: "显示实时",
    ar: "عرض مباشر",
    de: "Live anzeigen",
    fr: "Afficher live",
    es: "Mostrar en vivo",
    pt: "Mostrar ao vivo",
    ms: "Papar Live",
    tr: "Canlı Göster",
    it: "Mostra live",
    nl: "Live tonen",
    ru: "Показать live",
  },
  Hide: {
    id: "Sembunyikan",
    en: "Hide",
    ja: "非表示",
    ko: "숨기기",
    zh: "隐藏",
    ar: "إخفاء",
    de: "Ausblenden",
    fr: "Masquer",
    es: "Ocultar",
    pt: "Ocultar",
    ms: "Sembunyi",
    tr: "Gizle",
    it: "Nascondi",
    nl: "Verbergen",
    ru: "Скрыть",
  },
  "Search modules, BTS, streams, alerts...": {
    id: "Cari modul, BTS, stream, alert...",
    en: "Search modules, BTS, streams, alerts...",
    ja: "モジュール、BTS、ストリーム、アラートを検索...",
    ko: "모듈, BTS, 스트림, 알림 검색...",
    zh: "搜索模块、BTS、流、告警...",
    ar: "بحث عن الوحدات وBTS والبث والتنبيهات...",
    de: "Module, BTS, Streams, Alarme suchen...",
    fr: "Rechercher modules, BTS, flux, alertes...",
    es: "Buscar módulos, BTS, streams, alertas...",
    pt: "Pesquisar módulos, BTS, streams, alertas...",
    ms: "Cari modul, BTS, stream, amaran...",
    tr: "Modül, BTS, yayın, uyarı ara...",
    it: "Cerca moduli, BTS, stream, avvisi...",
    nl: "Zoek modules, BTS, streams, alarmen...",
    ru: "Поиск модулей, BTS, потоков, тревог...",
  },
} as const;

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
  sunrise: {
    "--aksara-bg": "#160b02",
    "--aksara-panel": "#2b1606",
    "--aksara-panel2": "#3b220d",
    "--aksara-border": "#b45309",
    "--aksara-text": "#fff7ed",
    "--aksara-muted": "#fdba74",
    "--aksara-accent": "#fb923c",
    "--aksara-accent2": "#fde047",
    "--aksara-danger": "#ef4444",
  },
  arctic: {
    "--aksara-bg": "#03111f",
    "--aksara-panel": "#082f49",
    "--aksara-panel2": "#0c4a6e",
    "--aksara-border": "#38bdf8",
    "--aksara-text": "#f0f9ff",
    "--aksara-muted": "#bae6fd",
    "--aksara-accent": "#7dd3fc",
    "--aksara-accent2": "#a7f3d0",
    "--aksara-danger": "#fb7185",
  },
  matrix: {
    "--aksara-bg": "#020a05",
    "--aksara-panel": "#06140b",
    "--aksara-panel2": "#092113",
    "--aksara-border": "#14532d",
    "--aksara-text": "#ecfdf5",
    "--aksara-muted": "#86efac",
    "--aksara-accent": "#22c55e",
    "--aksara-accent2": "#84cc16",
    "--aksara-danger": "#ef4444",
  },
  royal: {
    "--aksara-bg": "#08051a",
    "--aksara-panel": "#11103a",
    "--aksara-panel2": "#1e1b4b",
    "--aksara-border": "#4f46e5",
    "--aksara-text": "#eef2ff",
    "--aksara-muted": "#c7d2fe",
    "--aksara-accent": "#818cf8",
    "--aksara-accent2": "#22d3ee",
    "--aksara-danger": "#fb7185",
  },
};

const reverse = new Map<string, string>();

Object.entries(phrases).forEach(([canonical, translations]) => {
  reverse.set(canonical.trim().toLowerCase(), canonical);
  Object.values(translations).forEach((value) => {
    reverse.set(String(value).trim().toLowerCase(), canonical);
  });
});

function canonicalOf(text: string) {
  const key = text.trim().replace(/\s+/g, " ").toLowerCase();
  return reverse.get(key) || null;
}

function translate(text: string, lang: Lang) {
  const canonical = canonicalOf(text);
  if (!canonical) return text;
  const item = phrases[canonical as keyof typeof phrases] as any;
  return item?.[lang] || item?.en || canonical;
}

function applyTheme(theme: string) {
  const selected = themeVars[theme] || themeVars.obsidian;
  const root = document.documentElement;

  root.setAttribute("data-aksara-theme", theme);

  Object.entries(selected).forEach(([key, value]) => {
    root.style.setProperty(key, value);
  });
}

function translateDom(lang: Lang) {
  const walker = document.createTreeWalker(
    document.body,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        const parent = node.parentElement;
        if (!parent) return NodeFilter.FILTER_REJECT;

        const tag = parent.tagName.toLowerCase();
        if (["script", "style", "textarea", "code", "pre", "option"].includes(tag)) {
          return NodeFilter.FILTER_REJECT;
        }

        const raw = node.textContent?.trim() || "";
        if (!raw || raw.length > 80) return NodeFilter.FILTER_REJECT;

        return canonicalOf(raw) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      },
    }
  );

  const nodes: Node[] = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);

  nodes.forEach((node) => {
    const raw = node.textContent || "";
    const trimmed = raw.trim();
    const translated = translate(trimmed, lang);
    if (translated !== trimmed) {
      node.textContent = raw.replace(trimmed, translated);
    }
  });

  document.querySelectorAll<HTMLInputElement>("input[placeholder]").forEach((input) => {
    const ph = input.getAttribute("placeholder");
    if (ph) input.setAttribute("placeholder", translate(ph, lang));
  });
}

function applyFontProfile(profile: string) {
  const root = document.documentElement;
  root.setAttribute("data-aksara-font", profile);

  if (profile === "compact") root.style.setProperty("--aksara-font-scale", "0.92");
  else if (profile === "large") root.style.setProperty("--aksara-font-scale", "1.08");
  else if (profile === "presentation") root.style.setProperty("--aksara-font-scale", "1.14");
  else root.style.setProperty("--aksara-font-scale", "1");
}

function applyDensity(profile: string) {
  document.documentElement.setAttribute("data-aksara-density", profile);
}

export function EnterpriseRuntimeShell() {
  useEffect(() => {
    let busy = false;

    const applyAll = () => {
      if (busy) return;
      busy = true;

      requestAnimationFrame(() => {
        const lang = (localStorage.getItem("aksara-lang") || "id") as Lang;
        const theme = localStorage.getItem("aksara-theme") || "obsidian";
        const font = localStorage.getItem("aksara-font-size") || "normal";
        const density = localStorage.getItem("aksara-density") || "comfortable";

        document.documentElement.lang = lang;
        document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";

        applyTheme(theme);
        applyFontProfile(font);
        applyDensity(density);
        translateDom(lang);

        busy = false;
      });
    };

    applyAll();

    const observer = new MutationObserver(() => applyAll());
    observer.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
    });

    window.addEventListener("aksara-lang-change", applyAll);
    window.addEventListener("aksara-theme-change", applyAll);
    window.addEventListener("aksara-settings-change", applyAll);
    window.addEventListener("storage", applyAll);

    return () => {
      observer.disconnect();
      window.removeEventListener("aksara-lang-change", applyAll);
      window.removeEventListener("aksara-theme-change", applyAll);
      window.removeEventListener("aksara-settings-change", applyAll);
      window.removeEventListener("storage", applyAll);
    };
  }, []);

  return null;
}
TSX

cat >> app/globals.css <<'CSS'

/* AKSARA Runtime Settings v2 */
html[data-aksara-font="compact"] body {
  font-size: calc(0.92rem * var(--aksara-font-scale, 1));
}

html[data-aksara-font="normal"] body {
  font-size: calc(1rem * var(--aksara-font-scale, 1));
}

html[data-aksara-font="large"] body {
  font-size: calc(1.06rem * var(--aksara-font-scale, 1));
}

html[data-aksara-font="presentation"] body {
  font-size: calc(1.12rem * var(--aksara-font-scale, 1));
}

html[data-aksara-density="compact"] .rounded-3xl {
  border-radius: 1rem;
}

html[data-aksara-density="comfortable"] .rounded-3xl {
  border-radius: 1.25rem;
}

html[data-aksara-density="spacious"] .rounded-3xl {
  border-radius: 1.65rem;
}

html[data-aksara-theme] body,
html[data-aksara-theme] main {
  background-color: var(--aksara-bg) !important;
}

html[data-aksara-theme] .bg-slate-900\/70,
html[data-aksara-theme] .bg-slate-900\/80,
html[data-aksara-theme] .bg-slate-900\/90,
html[data-aksara-theme] .bg-slate-900 {
  background-color: color-mix(in srgb, var(--aksara-panel) 90%, transparent) !important;
}

html[data-aksara-theme] .bg-slate-950,
html[data-aksara-theme] .bg-slate-950\/70,
html[data-aksara-theme] .bg-slate-950\/80,
html[data-aksara-theme] .bg-slate-950\/90 {
  background-color: color-mix(in srgb, var(--aksara-bg) 96%, var(--aksara-panel) 4%) !important;
}

html[data-aksara-theme] .border-slate-800,
html[data-aksara-theme] .border-slate-700 {
  border-color: color-mix(in srgb, var(--aksara-border) 82%, #ffffff 8%) !important;
}
CSS

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

const fontSizes = [
  { key: "compact", label: "Compact", note: "Smaller labels, more rows visible" },
  { key: "normal", label: "Normal", note: "Balanced readability" },
  { key: "large", label: "Large", note: "Better for laptop screen share" },
  { key: "presentation", label: "Presentation", note: "Largest text for projector" },
];

const densityOptions = [
  { key: "compact", label: "Compact", note: "Tighter card spacing" },
  { key: "comfortable", label: "Comfortable", note: "Default dashboard spacing" },
  { key: "spacious", label: "Spacious", note: "More breathing room" },
];

const refreshOptions = ["3s", "5s", "10s", "15s", "30s"];
const chartWindows = ["5 minutes", "15 minutes", "30 minutes", "1 hour", "6 hours"];
const telemetrySources = ["Live API", "Browser QoE Probe", "Cloud SQL Window", "BigQuery Parsed View"];
const coverageRadius = ["2 km", "5 km", "10 km", "25 km", "50 km"];
const chartModes = ["Balanced", "Engineer Dense", "Executive Clean", "Presentation"];
const animationModes = ["Reduced", "Normal", "Enhanced"];
const mapModes = ["Standard", "RF Planning", "Atoll-like", "CellMapper-like"];

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
    localStorage.setItem("aksara-lang", lang);
    localStorage.setItem("aksara-theme", theme);
    localStorage.setItem("aksara-font-size", fontSize);
    localStorage.setItem("aksara-density", density);
    localStorage.setItem("aksara-refresh-rate", refreshRate);
    localStorage.setItem("aksara-chart-window", chartWindow);
    localStorage.setItem("aksara-telemetry-source", telemetrySource);
    localStorage.setItem("aksara-coverage-radius", radius);
    localStorage.setItem("aksara-chart-mode", chartMode);
    localStorage.setItem("aksara-animation-mode", animationMode);
    localStorage.setItem("aksara-map-mode", mapMode);

    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";

    notify();
    setStatus("Applied globally. Language/theme/profile settings are now active across navigation, status labels, common actions, and runtime UI.");
  };

  const reset = () => {
    localStorage.setItem("aksara-lang", "id");
    localStorage.setItem("aksara-theme", "obsidian");
    localStorage.setItem("aksara-font-size", "normal");
    localStorage.setItem("aksara-density", "comfortable");
    localStorage.setItem("aksara-refresh-rate", "5s");
    localStorage.setItem("aksara-chart-window", "15 minutes");
    localStorage.setItem("aksara-telemetry-source", "Live API");
    localStorage.setItem("aksara-coverage-radius", "10 km");
    localStorage.setItem("aksara-chart-mode", "Engineer Dense");
    localStorage.setItem("aksara-animation-mode", "Normal");
    localStorage.setItem("aksara-map-mode", "RF Planning");

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

    notify();
    setStatus("Reset to default enterprise profile.");
  };

  const clearCache = async () => {
    const keepKeys = {
      lang,
      theme,
      fontSize,
      density,
      refreshRate,
      chartWindow,
      telemetrySource,
      radius,
      chartMode,
      animationMode,
      mapMode,
    };

    try {
      sessionStorage.clear();

      const preserve = {
        "aksara-lang": keepKeys.lang,
        "aksara-theme": keepKeys.theme,
        "aksara-font-size": keepKeys.fontSize,
        "aksara-density": keepKeys.density,
        "aksara-refresh-rate": keepKeys.refreshRate,
        "aksara-chart-window": keepKeys.chartWindow,
        "aksara-telemetry-source": keepKeys.telemetrySource,
        "aksara-coverage-radius": keepKeys.radius,
        "aksara-chart-mode": keepKeys.chartMode,
        "aksara-animation-mode": keepKeys.animationMode,
        "aksara-map-mode": keepKeys.mapMode,
      };

      Object.keys(localStorage).forEach((key) => {
        if (
          key.includes("next") ||
          key.includes("cache") ||
          key.includes("qoe") ||
          key.includes("telemetry") ||
          key.includes("dashboard") ||
          key.includes("coverage") ||
          key.includes("leaflet")
        ) {
          localStorage.removeItem(key);
        }
      });

      Object.entries(preserve).forEach(([key, value]) => localStorage.setItem(key, value));

      if ("caches" in window) {
        const names = await caches.keys();
        await Promise.all(names.map((name) => caches.delete(name)));
      }

      setStatus("UI cache, session cache, service-worker cache, and old telemetry UI states have been cleared. Refreshing page...");
      setTimeout(() => window.location.reload(), 800);
    } catch {
      setStatus("Cache cleanup partially completed. Manual hard refresh may still be required.");
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
            Enterprise interface configuration for language, theme, readability,
            dashboard density, telemetry behavior, map mode, chart mode, and browser cache control.
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
                Translates navigation, status, common actions, floating controls, and operational labels without repeating text.
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
                High-readability color systems applied globally across panels, buttons, cards, and charts.
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
              <p className="text-sm text-slate-400">Font profile for presentation and engineering review.</p>
            </div>
          </div>

          <div className="grid gap-3">
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
                <p className="font-black">{item.label}</p>
                <p className="mt-2 text-xs text-slate-400">{item.note}</p>
              </button>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <LayoutDashboard className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Layout Density</h2>
              <p className="text-sm text-slate-400">Controls panel spacing and visual compactness.</p>
            </div>
          </div>

          <div className="grid gap-3">
            {densityOptions.map((item) => (
              <button
                key={item.key}
                onClick={() => setDensity(item.key)}
                className={`rounded-2xl border p-4 text-left transition ${
                  density === item.key
                    ? "border-cyan-500/60 bg-cyan-500/10"
                    : "border-slate-800 bg-slate-950/70 hover:border-slate-600"
                }`}
              >
                <p className="font-black">{item.label}</p>
                <p className="mt-2 text-xs text-slate-400">{item.note}</p>
              </button>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <Wifi className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Telemetry Behavior</h2>
              <p className="text-sm text-slate-400">Controls refresh behavior and source preference.</p>
            </div>
          </div>

          <SelectRow label="Refresh Rate" value={refreshRate} setValue={setRefreshRate} options={refreshOptions} />
          <SelectRow label="Chart Window" value={chartWindow} setValue={setChartWindow} options={chartWindows} />
          <SelectRow label="Telemetry Source" value={telemetrySource} setValue={setTelemetrySource} options={telemetrySources} />
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-2">
        <div className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
          <div className="mb-5 flex items-center gap-3">
            <SlidersHorizontal className="h-6 w-6 text-cyan-300" />
            <div>
              <h2 className="text-xl font-black">Visualization Profile</h2>
              <p className="text-sm text-slate-400">Extra UI options for dashboard, realtime monitor, and coverage planning.</p>
            </div>
          </div>

          <SelectRow label="Chart Mode" value={chartMode} setValue={setChartMode} options={chartModes} />
          <SelectRow label="Animation Mode" value={animationMode} setValue={setAnimationMode} options={animationModes} />
          <SelectRow label="Coverage Radius" value={radius} setValue={setRadius} options={coverageRadius} />
          <SelectRow label="Coverage Map Mode" value={mapMode} setValue={setMapMode} options={mapModes} />
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

          <div className="mt-5 rounded-2xl border border-red-500/30 bg-red-500/10 p-4">
            <p className="font-black text-red-300">Cache Control</p>
            <p className="mt-2 text-sm text-slate-300">
              Use Clear UI Cache when language gets stuck, old translated text remains visible,
              floating widgets appear before login, or a deployed page still shows the previous build.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
TSX

echo "=================================================="
echo "DONE"
echo "=================================================="
