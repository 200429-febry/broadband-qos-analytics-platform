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
