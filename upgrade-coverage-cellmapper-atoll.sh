#!/bin/bash
set -e

echo "=== Backup current coverage UI ==="
mkdir -p .backup-coverage-upgrade
[ -f app/coverage/page.tsx ] && cp app/coverage/page.tsx .backup-coverage-upgrade/app_coverage_page.tsx.bak
[ -f components/coverage-map-client.tsx ] && cp components/coverage-map-client.tsx .backup-coverage-upgrade/components_coverage-map-client.tsx.bak

echo "=== Patch Coverage Page ==="
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

echo "=== Patch CellMapper / Atoll-style Coverage Client ==="
cat > components/coverage-map-client.tsx <<'TSX'
"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Circle,
  CircleMarker,
  MapContainer,
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

type NearestTower = Tower & {
  distanceKm: number;
  estimatedSignal: number;
  quality: string;
  risk: string;
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
  const earthRadiusKm = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;

  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function estimateSignal(baseSignal: number, distanceKm: number, rangeMeter: number) {
  const rangeKm = Math.max(rangeMeter / 1000, 0.5);
  const distancePenalty = Math.min(distanceKm / rangeKm, 3) * 12;
  return Math.round(baseSignal - distancePenalty);
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

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-slate-700 bg-slate-900/80 p-3">
      <p className="text-xs text-slate-400">{label}</p>
      <p className="mt-1 text-2xl font-black text-white">{value}</p>
    </div>
  );
}

function MiniSpec({
  label,
  value,
  accent,
}: {
  label: string;
  value: string | number;
  accent?: string;
}) {
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
  const [data, setData] = useState<CoverageResponse>({
    count: 0,
    towers: [],
    providers: [],
  });

  const [providerFilter, setProviderFilter] = useState("ALL");
  const [radioFilter, setRadioFilter] = useState("ALL");
  const [limit, setLimit] = useState(3000);
  const [showRadius, setShowRadius] = useState(false);
  const [userLocation, setUserLocation] = useState<[number, number] | null>(null);
  const [selectedTower, setSelectedTower] = useState<Tower | null>(null);
  const [loading, setLoading] = useState(true);
  const [gpsError, setGpsError] = useState("");

  const fetchCoverage = async () => {
    try {
      const res = await fetch(`/api/coverage-live?x=${Date.now()}`, {
        cache: "no-store",
      });

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
      .slice(0, limit);
  }, [data.towers, providerFilter, radioFilter, limit]);

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

  const nearestTowers = useMemo<NearestTower[]>(() => {
    if (!userLocation) return [];

    return filteredTowers
      .map((tower) => {
        const distanceKm = haversineKm(userLocation[0], userLocation[1], tower.lat, tower.lon);
        const estimatedSignal = estimateSignal(
          Number(tower.average_signal || -90),
          distanceKm,
          Number(tower.range || 1000)
        );

        return {
          ...tower,
          distanceKm: Number(distanceKm.toFixed(2)),
          estimatedSignal,
          quality: qualityFromSignal(estimatedSignal),
          risk: riskFromSignal(estimatedSignal, distanceKm, Number(tower.range || 1000)),
        };
      })
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, 5);
  }, [filteredTowers, userLocation]);

  const servingTower = selectedTower || nearestTowers[0] || null;

  const servingSpec = useMemo(() => {
    if (!servingTower) return null;

    const distanceKm = userLocation
      ? haversineKm(userLocation[0], userLocation[1], servingTower.lat, servingTower.lon)
      : 0;

    const estimatedSignal = estimateSignal(
      Number(servingTower.average_signal || -90),
      distanceKm,
      Number(servingTower.range || 1000)
    );

    return {
      distanceKm: Number(distanceKm.toFixed(2)),
      estimatedSignal,
      quality: qualityFromSignal(estimatedSignal),
      risk: riskFromSignal(
        estimatedSignal,
        distanceKm,
        Number(servingTower.range || 1000)
      ),
    };
  }, [servingTower, userLocation]);

  const locateMe = () => {
    setGpsError("");

    if (!navigator.geolocation) {
      setGpsError("GPS tidak didukung browser ini.");
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setUserLocation([pos.coords.latitude, pos.coords.longitude]);
      },
      () => {
        setGpsError("GPS gagal diakses. Izinkan location permission di browser.");
      },
      {
        enableHighAccuracy: true,
        timeout: 12000,
        maximumAge: 5000,
      }
    );
  };

  const center: [number, number] = [-2.5, 118.0];

  return (
    <main className="space-y-6 p-6 text-white">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black">Cellular Coverage Intelligence</h1>
          <p className="mt-2 text-slate-400">
            CellMapper / Atoll-style BTS intelligence with provider layer, radio layer,
            nearest serving cell, RF estimate, and coverage radius from real OpenCellID data.
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
          <p className="mt-2 text-sm text-slate-300">
            {data.message ||
              "No BTS dataset was found. Upload 510.csv.gz or coverage.csv to public/data/ to enable real coverage visualization."}
          </p>
          <p className="mt-2 text-xs text-slate-500">Source: {data.source || "unknown"}</p>
        </div>
      ) : null}

      <section className="relative overflow-hidden rounded-3xl border border-slate-800 bg-slate-900/70">
        <div className="absolute left-5 top-5 z-[1000] w-[390px] rounded-2xl border border-slate-700 bg-slate-950/95 p-5 shadow-2xl backdrop-blur-xl">
          <div className="mb-4 flex items-start justify-between">
            <div>
              <h2 className="font-black">Dynamic Coverage Intelligence</h2>
              <p className="text-xs text-slate-400">Viewport-based OpenCellID BTS loading</p>
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

          {gpsError ? (
            <p className="mt-2 rounded-lg border border-red-500/30 bg-red-500/10 p-2 text-xs text-red-300">
              {gpsError}
            </p>
          ) : null}

          <div className="mt-4 grid grid-cols-2 gap-3">
            <select
              value={providerFilter}
              onChange={(e) => setProviderFilter(e.target.value)}
              className="rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-xs text-white"
            >
              <option value="ALL">All Providers</option>
              {providers.map((provider) => (
                <option key={provider} value={provider}>
                  {provider}
                </option>
              ))}
            </select>

            <select
              value={radioFilter}
              onChange={(e) => setRadioFilter(e.target.value)}
              className="rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-xs text-white"
            >
              <option value="ALL">All Radio</option>
              {radios.map((radio) => (
                <option key={radio} value={radio}>
                  {radio}
                </option>
              ))}
            </select>

            <select
              value={limit}
              onChange={(e) => setLimit(Number(e.target.value))}
              className="rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-xs text-white"
            >
              <option value={600}>600 BTS</option>
              <option value={1000}>1000 BTS</option>
              <option value={3000}>3000 BTS</option>
              <option value={5000}>5000 BTS</option>
              <option value={8000}>8000 BTS</option>
            </select>

            <button
              onClick={() => setShowRadius((prev) => !prev)}
              className="rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-xs font-bold text-cyan-300"
            >
              {showRadius ? "Hide Radius" : "Show Radius"}
            </button>
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

        <div className="absolute bottom-5 left-5 z-[1000] w-[390px] rounded-2xl border border-slate-700 bg-slate-950/95 p-5 shadow-2xl backdrop-blur-xl">
          <h2 className="text-sm font-black">RF Engineering Specs</h2>
          <p className="mt-1 text-xs text-slate-400">
            Serving-cell style estimate from selected or nearest BTS.
          </p>

          {servingTower && servingSpec ? (
            <>
              <div className="mt-4 grid grid-cols-2 gap-3">
                <MiniSpec label="Provider" value={servingTower.provider} accent="text-cyan-300" />
                <MiniSpec label="Radio" value={servingTower.radio} accent="text-emerald-300" />
                <MiniSpec label="MCC/MNC" value={`${servingTower.mcc}/${servingTower.mnc}`} />
                <MiniSpec label="LAC/TAC" value={servingTower.lac} />
                <MiniSpec label="Cell ID" value={servingTower.cellid} />
                <MiniSpec label="Distance" value={`${servingSpec.distanceKm} km`} />
                <MiniSpec
                  label="Est. Signal"
                  value={`${servingSpec.estimatedSignal} dBm`}
                  accent={
                    servingSpec.estimatedSignal >= -90
                      ? "text-emerald-300"
                      : servingSpec.estimatedSignal >= -105
                      ? "text-yellow-300"
                      : "text-red-300"
                  }
                />
                <MiniSpec label="Coverage Quality" value={servingSpec.quality} />
                <MiniSpec label="Range" value={`${servingTower.range || 0} m`} />
                <MiniSpec label="Samples" value={servingTower.samples || 0} />
              </div>

              <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/80 p-3">
                <p className="text-xs font-bold text-slate-300">Engineering Interpretation</p>
                <p className="mt-2 text-xs leading-relaxed text-slate-400">
                  {servingSpec.risk}. This is an RF planning estimate based on BTS position,
                  reported range, dataset signal, and user distance. Sector azimuth, PCI, EARFCN,
                  and exact band require operator-level dataset or Atoll planning file.
                </p>
              </div>
            </>
          ) : (
            <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/80 p-4 text-xs text-slate-400">
              Click a BTS marker or press Locate Me via GPS to calculate nearest serving-cell estimate.
            </div>
          )}

          {nearestTowers.length > 0 ? (
            <div className="mt-4">
              <p className="mb-2 text-xs font-bold text-slate-300">Nearest BTS Candidates</p>
              <div className="max-h-[160px] space-y-2 overflow-y-auto pr-1">
                {nearestTowers.map((tower) => (
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
                      {tower.radio} • Cell {tower.cellid} • {tower.estimatedSignal} dBm • {tower.quality}
                    </div>
                  </button>
                ))}
              </div>
            </div>
          ) : null}
        </div>

        <div className="h-[820px]">
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
                pathOptions={{
                  color: "#00e5ff",
                  fillColor: "#00e5ff",
                  fillOpacity: 0.8,
                  weight: 3,
                }}
              >
                <Popup>Your current GPS position</Popup>
              </CircleMarker>
            ) : null}

            {userLocation && nearestTowers[0] ? (
              <Polyline
                positions={[
                  userLocation,
                  [nearestTowers[0].lat, nearestTowers[0].lon],
                ]}
                pathOptions={{
                  color: "#00e5ff",
                  weight: 2,
                  dashArray: "8 8",
                }}
              />
            ) : null}

            {showRadius
              ? filteredTowers.slice(0, 500).map((tower, index) => {
                  const color = getColor(tower.provider);

                  return (
                    <Circle
                      key={`radius-${tower.cellid}-${index}`}
                      center={[tower.lat, tower.lon]}
                      radius={Math.max(Number(tower.range || 500), 200)}
                      pathOptions={{
                        color,
                        fillColor: color,
                        fillOpacity: 0.05,
                        weight: 1,
                      }}
                    />
                  );
                })
              : null}

            {filteredTowers.map((tower, index) => {
              const color = getColor(tower.provider);
              const selected = selectedTower?.cellid === tower.cellid;

              return (
                <CircleMarker
                  key={`${tower.mcc}-${tower.mnc}-${tower.cellid}-${index}`}
                  center={[tower.lat, tower.lon]}
                  radius={selected ? 9 : 5}
                  eventHandlers={{
                    click: () => setSelectedTower(tower),
                  }}
                  pathOptions={{
                    color,
                    fillColor: color,
                    fillOpacity: selected ? 1 : 0.72,
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
                      Range: {tower.range} m
                      <br />
                      Samples: {tower.samples}
                      <br />
                      Avg Signal: {tower.average_signal} dBm
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

echo "=== Done coverage upgrade ==="
