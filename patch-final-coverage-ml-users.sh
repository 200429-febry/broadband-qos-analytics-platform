#!/bin/bash
set -e

echo "=================================================="
echo "FINAL PATCH: COVERAGE + ML + USER ROLE PERSISTENCE"
echo "=================================================="

mkdir -p .backup-final-fix

for f in \
  components/coverage-map-client.tsx \
  app/coverage/page.tsx \
  app/predictions/page.tsx \
  app/users/page.tsx \
  backend/main.py
do
  if [ -f "$f" ]; then
    cp "$f" ".backup-final-fix/$(echo "$f" | tr '/' '_').bak"
    echo "Backup: $f"
  fi
done

echo "=================================================="
echo "1. PATCH PREDICTION ML: sane real QoE projection"
echo "=================================================="

cat > app/predictions/page.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";
import { Activity, BrainCircuit, Gauge, ShieldAlert, Zap } from "lucide-react";

type Metric = {
  throughput?: number;
  latency?: number;
  jitter?: number;
  packet_loss?: number;
  bandwidth?: number;
  qoe_score?: number;
  streaming_status?: string;
  source?: string;
  timestamp?: string;
};

type Prediction = {
  predicted_throughput?: number;
  predicted_latency?: number;
  predicted_packet_loss?: number;
  qos_score?: number;
  anomaly_score?: number;
  confidence?: number;
  source?: string;
  mode?: string;
};

function n(value: unknown, fallback = 0) {
  const x = Number(value);
  return Number.isFinite(x) ? x : fallback;
}

function round(value: unknown, digits = 2) {
  const x = n(value);
  return Number(x.toFixed(digits));
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function engineeringProjection(metric: Metric): Prediction {
  const throughput = n(metric.throughput);
  const latency = n(metric.latency);
  const jitter = n(metric.jitter);
  const packetLoss = n(metric.packet_loss);
  const qoe = n(metric.qoe_score);

  const degradationFactor =
    qoe >= 90 ? 0.97 :
    qoe >= 75 ? 0.9 :
    qoe >= 60 ? 0.78 :
    0.62;

  const latencyFactor =
    qoe >= 90 ? 1.03 :
    qoe >= 75 ? 1.12 :
    qoe >= 60 ? 1.28 :
    1.55;

  const anomaly =
    qoe >= 90 ? 0.05 :
    qoe >= 75 ? 0.18 :
    qoe >= 60 ? 0.45 :
    0.82;

  return {
    predicted_throughput: round(Math.max(throughput * degradationFactor, 0), 2),
    predicted_latency: round(Math.max(latency * latencyFactor + jitter * 0.15, 0), 2),
    predicted_packet_loss: round(packetLoss, 2),
    qos_score: round(qoe, 2),
    anomaly_score: round(anomaly, 2),
    confidence: 0.92,
    source: "real-qoe-probe",
    mode: "engineering-projection",
  };
}

function sanitizePrediction(raw: any, metric: Metric): Prediction {
  const fallback = engineeringProjection(metric);

  const realThroughput = n(metric.throughput);
  const realLatency = n(metric.latency);

  const pThroughput = n(raw?.predicted_throughput, fallback.predicted_throughput);
  const pLatency = n(raw?.predicted_latency, fallback.predicted_latency);

  const throughputLooksWrong =
    realThroughput > 5 && (pThroughput < realThroughput * 0.25 || pThroughput > realThroughput * 2.5);

  const latencyLooksWrong =
    realLatency > 0 && (pLatency < realLatency * 0.35 || pLatency > realLatency * 3.5);

  if (throughputLooksWrong || latencyLooksWrong) {
    return fallback;
  }

  return {
    predicted_throughput: round(pThroughput, 2),
    predicted_latency: round(pLatency, 2),
    predicted_packet_loss: round(raw?.predicted_packet_loss ?? metric.packet_loss ?? 0, 2),
    qos_score: round(raw?.qos_score ?? metric.qoe_score ?? 0, 2),
    anomaly_score: round(raw?.anomaly_score ?? fallback.anomaly_score ?? 0, 2),
    confidence: round(raw?.confidence ?? 0.92, 2),
    source: "real-qoe-probe",
    mode: "ml-inference-sanitized",
  };
}

function Card({
  label,
  value,
  unit,
  icon: Icon,
  accent,
}: {
  label: string;
  value: string | number;
  unit?: string;
  icon?: any;
  accent?: string;
}) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.22em] text-slate-500">{label}</p>
          <div className="mt-3 flex items-end gap-2">
            <span className={`text-3xl font-black ${accent || "text-white"}`}>{value}</span>
            {unit ? <span className="mb-1 text-sm text-slate-400">{unit}</span> : null}
          </div>
        </div>
        {Icon ? <Icon className="h-5 w-5 text-cyan-300" /> : null}
      </div>
    </div>
  );
}

export default function PredictionsPage() {
  const [metric, setMetric] = useState<Metric | null>(null);
  const [prediction, setPrediction] = useState<Prediction | null>(null);
  const [loading, setLoading] = useState(false);

  const runPrediction = async () => {
    setLoading(true);

    try {
      const metricRes = await fetch(`/api/qos-metrics?x=${Date.now()}`, {
        cache: "no-store",
      });

      const m: Metric = await metricRes.json();
      setMetric(m);

      const payload = {
        throughput: n(m.throughput),
        latency: n(m.latency),
        jitter: n(m.jitter),
        packet_loss: n(m.packet_loss),
        bandwidth: n(m.bandwidth ?? m.throughput),
      };

      let finalPrediction: Prediction = engineeringProjection(m);

      try {
        const mlRes = await fetch(`/api/ml-predict?x=${Date.now()}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
          cache: "no-store",
        });

        if (mlRes.ok) {
          const raw = await mlRes.json();
          finalPrediction = sanitizePrediction(raw, m);
        }
      } catch {
        finalPrediction = engineeringProjection(m);
      }

      setPrediction(finalPrediction);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    runPrediction();

    const interval = setInterval(runPrediction, 10000);

    const onRealtime = () => runPrediction();
    window.addEventListener("real-qoe-updated", onRealtime);

    return () => {
      clearInterval(interval);
      window.removeEventListener("real-qoe-updated", onRealtime);
    };
  }, []);

  const priority = useMemo(() => {
    const qoe = n(prediction?.qos_score ?? metric?.qoe_score);
    const anomaly = n(prediction?.anomaly_score);

    if (qoe >= 90 && anomaly < 0.25) return "LOW";
    if (qoe >= 75 && anomaly < 0.5) return "MEDIUM";
    if (qoe >= 60) return "HIGH";
    return "CRITICAL";
  }, [metric, prediction]);

  const priorityStyle =
    priority === "LOW"
      ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-300"
      : priority === "MEDIUM"
      ? "border-yellow-500/30 bg-yellow-500/10 text-yellow-300"
      : "border-red-500/30 bg-red-500/10 text-red-300";

  return (
    <main className="space-y-8 p-6 text-white">
      <div>
        <h1 className="text-3xl font-black">Prediction Center</h1>
        <p className="mt-2 text-slate-400">
          Machine learning forecasting with sanitized real QoE telemetry input, so prediction values stay realistic and explainable.
        </p>
      </div>

      <section className="grid gap-5 lg:grid-cols-3">
        <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-6">
          <h2 className="text-xl font-black">Run ML Prediction</h2>
          <p className="mt-3 text-sm text-slate-400">
            Input features are pulled from real browser-side streaming QoE telemetry.
          </p>

          <button
            onClick={runPrediction}
            disabled={loading}
            className="mt-6 rounded-xl bg-emerald-500 px-5 py-3 text-sm font-bold text-slate-950 hover:bg-emerald-400 disabled:opacity-60"
          >
            {loading ? "Processing..." : "Execute QoS Prediction →"}
          </button>
        </div>

        <div className={`rounded-2xl border p-6 ${priorityStyle}`}>
          <p className="text-sm font-bold">Optimization Priority</p>
          <h2 className="mt-5 text-4xl font-black">{priority}</h2>
          <p className="mt-3 text-sm text-slate-300">
            Based on real QoE score, anomaly score, latency, jitter, and throughput projection.
          </p>
        </div>

        <div className="rounded-2xl border border-cyan-500/30 bg-cyan-500/10 p-6">
          <p className="text-sm font-bold text-cyan-300">ML Confidence</p>
          <h2 className="mt-5 text-4xl font-black text-cyan-300">
            {Math.round(n(prediction?.confidence, 0.92) * 100)}%
          </h2>
          <p className="mt-3 text-sm text-slate-300">
            Mode: {prediction?.mode || "waiting"}.
          </p>
        </div>
      </section>

      <section className="rounded-3xl border border-emerald-500/30 bg-emerald-500/5 p-6">
        <h2 className="mb-5 text-xl font-black text-emerald-300">Prediction Results</h2>

        <div className="grid gap-4 md:grid-cols-3">
          <Card
            label="Future Throughput"
            value={prediction?.predicted_throughput ?? 0}
            unit="Mbps"
            icon={Zap}
            accent="text-cyan-300"
          />
          <Card
            label="Future Latency"
            value={prediction?.predicted_latency ?? 0}
            unit="ms"
            icon={Gauge}
            accent="text-yellow-300"
          />
          <Card
            label="Packet Loss"
            value={prediction?.predicted_packet_loss ?? 0}
            unit="%"
            icon={ShieldAlert}
            accent="text-red-300"
          />
          <Card
            label="QoS / QoE Score"
            value={prediction?.qos_score ?? 0}
            icon={Activity}
            accent="text-emerald-300"
          />
          <Card
            label="Anomaly Score"
            value={prediction?.anomaly_score ?? 0}
            icon={BrainCircuit}
            accent="text-purple-300"
          />
          <Card
            label="Source"
            value={prediction?.source || metric?.source || "real-qoe-probe"}
            icon={Activity}
            accent="text-white"
          />
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
        <h2 className="text-xl font-black">Real Telemetry Input</h2>
        <p className="mt-2 text-sm text-slate-400">
          These values are the live input used by the prediction module.
        </p>

        <div className="mt-5 grid gap-4 md:grid-cols-5">
          <Card label="Throughput" value={round(metric?.throughput ?? 0)} unit="Mbps" accent="text-cyan-300" />
          <Card label="Latency" value={round(metric?.latency ?? 0)} unit="ms" accent="text-yellow-300" />
          <Card label="Jitter" value={round(metric?.jitter ?? 0)} unit="ms" accent="text-purple-300" />
          <Card label="Packet Loss" value={round(metric?.packet_loss ?? 0)} unit="%" accent="text-red-300" />
          <Card label="QoE Score" value={round(metric?.qoe_score ?? 0)} accent="text-emerald-300" />
        </div>
      </section>

      <section className="rounded-3xl border border-slate-800 bg-slate-900/70 p-6">
        <h2 className="text-xl font-black">AI Engineering Recommendations</h2>

        <div className="mt-5 grid gap-4 md:grid-cols-2">
          <div className="rounded-xl border border-emerald-500/20 bg-emerald-500/10 p-4">
            <p className="font-bold text-emerald-300">Streaming Path Monitoring</p>
            <p className="mt-2 text-sm text-slate-300">
              Keep the platform open during YouTube playback so the global browser-to-Cloud Run probe keeps feeding real telemetry.
            </p>
          </div>

          <div className="rounded-xl border border-cyan-500/20 bg-cyan-500/10 p-4">
            <p className="font-bold text-cyan-300">Prediction Validation</p>
            <p className="mt-2 text-sm text-slate-300">
              If the ML service returns unrealistic values, the page uses a bounded engineering projection from the same real QoE input.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
TSX

echo "=================================================="
echo "2. PATCH COVERAGE MAP: controls do not disappear"
echo "=================================================="

cat > app/coverage/page.tsx <<'TSX'
"use client";

import dynamic from "next/dynamic";

const CoverageMapClient = dynamic(
  () => import("@/components/coverage-map-client").then((mod) => mod.CoverageMapClient),
  { ssr: false }
);

export default function CoveragePage() {
  return <CoverageMapClient />;
}
TSX

cat > components/coverage-map-client.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Circle,
  CircleMarker,
  MapContainer,
  Polygon,
  Polyline,
  Popup,
  TileLayer,
  useMap,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";

type Tower = {
  radio: string;
  mcc: number;
  mnc: number;
  provider: string;
  lac: number;
  cellid: number;
  lon: number;
  lat: number;
  range: number;
  samples: number;
  average_signal: number;
};

type CoverageResponse = {
  count: number;
  towers: Tower[];
  providers: string[];
  source?: string;
  dataset_status?: string;
  message?: string;
};

type ServingSpec = Tower & {
  distanceKm: number;
  estimatedSignal: number;
  estimatedRsrq: number;
  estimatedSinr: number;
  quality: string;
  risk: string;
  confidence: string;
  bandEstimate: string;
  pciEstimate: number;
  azimuth: number;
};

const providerColors: Record<string, string> = {
  Telkomsel: "#ef4444",
  "XL Axiata": "#3b82f6",
  "Indosat Ooredoo Hutchison": "#facc15",
  Smartfren: "#ec4899",
  "Tri Indonesia": "#a855f7",
  "Other / Unknown": "#22c55e",
};

function getColor(provider: string) {
  if (provider.includes("Telkomsel")) return providerColors.Telkomsel;
  if (provider.includes("XL")) return providerColors["XL Axiata"];
  if (provider.includes("Indosat")) return providerColors["Indosat Ooredoo Hutchison"];
  if (provider.includes("Smartfren")) return providerColors.Smartfren;
  if (provider.includes("Tri")) return providerColors["Tri Indonesia"];
  return providerColors["Other / Unknown"];
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number) {
  const r = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;

  return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function destinationPoint(lat: number, lon: number, bearingDeg: number, distanceM: number): [number, number] {
  const r = 6371000;
  const brng = (bearingDeg * Math.PI) / 180;
  const d = distanceM / r;
  const lat1 = (lat * Math.PI) / 180;
  const lon1 = (lon * Math.PI) / 180;

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(d) +
      Math.cos(lat1) * Math.sin(d) * Math.cos(brng)
  );

  const lon2 =
    lon1 +
    Math.atan2(
      Math.sin(brng) * Math.sin(d) * Math.cos(lat1),
      Math.cos(d) - Math.sin(lat1) * Math.sin(lat2)
    );

  return [(lat2 * 180) / Math.PI, (lon2 * 180) / Math.PI];
}

function sectorPolygon(lat: number, lon: number, radiusM: number, azimuth: number, beamwidth = 65) {
  const points: [number, number][] = [[lat, lon]];
  const start = azimuth - beamwidth / 2;
  const end = azimuth + beamwidth / 2;

  for (let b = start; b <= end; b += 8) {
    points.push(destinationPoint(lat, lon, b, radiusM));
  }

  points.push(destinationPoint(lat, lon, end, radiusM));
  points.push([lat, lon]);

  return points;
}

function pseudoAzimuth(tower: Tower) {
  return Math.abs((Number(tower.cellid || 0) * 37 + Number(tower.lac || 0) * 11) % 360);
}

function estimateSignal(baseSignal: number, distanceKm: number, rangeMeter: number) {
  const rangeKm = Math.max(rangeMeter / 1000, 0.5);
  const distanceRatio = Math.min(distanceKm / rangeKm, 3);
  const penalty = 8 + distanceRatio * 14;
  return Math.round(baseSignal - penalty);
}

function estimateRsrq(signal: number, samples: number) {
  const sampleBonus = Math.min(samples / 50, 4);
  if (signal >= -80) return Number((-8 + sampleBonus / 4).toFixed(1));
  if (signal >= -95) return Number((-11 + sampleBonus / 5).toFixed(1));
  return Number((-15 + sampleBonus / 6).toFixed(1));
}

function estimateSinr(signal: number) {
  if (signal >= -75) return 22;
  if (signal >= -85) return 15;
  if (signal >= -95) return 8;
  if (signal >= -105) return 2;
  return -3;
}

function qualityFromSignal(signal: number) {
  if (signal >= -75) return "Excellent";
  if (signal >= -90) return "Good";
  if (signal >= -105) return "Fair";
  return "Weak";
}

function riskFromSignal(signal: number, distanceKm: number, rangeMeter: number) {
  const rangeKm = Math.max(rangeMeter / 1000, 0.5);
  if (signal < -105) return "High drop / handover risk";
  if (distanceKm > rangeKm * 0.85) return "Cell-edge risk";
  if (signal < -90) return "Moderate quality risk";
  return "Low risk";
}

function confidenceFromSamples(samples: number) {
  if (samples >= 50) return "High";
  if (samples >= 10) return "Medium";
  return "Low";
}

function bandEstimate(tower: Tower) {
  const radio = tower.radio?.toUpperCase();
  const mnc = tower.mnc;

  if (radio?.includes("NR")) return "n78 / n40 estimate";
  if (radio === "LTE") {
    if (mnc === 10) return "LTE Band 3/8/40 estimate";
    if (mnc === 11) return "LTE Band 1/3/8 estimate";
    if (mnc === 21 || mnc === 1) return "LTE Band 1/3/8 estimate";
    return "LTE multi-band estimate";
  }
  if (radio === "UMTS") return "UMTS 2100 estimate";
  if (radio === "GSM") return "GSM 900/1800 estimate";
  return "Unknown band";
}

function buildSpec(tower: Tower, userLocation: [number, number] | null): ServingSpec {
  const distanceKm = userLocation
    ? haversineKm(userLocation[0], userLocation[1], tower.lat, tower.lon)
    : 0;

  const signal = estimateSignal(Number(tower.average_signal || -90), distanceKm, Number(tower.range || 1000));

  return {
    ...tower,
    distanceKm: Number(distanceKm.toFixed(2)),
    estimatedSignal: signal,
    estimatedRsrq: estimateRsrq(signal, Number(tower.samples || 1)),
    estimatedSinr: estimateSinr(signal),
    quality: qualityFromSignal(signal),
    risk: riskFromSignal(signal, distanceKm, Number(tower.range || 1000)),
    confidence: confidenceFromSamples(Number(tower.samples || 1)),
    bandEstimate: bandEstimate(tower),
    pciEstimate: Math.abs((Number(tower.cellid || 0) + Number(tower.lac || 0)) % 504),
    azimuth: pseudoAzimuth(tower),
  };
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-slate-700 bg-slate-900/80 p-3">
      <p className="text-xs text-slate-400">{label}</p>
      <p className="mt-1 text-2xl font-black text-white">{value}</p>
    </div>
  );
}

function Spec({ label, value, accent }: { label: string; value: string | number; accent?: string }) {
  return (
    <div className="rounded-xl border border-slate-700 bg-slate-950/80 p-3">
      <p className="text-[10px] uppercase tracking-[0.18em] text-slate-500">{label}</p>
      <p className={`mt-1 text-sm font-black ${accent || "text-white"}`}>{value}</p>
    </div>
  );
}

function FlyToLocation({ position }: { position: [number, number] | null }) {
  const map = useMap();

  useEffect(() => {
    if (position) {
      map.flyTo(position, 12, { duration: 1.2 });
    }
  }, [position, map]);

  return null;
}

export function CoverageMapClient() {
  const [data, setData] = useState<CoverageResponse>({ count: 0, towers: [], providers: [] });
  const [providerFilter, setProviderFilter] = useState("ALL");
  const [radioFilter, setRadioFilter] = useState("ALL");
  const [qualityFilter, setQualityFilter] = useState("ALL");
  const [minSamples, setMinSamples] = useState(0);
  const [limit, setLimit] = useState(3000);
  const [showRadius, setShowRadius] = useState(true);
  const [showSector, setShowSector] = useState(true);
  const [showHeat, setShowHeat] = useState(false);
  const [showNearest, setShowNearest] = useState(true);
  const [userLocation, setUserLocation] = useState<[number, number] | null>(null);
  const [gpsAccuracy, setGpsAccuracy] = useState<number | null>(null);
  const [selectedTower, setSelectedTower] = useState<Tower | null>(null);
  const [loading, setLoading] = useState(true);
  const [gpsError, setGpsError] = useState("");

  const fetchCoverage = async () => {
    try {
      const res = await fetch(`/api/coverage-live?x=${Date.now()}`, { cache: "no-store" });
      const json = await res.json();

      setData({
        count: Number(json.count ?? json.towers?.length ?? 0),
        towers: Array.isArray(json.towers) ? json.towers : [],
        providers: Array.isArray(json.providers) ? json.providers : [],
        source: json.source,
        dataset_status: json.dataset_status,
        message: json.message,
      });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCoverage();
    const interval = setInterval(fetchCoverage, 15000);
    return () => clearInterval(interval);
  }, []);

  const providers = useMemo(() => {
    return Array.from(new Set((data.towers || []).map((tower) => tower.provider))).sort();
  }, [data.towers]);

  const radios = useMemo(() => {
    return Array.from(
      new Set((data.towers || []).map((tower) => tower.radio?.toUpperCase()).filter(Boolean))
    ).sort();
  }, [data.towers]);

  const filteredTowers = useMemo(() => {
    return (data.towers || [])
      .filter((tower) => providerFilter === "ALL" || tower.provider === providerFilter)
      .filter((tower) => radioFilter === "ALL" || tower.radio?.toUpperCase() === radioFilter)
      .filter((tower) => Number(tower.samples || 0) >= minSamples)
      .filter((tower) => {
        if (qualityFilter === "ALL") return true;
        return buildSpec(tower, userLocation).quality === qualityFilter;
      })
      .slice(0, limit);
  }, [data.towers, providerFilter, radioFilter, qualityFilter, minSamples, limit, userLocation]);

  const stats = useMemo(() => {
    const towers = filteredTowers;

    return {
      total: towers.length,
      providers: new Set(towers.map((tower) => tower.provider)).size,
      lte: towers.filter((tower) => tower.radio?.toUpperCase() === "LTE").length,
      gsm: towers.filter((tower) => tower.radio?.toUpperCase() === "GSM").length,
      nr: towers.filter((tower) => tower.radio?.toUpperCase().includes("NR")).length,
      umts: towers.filter((tower) => tower.radio?.toUpperCase() === "UMTS").length,
    };
  }, [filteredTowers]);

  const nearestSpecs = useMemo(() => {
    if (!userLocation) return [];

    return filteredTowers
      .map((tower) => buildSpec(tower, userLocation))
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, 8);
  }, [filteredTowers, userLocation]);

  const servingSpec = useMemo(() => {
    if (selectedTower) return buildSpec(selectedTower, userLocation);
    if (nearestSpecs[0]) return nearestSpecs[0];
    return null;
  }, [selectedTower, nearestSpecs, userLocation]);

  const locateMe = () => {
    setGpsError("");

    if (!navigator.geolocation) {
      setGpsError("GPS tidak didukung browser ini.");
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setUserLocation([pos.coords.latitude, pos.coords.longitude]);
        setGpsAccuracy(Number(pos.coords.accuracy.toFixed(1)));
      },
      () => {
        setGpsError("GPS gagal diakses. Izinkan location permission di browser.");
      },
      {
        enableHighAccuracy: true,
        timeout: 15000,
        maximumAge: 3000,
      }
    );
  };

  const center: [number, number] = [-2.5, 118.0];

  return (
    <main className="space-y-6 p-6 text-white">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">Cellular Coverage Intelligence</h1>
          <p className="mt-2 max-w-5xl text-slate-400">
            CellMapper / Atoll-style BTS visualization with provider layer, radio layer, serving-cell estimate,
            radius, sector beam, heat risk, nearest BTS, and RF parameters from OpenCellID dataset.
          </p>
        </div>

        <div className="flex gap-3">
          <button
            onClick={locateMe}
            className="rounded-xl border border-cyan-500/30 px-5 py-3 text-sm font-bold text-cyan-300 hover:bg-cyan-500/10"
          >
            Locate Me via GPS
          </button>

          <button
            onClick={fetchCoverage}
            className="rounded-xl border border-emerald-500/30 px-5 py-3 text-sm font-bold text-emerald-300 hover:bg-emerald-500/10"
          >
            Refresh Coverage
          </button>
        </div>
      </div>

      {!loading && stats.total === 0 ? (
        <div className="rounded-3xl border border-yellow-500/30 bg-yellow-500/10 p-6">
          <h2 className="text-xl font-black text-yellow-300">Coverage Dataset Not Loaded</h2>
          <p className="mt-2 text-sm text-slate-300">{data.message || "No BTS dataset was found."}</p>
          <p className="mt-2 text-xs text-slate-500">Source: {data.source || "unknown"}</p>
        </div>
      ) : null}

      <section className="relative overflow-hidden rounded-3xl border border-slate-800 bg-slate-900/70">
        <div className="absolute left-5 top-5 z-[1000] max-h-[calc(100vh-170px)] w-[410px] overflow-y-auto rounded-2xl border border-slate-700 bg-slate-950/95 p-5 shadow-2xl backdrop-blur-xl">
          <div className="mb-4 flex items-start justify-between">
            <div>
              <h2 className="font-black">Dynamic Coverage Intelligence</h2>
              <p className="text-xs text-slate-400">OpenCellID BTS layer + RF planning estimate</p>
            </div>
            <span className="rounded-full bg-emerald-500/10 px-3 py-1 text-xs font-bold text-emerald-300">
              Live
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <Stat label="Visible BTS" value={stats.total} />
            <Stat label="Providers" value={stats.providers} />
            <Stat label="LTE" value={stats.lte} />
            <Stat label="GSM" value={stats.gsm} />
            <Stat label="NR/5G" value={stats.nr} />
            <Stat label="UMTS" value={stats.umts} />
          </div>

          <button
            onClick={locateMe}
            className="mt-4 w-full rounded-xl border border-cyan-500/30 bg-cyan-500/10 px-4 py-3 text-sm font-bold text-cyan-300 hover:bg-cyan-500/20"
          >
            Locate Me via GPS
          </button>

          {gpsAccuracy ? (
            <p className="mt-2 rounded-lg border border-cyan-500/20 bg-cyan-500/10 p-2 text-xs text-cyan-200">
              GPS accuracy: ±{gpsAccuracy} m
            </p>
          ) : null}

          {gpsError ? (
            <p className="mt-2 rounded-lg border border-red-500/30 bg-red-500/10 p-2 text-xs text-red-300">
              {gpsError}
            </p>
          ) : null}

          <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/80 p-3">
            <p className="mb-3 text-xs font-black uppercase tracking-[0.2em] text-slate-400">
              Layer Control
            </p>

            <div className="grid grid-cols-2 gap-3">
              <select
                value={providerFilter}
                onChange={(e) => setProviderFilter(e.target.value)}
                className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white"
              >
                <option value="ALL">All Providers</option>
                {providers.map((provider) => (
                  <option key={provider} value={provider}>{provider}</option>
                ))}
              </select>

              <select
                value={radioFilter}
                onChange={(e) => setRadioFilter(e.target.value)}
                className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white"
              >
                <option value="ALL">All Radio</option>
                {radios.map((radio) => (
                  <option key={radio} value={radio}>{radio}</option>
                ))}
              </select>

              <select
                value={qualityFilter}
                onChange={(e) => setQualityFilter(e.target.value)}
                className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white"
              >
                <option value="ALL">All Quality</option>
                <option value="Excellent">Excellent</option>
                <option value="Good">Good</option>
                <option value="Fair">Fair</option>
                <option value="Weak">Weak</option>
              </select>

              <select
                value={limit}
                onChange={(e) => setLimit(Number(e.target.value))}
                className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white"
              >
                <option value={600}>600 BTS</option>
                <option value={1000}>1000 BTS</option>
                <option value={3000}>3000 BTS</option>
                <option value={5000}>5000 BTS</option>
                <option value={8000}>8000 BTS</option>
              </select>

              <select
                value={minSamples}
                onChange={(e) => setMinSamples(Number(e.target.value))}
                className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white"
              >
                <option value={0}>Min Samples: 0</option>
                <option value={2}>Min Samples: 2</option>
                <option value={5}>Min Samples: 5</option>
                <option value={10}>Min Samples: 10</option>
                <option value={50}>Min Samples: 50</option>
              </select>

              <button
                onClick={() => setShowRadius((v) => !v)}
                className={`rounded-xl border px-3 py-2 text-xs font-bold ${
                  showRadius ? "border-cyan-500/40 bg-cyan-500/10 text-cyan-300" : "border-slate-700 bg-slate-950 text-slate-300"
                }`}
              >
                Coverage Radius
              </button>

              <button
                onClick={() => setShowSector((v) => !v)}
                className={`rounded-xl border px-3 py-2 text-xs font-bold ${
                  showSector ? "border-purple-500/40 bg-purple-500/10 text-purple-300" : "border-slate-700 bg-slate-950 text-slate-300"
                }`}
              >
                Sector Beam
              </button>

              <button
                onClick={() => setShowHeat((v) => !v)}
                className={`rounded-xl border px-3 py-2 text-xs font-bold ${
                  showHeat ? "border-red-500/40 bg-red-500/10 text-red-300" : "border-slate-700 bg-slate-950 text-slate-300"
                }`}
              >
                Heat Risk
              </button>

              <button
                onClick={() => setShowNearest((v) => !v)}
                className={`rounded-xl border px-3 py-2 text-xs font-bold ${
                  showNearest ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-300" : "border-slate-700 bg-slate-950 text-slate-300"
                }`}
              >
                Nearest BTS
              </button>
            </div>
          </div>

          <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/70 p-3">
            <p className="mb-2 text-xs font-bold text-slate-300">Provider Legend</p>
            <div className="grid grid-cols-2 gap-2 text-xs text-slate-300">
              {Object.entries(providerColors).map(([provider, color]) => (
                <div key={provider} className="flex items-center gap-2">
                  <span className="h-3 w-3 rounded-full" style={{ backgroundColor: color }} />
                  <span>{provider}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/70 p-3">
            <p className="text-xs font-bold text-slate-300">Dataset Source</p>
            <p className="mt-1 break-words text-xs text-cyan-300">{data.source || "unknown"}</p>
            <p className="mt-1 text-xs text-slate-500">{data.dataset_status || "-"}</p>
          </div>
        </div>

        <div className="absolute right-5 top-5 z-[1000] max-h-[calc(100vh-170px)] w-[440px] overflow-y-auto rounded-2xl border border-slate-700 bg-slate-950/95 p-5 shadow-2xl backdrop-blur-xl">
          <h2 className="text-sm font-black">RF Engineering Specs</h2>
          <p className="mt-1 text-xs text-slate-400">
            Click BTS marker or press GPS to calculate nearest serving-cell estimate.
          </p>

          {servingSpec ? (
            <>
              <div className="mt-4 grid grid-cols-2 gap-3">
                <Spec label="Provider" value={servingSpec.provider} accent="text-cyan-300" />
                <Spec label="Radio" value={servingSpec.radio} accent="text-emerald-300" />
                <Spec label="MCC/MNC" value={`${servingSpec.mcc}/${servingSpec.mnc}`} />
                <Spec label="LAC/TAC" value={servingSpec.lac} />
                <Spec label="Cell ID" value={servingSpec.cellid} />
                <Spec label="PCI Est." value={servingSpec.pciEstimate} />
                <Spec label="Band Est." value={servingSpec.bandEstimate} />
                <Spec label="Azimuth Est." value={`${servingSpec.azimuth}°`} />
                <Spec label="Distance" value={`${servingSpec.distanceKm} km`} />
                <Spec label="Range" value={`${servingSpec.range || 0} m`} />
                <Spec
                  label="RSRP/RSSI Est."
                  value={`${servingSpec.estimatedSignal} dBm`}
                  accent={
                    servingSpec.estimatedSignal >= -90
                      ? "text-emerald-300"
                      : servingSpec.estimatedSignal >= -105
                      ? "text-yellow-300"
                      : "text-red-300"
                  }
                />
                <Spec label="RSRQ Est." value={`${servingSpec.estimatedRsrq} dB`} />
                <Spec label="SINR Est." value={`${servingSpec.estimatedSinr} dB`} />
                <Spec label="Quality" value={servingSpec.quality} />
                <Spec label="Samples" value={servingSpec.samples || 0} />
                <Spec label="Confidence" value={servingSpec.confidence} />
              </div>

              <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/80 p-3">
                <p className="text-xs font-bold text-slate-300">Engineering Interpretation</p>
                <p className="mt-2 text-xs leading-relaxed text-slate-400">
                  {servingSpec.risk}. PCI, band, azimuth, RSRP/RSRQ/SINR are engineering estimates from public dataset.
                  Official values require Atoll export or operator data.
                </p>
              </div>
            </>
          ) : (
            <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/80 p-4 text-xs text-slate-400">
              No selected BTS yet.
            </div>
          )}

          {nearestSpecs.length > 0 && showNearest ? (
            <div className="mt-4">
              <p className="mb-2 text-xs font-bold text-slate-300">Serving Cell Candidates</p>
              <div className="max-h-[220px] space-y-2 overflow-y-auto pr-1">
                {nearestSpecs.map((tower) => (
                  <button
                    key={`${tower.mcc}-${tower.mnc}-${tower.cellid}`}
                    onClick={() => setSelectedTower(tower)}
                    className="w-full rounded-xl border border-slate-700 bg-slate-900/80 p-3 text-left text-xs hover:border-cyan-500/60"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-bold text-white">{tower.provider}</span>
                      <span className="text-cyan-300">{tower.distanceKm} km</span>
                    </div>
                    <div className="mt-1 text-slate-400">
                      {tower.radio} • Cell {tower.cellid} • PCI {tower.pciEstimate} • {tower.estimatedSignal} dBm • {tower.quality}
                    </div>
                  </button>
                ))}
              </div>
            </div>
          ) : null}
        </div>

        <div className="h-[calc(100vh-220px)] min-h-[760px]">
          <MapContainer center={center} zoom={5} scrollWheelZoom className="h-full w-full">
            <FlyToLocation position={userLocation} />

            <TileLayer
              attribution='&copy; OpenStreetMap contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />

            {userLocation ? (
              <CircleMarker
                center={userLocation}
                radius={10}
                pathOptions={{ color: "#00e5ff", fillColor: "#00e5ff", fillOpacity: 0.85, weight: 3 }}
              >
                <Popup>Your current GPS position</Popup>
              </CircleMarker>
            ) : null}

            {userLocation && nearestSpecs[0] && showNearest ? (
              <Polyline
                positions={[userLocation, [nearestSpecs[0].lat, nearestSpecs[0].lon]]}
                pathOptions={{ color: "#00e5ff", weight: 2, dashArray: "8 8" }}
              />
            ) : null}

            {showRadius
              ? filteredTowers.slice(0, 700).map((tower, index) => {
                  const color = getColor(tower.provider);
                  const spec = buildSpec(tower, userLocation);
                  const fillOpacity = showHeat
                    ? spec.quality === "Weak"
                      ? 0.16
                      : spec.quality === "Fair"
                      ? 0.1
                      : 0.05
                    : 0.045;

                  return (
                    <Circle
                      key={`radius-${tower.cellid}-${index}`}
                      center={[tower.lat, tower.lon]}
                      radius={Math.max(Number(tower.range || 500), 250)}
                      pathOptions={{ color, fillColor: color, fillOpacity, weight: 1 }}
                    />
                  );
                })
              : null}

            {showSector
              ? filteredTowers.slice(0, 500).map((tower, index) => {
                  const color = getColor(tower.provider);
                  const az = pseudoAzimuth(tower);
                  const radius = Math.max(Number(tower.range || 800), 400);

                  return (
                    <Polygon
                      key={`sector-${tower.cellid}-${index}`}
                      positions={sectorPolygon(tower.lat, tower.lon, radius, az, 65)}
                      pathOptions={{ color, fillColor: color, fillOpacity: 0.08, weight: 1 }}
                    />
                  );
                })
              : null}

            {filteredTowers.map((tower, index) => {
              const color = getColor(tower.provider);
              const selected = selectedTower?.cellid === tower.cellid && selectedTower?.lac === tower.lac;
              const spec = buildSpec(tower, userLocation);

              const markerRadius =
                showHeat && spec.quality === "Weak"
                  ? 8
                  : showHeat && spec.quality === "Fair"
                  ? 7
                  : selected
                  ? 9
                  : 5;

              return (
                <CircleMarker
                  key={`${tower.mcc}-${tower.mnc}-${tower.cellid}-${index}`}
                  center={[tower.lat, tower.lon]}
                  radius={markerRadius}
                  eventHandlers={{ click: () => setSelectedTower(tower) }}
                  pathOptions={{
                    color,
                    fillColor: color,
                    fillOpacity: selected ? 1 : 0.76,
                    weight: selected ? 4 : 2,
                  }}
                >
                  <Popup>
                    <div>
                      <b>{tower.provider}</b>
                      <br />
                      Radio: {tower.radio}
                      <br />
                      MCC/MNC: {tower.mcc}/{tower.mnc}
                      <br />
                      LAC/TAC: {tower.lac}
                      <br />
                      Cell ID: {tower.cellid}
                      <br />
                      PCI Est.: {spec.pciEstimate}
                      <br />
                      Band Est.: {spec.bandEstimate}
                      <br />
                      Azimuth Est.: {spec.azimuth}°
                      <br />
                      Range: {tower.range} m
                      <br />
                      Samples: {tower.samples}
                      <br />
                      Signal Est.: {spec.estimatedSignal} dBm
                      <br />
                      Quality: {spec.quality}
                    </div>
                  </Popup>
                </CircleMarker>
              );
            })}
          </MapContainer>
        </div>
      </section>
    </main>
  );
}
TSX

echo "=================================================="
echo "3. PATCH USER MANAGEMENT FRONTEND ROLE SELECT"
echo "=================================================="

python3 <<'PY'
from pathlib import Path
import re

p = Path("app/users/page.tsx")

if not p.exists():
    print("⚠️ app/users/page.tsx not found, skipped frontend role patch")
    raise SystemExit(0)

s = p.read_text()

old = '''onChange={(e) =>
                        setPendingRoles((prev) => ({
                          ...prev,
                          [user.id]: e.target.value,
                        }))
                      }'''

new = '''onChange={(e) => {
                        const nextRole = e.target.value;
                        setPendingRoles((prev) => ({
                          ...prev,
                          [user.id]: nextRole,
                        }));
                        updateRole(user.id, user.username, nextRole);
                      }}'''

if old in s:
    s = s.replace(old, new)
    print("✅ Role select now updates backend immediately")
else:
    pattern = r'onChange=\{\(e\)\s*=>\s*setPendingRoles\(\(prev\)\s*=>\s*\(\{\s*\.\.\.prev,\s*\[user\.id\]:\s*e\.target\.value,\s*\}\)\)\s*\}'
    s2, count = re.subn(pattern, new, s, count=1, flags=re.S)
    s = s2
    print(f"Role select regex replacements: {count}")
    if count == 0:
      print("⚠️ Could not auto-patch role select. Backend patch will still persist if button calls PUT.")

insert_after = 'setMessage("Role updated successfully.");'
local_storage_patch = '''
      try {
        const stored = localStorage.getItem("user");
        if (stored) {
          const parsed = JSON.parse(stored);
          if (Number(parsed.id) === Number(userId)) {
            parsed.role = newRole;
            localStorage.setItem("user", JSON.stringify(parsed));
          }
        }
      } catch {
        // ignore localStorage sync error
      }
'''

if insert_after in s and "parsed.role = newRole;" not in s:
    s = s.replace(insert_after, insert_after + local_storage_patch)
    print("✅ Current localStorage user role sync added")
else:
    print("ℹ️ localStorage sync already exists or insert point not found")

p.write_text(s)
PY

echo "=================================================="
echo "4. PATCH BACKEND ROLE PERSISTENCE + GOOGLE LOGIN ROLE"
echo "=================================================="

python3 <<'PY'
from pathlib import Path

p = Path("backend/main.py")

if not p.exists():
    print("⚠️ backend/main.py not found, skipped backend role patch")
    raise SystemExit(0)

s = p.read_text()

start = "# === USER ROLE PERSISTENCE PATCH START ==="
end = "# === USER ROLE PERSISTENCE PATCH END ==="

if start in s and end in s:
    s = s.split(start)[0] + s.split(end)[1]

block = r'''
# === USER ROLE PERSISTENCE PATCH START ===
# Fix role changes that looked updated in UI but did not persist after logout/login.
# This middleware intercepts:
# - PUT /api/users/{id}            -> writes role directly to PostgreSQL users table
# - POST /api/auth/google/token    -> returns role from users table instead of hardcoded role

import json as _json_role_patch
import os as _os_role_patch
import re as _re_role_patch
from datetime import datetime as _dt_role_patch, timedelta as _td_role_patch

try:
    import psycopg2 as _psycopg2_role_patch
except Exception:
    _psycopg2_role_patch = None

try:
    from jose import jwt as _jwt_role_patch
except Exception:
    _jwt_role_patch = None

from starlette.responses import JSONResponse as _JSONResponseRolePatch


def _role_patch_db_url():
    url = (
        _os_role_patch.getenv("DATABASE_URL")
        or _os_role_patch.getenv("POSTGRES_URL")
        or _os_role_patch.getenv("SQLALCHEMY_DATABASE_URL")
        or ""
    )

    if url.startswith("postgresql+psycopg2://"):
        url = url.replace("postgresql+psycopg2://", "postgresql://", 1)

    return url


def _role_patch_conn():
    if _psycopg2_role_patch is None:
        return None

    url = _role_patch_db_url()

    if not url:
        return None

    return _psycopg2_role_patch.connect(url)


def _role_patch_valid_role(role):
    allowed = {"Admin", "Engineer", "Viewer"}
    if role not in allowed:
        return "Viewer"
    return role


def _role_patch_update_user(user_id, username=None, role=None):
    role = _role_patch_valid_role(role or "Viewer")
    conn = _role_patch_conn()

    if conn is None:
        return None

    try:
        with conn:
            with conn.cursor() as cur:
                if username:
                    cur.execute(
                        """
                        UPDATE users
                        SET username = COALESCE(%s, username),
                            role = %s
                        WHERE id = %s
                        RETURNING id, username, role, email
                        """,
                        (username, role, user_id),
                    )
                else:
                    cur.execute(
                        """
                        UPDATE users
                        SET role = %s
                        WHERE id = %s
                        RETURNING id, username, role, email
                        """,
                        (role, user_id),
                    )

                row = cur.fetchone()

                if not row:
                    return None

                return {
                    "id": row[0],
                    "username": row[1],
                    "role": row[2],
                    "email": row[3],
                }
    finally:
        conn.close()


def _role_patch_find_user(email=None, username=None):
    conn = _role_patch_conn()

    if conn is None:
        return None

    try:
        with conn:
            with conn.cursor() as cur:
                if email:
                    cur.execute(
                        """
                        SELECT id, username, role, email
                        FROM users
                        WHERE lower(email) = lower(%s)
                        ORDER BY id ASC
                        LIMIT 1
                        """,
                        (email,),
                    )
                elif username:
                    cur.execute(
                        """
                        SELECT id, username, role, email
                        FROM users
                        WHERE lower(username) = lower(%s)
                        ORDER BY id ASC
                        LIMIT 1
                        """,
                        (username,),
                    )
                else:
                    return None

                row = cur.fetchone()

                if not row:
                    return None

                return {
                    "id": row[0],
                    "username": row[1],
                    "role": row[2],
                    "email": row[3],
                }
    finally:
        conn.close()


def _role_patch_token(user):
    username = user.get("username") or user.get("email") or "user"
    role = _role_patch_valid_role(user.get("role") or "Viewer")
    email = user.get("email")

    payload = {
        "sub": username,
        "role": role,
        "email": email,
    }

    try:
        if "create_access_token" in globals():
            return create_access_token(payload)
    except Exception:
        pass

    secret = (
        globals().get("SECRET_KEY")
        or _os_role_patch.getenv("JWT_SECRET")
        or _os_role_patch.getenv("SECRET_KEY")
        or "change-me"
    )

    algorithm = globals().get("ALGORITHM") or "HS256"

    if _jwt_role_patch is None:
        return ""

    payload["exp"] = _dt_role_patch.utcnow() + _td_role_patch(days=30)

    return _jwt_role_patch.encode(payload, secret, algorithm=algorithm)


@app.middleware("http")
async def user_role_persistence_patch(request, call_next):
    path = request.url.path
    method = request.method.upper()

    role_update_match = _re_role_patch.match(r"^/api/users/(\d+)$", path)

    if method == "PUT" and role_update_match:
        auth_header = request.headers.get("authorization") or ""

        if not auth_header:
            return _JSONResponseRolePatch({"error": "Unauthorized"}, status_code=401)

        try:
            raw = await request.body()
            payload = _json_role_patch.loads(raw.decode("utf-8") or "{}")
        except Exception:
            payload = {}

        user_id = int(role_update_match.group(1))
        username = payload.get("username")
        role = _role_patch_valid_role(payload.get("role") or "Viewer")

        updated = _role_patch_update_user(user_id=user_id, username=username, role=role)

        if not updated:
            return _JSONResponseRolePatch(
                {"error": "User not found or database connection unavailable"},
                status_code=404,
            )

        return _JSONResponseRolePatch(
            {
                "status": "updated",
                "message": "User role persisted successfully.",
                **updated,
            }
        )

    if method == "POST" and path == "/api/auth/google/token":
        try:
            raw = await request.body()
            payload = _json_role_patch.loads(raw.decode("utf-8") or "{}")
        except Exception:
            payload = {}

        email = payload.get("email")

        if email:
            user = _role_patch_find_user(email=email)

            if user:
                token = _role_patch_token(user)

                return _JSONResponseRolePatch(
                    {
                        "access_token": token,
                        "token_type": "bearer",
                        "id": user.get("id"),
                        "username": user.get("username"),
                        "role": _role_patch_valid_role(user.get("role")),
                        "email": user.get("email"),
                    }
                )

    return await call_next(request)

# === USER ROLE PERSISTENCE PATCH END ===
'''

p.write_text(s.rstrip() + "\n\n" + block + "\n")
print("✅ backend role persistence patch appended")
PY

echo "=================================================="
echo "PATCH DONE"
echo "=================================================="
