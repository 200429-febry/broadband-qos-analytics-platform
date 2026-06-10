#!/bin/bash
set -e

echo "=================================================="
echo "FIX COVERAGE MAP: CLICKABLE BTS + GPS PRECISION + HEX + GOOGLE MAPS"
echo "=================================================="

mkdir -p .backup-coverage-v4
[ -f app/coverage/page.tsx ] && cp app/coverage/page.tsx .backup-coverage-v4/app_coverage_page.tsx.bak
[ -f components/coverage-map-client.tsx ] && cp components/coverage-map-client.tsx .backup-coverage-v4/components_coverage_map_client.tsx.bak

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

import { useEffect, useMemo, useRef, useState } from "react";
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

function getHeatColor(quality: string) {
  if (quality === "Excellent") return "#22c55e";
  if (quality === "Good") return "#84cc16";
  if (quality === "Fair") return "#facc15";
  return "#ef4444";
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

  for (let b = start; b <= end; b += 7) {
    points.push(destinationPoint(lat, lon, b, radiusM));
  }

  points.push(destinationPoint(lat, lon, end, radiusM));
  points.push([lat, lon]);
  return points;
}

function hexagonPolygon(lat: number, lon: number, radiusM: number) {
  const points: [number, number][] = [];
  for (let i = 0; i < 6; i++) {
    points.push(destinationPoint(lat, lon, i * 60 + 30, radiusM));
  }
  return points;
}

function pseudoAzimuth(tower: Tower) {
  return Math.abs((Number(tower.cellid || 0) * 37 + Number(tower.lac || 0) * 11) % 360);
}

function estimateSignal(baseSignal: number, distanceKm: number, rangeMeter: number) {
  const cleanBase = Number.isFinite(baseSignal) && baseSignal !== 0 ? baseSignal : -90;
  const rangeKm = Math.max(rangeMeter / 1000, 0.5);
  const distanceRatio = Math.min(distanceKm / rangeKm, 3);
  const penalty = distanceKm > 0 ? 6 + distanceRatio * 14 : 0;
  return Math.round(cleanBase - penalty);
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

  if (radio?.includes("NR")) return "NR n78/n40 estimate";
  if (radio === "LTE") {
    if (mnc === 10) return "LTE B3/B8/B40 estimate";
    if (mnc === 11) return "LTE B1/B3/B8 estimate";
    if (mnc === 21 || mnc === 1) return "LTE B1/B3/B8 estimate";
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

  const signal = estimateSignal(
    Number(tower.average_signal || -90),
    distanceKm,
    Number(tower.range || 1000)
  );

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

function openGoogleMaps(lat: number, lon: number) {
  window.open(`https://www.google.com/maps/search/?api=1&query=${lat},${lon}`, "_blank");
}

function openGoogleMapsDirection(lat: number, lon: number) {
  window.open(`https://www.google.com/maps/dir/?api=1&destination=${lat},${lon}`, "_blank");
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

function LeafletPaneSetup() {
  const map = useMap();

  useEffect(() => {
    const makePane = (name: string, zIndex: string, pointerEvents: string) => {
      if (!map.getPane(name)) {
        map.createPane(name);
      }
      const pane = map.getPane(name);
      if (pane) {
        pane.style.zIndex = zIndex;
        pane.style.pointerEvents = pointerEvents;
      }
    };

    makePane("coverage-hex", "350", "none");
    makePane("coverage-radius", "360", "none");
    makePane("coverage-sector", "370", "none");
    makePane("coverage-link", "390", "none");
  }, [map]);

  return null;
}

function MapController({
  userLocation,
  selectedTower,
  focusSignal,
}: {
  userLocation: [number, number] | null;
  selectedTower: Tower | null;
  focusSignal: number;
}) {
  const map = useMap();

  useEffect(() => {
    if (selectedTower) {
      map.flyTo([selectedTower.lat, selectedTower.lon], 17, { duration: 1.1 });
      return;
    }

    if (userLocation) {
      map.flyTo(userLocation, 17, { duration: 1.1 });
    }
  }, [map, userLocation, selectedTower, focusSignal]);

  return null;
}

export function CoverageMapClient() {
  const [data, setData] = useState<CoverageResponse>({ count: 0, towers: [], providers: [] });
  const [providerFilter, setProviderFilter] = useState("ALL");
  const [radioFilter, setRadioFilter] = useState("ALL");
  const [qualityFilter, setQualityFilter] = useState("ALL");
  const [minSamples, setMinSamples] = useState(0);
  const [limit, setLimit] = useState(8000);
  const [showRadius, setShowRadius] = useState(true);
  const [showSector, setShowSector] = useState(false);
  const [showHex, setShowHex] = useState(true);
  const [showHeat, setShowHeat] = useState(false);
  const [showNearest, setShowNearest] = useState(true);
  const [userLocation, setUserLocation] = useState<[number, number] | null>(null);
  const [gpsAccuracy, setGpsAccuracy] = useState<number | null>(null);
  const [selectedTower, setSelectedTower] = useState<Tower | null>(null);
  const [loading, setLoading] = useState(true);
  const [gpsError, setGpsError] = useState("");
  const [focusSignal, setFocusSignal] = useState(0);
  const watchIdRef = useRef<number | null>(null);

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

    return () => {
      clearInterval(interval);
      if (watchIdRef.current !== null && navigator.geolocation) {
        navigator.geolocation.clearWatch(watchIdRef.current);
      }
    };
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
      .slice(0, 10);
  }, [filteredTowers, userLocation]);

  const selectedSpec = useMemo(() => {
    if (!selectedTower) return null;
    return buildSpec(selectedTower, userLocation);
  }, [selectedTower, userLocation]);

  const locateMe = () => {
    setGpsError("");
    setSelectedTower(null);

    if (!navigator.geolocation) {
      setGpsError("GPS tidak didukung browser ini.");
      return;
    }

    const options = {
      enableHighAccuracy: true,
      timeout: 20000,
      maximumAge: 0,
    };

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setUserLocation([pos.coords.latitude, pos.coords.longitude]);
        setGpsAccuracy(Number(pos.coords.accuracy.toFixed(1)));
        setFocusSignal((v) => v + 1);
      },
      () => {
        setGpsError("GPS gagal diakses. Izinkan location permission di browser.");
      },
      options
    );

    if (watchIdRef.current !== null) {
      navigator.geolocation.clearWatch(watchIdRef.current);
    }

    watchIdRef.current = navigator.geolocation.watchPosition(
      (pos) => {
        setUserLocation([pos.coords.latitude, pos.coords.longitude]);
        setGpsAccuracy(Number(pos.coords.accuracy.toFixed(1)));
      },
      () => {},
      options
    );
  };

  const center: [number, number] = [-2.5, 118.0];

  return (
    <main className="space-y-6 p-6 text-white">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">Cellular Coverage Intelligence</h1>
          <p className="mt-2 max-w-5xl text-slate-400">
            CellMapper / Atoll-style BTS map with clickable BTS markers, provider color, RF estimates,
            GPS precision, Google Maps link, coverage radius, sector beam, hexagon layer, heat risk, and nearest cell candidates.
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
        <div className="absolute left-5 top-5 z-[1000] max-h-[calc(100vh-170px)] w-[420px] overflow-y-auto rounded-2xl border border-slate-700 bg-slate-950/95 p-5 shadow-2xl backdrop-blur-xl">
          <div className="mb-4 flex items-start justify-between">
            <div>
              <h2 className="font-black">Dynamic Coverage Intelligence</h2>
              <p className="text-xs text-slate-400">Clickable BTS layer + RF planning estimate</p>
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
              GPS precision: ±{gpsAccuracy} m • map zooms to level 17
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
              <select value={providerFilter} onChange={(e) => setProviderFilter(e.target.value)} className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white">
                <option value="ALL">All Providers</option>
                {providers.map((provider) => <option key={provider} value={provider}>{provider}</option>)}
              </select>

              <select value={radioFilter} onChange={(e) => setRadioFilter(e.target.value)} className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white">
                <option value="ALL">All Radio</option>
                {radios.map((radio) => <option key={radio} value={radio}>{radio}</option>)}
              </select>

              <select value={qualityFilter} onChange={(e) => setQualityFilter(e.target.value)} className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white">
                <option value="ALL">All Quality</option>
                <option value="Excellent">Excellent</option>
                <option value="Good">Good</option>
                <option value="Fair">Fair</option>
                <option value="Weak">Weak</option>
              </select>

              <select value={limit} onChange={(e) => setLimit(Number(e.target.value))} className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white">
                <option value={600}>600 BTS</option>
                <option value={1000}>1000 BTS</option>
                <option value={3000}>3000 BTS</option>
                <option value={5000}>5000 BTS</option>
                <option value={8000}>8000 BTS</option>
              </select>

              <select value={minSamples} onChange={(e) => setMinSamples(Number(e.target.value))} className="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-white">
                <option value={0}>Min Samples: 0</option>
                <option value={2}>Min Samples: 2</option>
                <option value={5}>Min Samples: 5</option>
                <option value={10}>Min Samples: 10</option>
                <option value={50}>Min Samples: 50</option>
              </select>

              <button onClick={() => setShowRadius((v) => !v)} className={`rounded-xl border px-3 py-2 text-xs font-bold ${showRadius ? "border-cyan-500/40 bg-cyan-500/10 text-cyan-300" : "border-slate-700 bg-slate-950 text-slate-300"}`}>
                Radius
              </button>

              <button onClick={() => setShowSector((v) => !v)} className={`rounded-xl border px-3 py-2 text-xs font-bold ${showSector ? "border-purple-500/40 bg-purple-500/10 text-purple-300" : "border-slate-700 bg-slate-950 text-slate-300"}`}>
                Sector Beam
              </button>

              <button onClick={() => setShowHex((v) => !v)} className={`rounded-xl border px-3 py-2 text-xs font-bold ${showHex ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-300" : "border-slate-700 bg-slate-950 text-slate-300"}`}>
                Hexagon
              </button>

              <button onClick={() => setShowHeat((v) => !v)} className={`rounded-xl border px-3 py-2 text-xs font-bold ${showHeat ? "border-red-500/40 bg-red-500/10 text-red-300" : "border-slate-700 bg-slate-950 text-slate-300"}`}>
                Heat Risk
              </button>

              <button onClick={() => setShowNearest((v) => !v)} className={`rounded-xl border px-3 py-2 text-xs font-bold ${showNearest ? "border-yellow-500/40 bg-yellow-500/10 text-yellow-300" : "border-slate-700 bg-slate-950 text-slate-300"}`}>
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
            Klik BTS marker merah/biru/kuning/hijau di peta untuk membuka detail dan Google Maps.
          </p>

          {selectedSpec ? (
            <>
              <div className="mt-4 grid grid-cols-2 gap-3">
                <Spec label="Provider" value={selectedSpec.provider} accent="text-cyan-300" />
                <Spec label="Radio" value={selectedSpec.radio} accent="text-emerald-300" />
                <Spec label="MCC/MNC" value={`${selectedSpec.mcc}/${selectedSpec.mnc}`} />
                <Spec label="LAC/TAC" value={selectedSpec.lac} />
                <Spec label="Cell ID" value={selectedSpec.cellid} />
                <Spec label="PCI Est." value={selectedSpec.pciEstimate} />
                <Spec label="Band Est." value={selectedSpec.bandEstimate} />
                <Spec label="Azimuth Est." value={`${selectedSpec.azimuth}°`} />
                <Spec label="Distance" value={userLocation ? `${selectedSpec.distanceKm} km` : "GPS needed"} />
                <Spec label="Range" value={`${selectedSpec.range || 0} m`} />
                <Spec
                  label="RSRP/RSSI Est."
                  value={`${selectedSpec.estimatedSignal} dBm`}
                  accent={selectedSpec.estimatedSignal >= -90 ? "text-emerald-300" : selectedSpec.estimatedSignal >= -105 ? "text-yellow-300" : "text-red-300"}
                />
                <Spec label="RSRQ Est." value={`${selectedSpec.estimatedRsrq} dB`} />
                <Spec label="SINR Est." value={`${selectedSpec.estimatedSinr} dB`} />
                <Spec label="Quality" value={selectedSpec.quality} />
                <Spec label="Samples" value={selectedSpec.samples || 0} />
                <Spec label="Confidence" value={selectedSpec.confidence} />
              </div>

              <div className="mt-4 grid grid-cols-2 gap-3">
                <button
                  onClick={() => openGoogleMaps(selectedSpec.lat, selectedSpec.lon)}
                  className="rounded-xl border border-cyan-500/30 bg-cyan-500/10 px-4 py-3 text-xs font-bold text-cyan-300 hover:bg-cyan-500/20"
                >
                  Open Google Maps
                </button>

                <button
                  onClick={() => openGoogleMapsDirection(selectedSpec.lat, selectedSpec.lon)}
                  className="rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-4 py-3 text-xs font-bold text-emerald-300 hover:bg-emerald-500/20"
                >
                  Direction
                </button>
              </div>

              <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/80 p-3">
                <p className="text-xs font-bold text-slate-300">Engineering Interpretation</p>
                <p className="mt-2 text-xs leading-relaxed text-slate-400">
                  {selectedSpec.risk}. PCI, band, azimuth, RSRP/RSRQ/SINR are engineering estimates from public dataset.
                  Official values require Atoll export or operator data.
                </p>
              </div>
            </>
          ) : (
            <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/80 p-4 text-xs text-slate-400">
              Belum ada BTS yang dipilih. Klik marker BTS di peta. Panel ini tidak akan otomatis memilih XL/Telkomsel sebelum kamu klik marker.
            </div>
          )}

          {nearestSpecs.length > 0 && showNearest ? (
            <div className="mt-4">
              <p className="mb-2 text-xs font-bold text-slate-300">Nearest BTS Candidates</p>
              <div className="max-h-[260px] space-y-2 overflow-y-auto pr-1">
                {nearestSpecs.map((tower) => (
                  <button
                    key={`${tower.mcc}-${tower.mnc}-${tower.lac}-${tower.cellid}`}
                    onClick={() => {
                      setSelectedTower(tower);
                      setFocusSignal((v) => v + 1);
                    }}
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
            <LeafletPaneSetup />
            <MapController userLocation={userLocation} selectedTower={selectedTower} focusSignal={focusSignal} />

            <TileLayer
              attribution='&copy; OpenStreetMap contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />

            {userLocation ? (
              <>
                <Circle
                  center={userLocation}
                  radius={gpsAccuracy || 25}
                  interactive={false}
                  pathOptions={{
                    color: "#00e5ff",
                    fillColor: "#00e5ff",
                    fillOpacity: 0.12,
                    weight: 1,
                    pane: "coverage-link",
                  }}
                />

                <CircleMarker
                  center={userLocation}
                  radius={10}
                  pathOptions={{
                    color: "#00e5ff",
                    fillColor: "#00e5ff",
                    fillOpacity: 0.9,
                    weight: 3,
                  }}
                >
                  <Popup>
                    <div>
                      <b>Your GPS Position</b>
                      <br />
                      Accuracy: ±{gpsAccuracy || "-"} m
                      <br />
                      Lat: {userLocation[0]}
                      <br />
                      Lon: {userLocation[1]}
                    </div>
                  </Popup>
                </CircleMarker>
              </>
            ) : null}

            {userLocation && selectedSpec ? (
              <Polyline
                interactive={false}
                positions={[userLocation, [selectedSpec.lat, selectedSpec.lon]]}
                pathOptions={{
                  color: "#00e5ff",
                  weight: 3,
                  dashArray: "8 8",
                  pane: "coverage-link",
                }}
              />
            ) : null}

            {showHex
              ? filteredTowers.slice(0, 1200).map((tower, index) => {
                  const spec = buildSpec(tower, userLocation);
                  const color = showHeat ? getHeatColor(spec.quality) : getColor(tower.provider);
                  const r = Math.max(Math.min(Number(tower.range || 600), 2500), 250);

                  return (
                    <Polygon
                      key={`hex-${tower.lac}-${tower.cellid}-${index}`}
                      positions={hexagonPolygon(tower.lat, tower.lon, r)}
                      interactive={false}
                      pathOptions={{
                        color,
                        fillColor: color,
                        fillOpacity: showHeat ? 0.13 : 0.06,
                        weight: 1,
                        pane: "coverage-hex",
                      }}
                    />
                  );
                })
              : null}

            {showRadius
              ? filteredTowers.slice(0, 1200).map((tower, index) => {
                  const spec = buildSpec(tower, userLocation);
                  const color = showHeat ? getHeatColor(spec.quality) : getColor(tower.provider);

                  return (
                    <Circle
                      key={`radius-${tower.lac}-${tower.cellid}-${index}`}
                      center={[tower.lat, tower.lon]}
                      radius={Math.max(Number(tower.range || 500), 250)}
                      interactive={false}
                      pathOptions={{
                        color,
                        fillColor: color,
                        fillOpacity: showHeat ? 0.12 : 0.04,
                        weight: 1,
                        pane: "coverage-radius",
                      }}
                    />
                  );
                })
              : null}

            {showSector
              ? filteredTowers.slice(0, 900).map((tower, index) => {
                  const spec = buildSpec(tower, userLocation);
                  const color = showHeat ? getHeatColor(spec.quality) : getColor(tower.provider);
                  const az = pseudoAzimuth(tower);
                  const radius = Math.max(Number(tower.range || 800), 400);

                  return (
                    <Polygon
                      key={`sector-${tower.lac}-${tower.cellid}-${index}`}
                      positions={sectorPolygon(tower.lat, tower.lon, radius, az, 65)}
                      interactive={false}
                      pathOptions={{
                        color,
                        fillColor: color,
                        fillOpacity: 0.12,
                        weight: 1,
                        pane: "coverage-sector",
                      }}
                    />
                  );
                })
              : null}

            {filteredTowers.map((tower, index) => {
              const spec = buildSpec(tower, userLocation);
              const providerColor = getColor(tower.provider);
              const markerColor = showHeat ? getHeatColor(spec.quality) : providerColor;
              const selected =
                selectedTower?.cellid === tower.cellid &&
                selectedTower?.lac === tower.lac &&
                selectedTower?.mnc === tower.mnc;

              return (
                <CircleMarker
                  key={`marker-${tower.mcc}-${tower.mnc}-${tower.lac}-${tower.cellid}-${index}`}
                  center={[tower.lat, tower.lon]}
                  radius={selected ? 10 : showHeat && spec.quality === "Weak" ? 8 : 5}
                  eventHandlers={{
                    click: () => {
                      setSelectedTower(tower);
                      setFocusSignal((v) => v + 1);
                    },
                  }}
                  pathOptions={{
                    color: selected ? "#ffffff" : markerColor,
                    fillColor: markerColor,
                    fillOpacity: selected ? 1 : 0.85,
                    weight: selected ? 4 : 2,
                  }}
                >
                  <Popup>
                    <div style={{ minWidth: 220 }}>
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
                      <br />
                      Distance: {userLocation ? `${spec.distanceKm} km` : "GPS needed"}
                      <br />
                      <button
                        onClick={() => openGoogleMaps(tower.lat, tower.lon)}
                        style={{
                          marginTop: 8,
                          width: "100%",
                          padding: "8px",
                          borderRadius: 8,
                          border: "1px solid #0891b2",
                          background: "#083344",
                          color: "#67e8f9",
                          fontWeight: 700,
                          cursor: "pointer",
                        }}
                      >
                        Open Google Maps
                      </button>
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
echo "DONE"
echo "=================================================="
