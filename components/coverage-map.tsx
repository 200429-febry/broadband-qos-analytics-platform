"use client";

import { Fragment, useCallback, useEffect, useMemo, useState } from "react";
import {
  MapContainer,
  TileLayer,
  CircleMarker,
  Circle,
  Polygon,
  Popup,
  Marker,
  useMap,
  useMapEvents,
} from "react-leaflet";
import type { LatLngBounds } from "leaflet";
import L from "leaflet";

interface Tower {
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
}

type BoundsPayload = {
  min_lat: number;
  max_lat: number;
  min_lon: number;
  max_lon: number;
};

type UserLocation = {
  lat: number;
  lon: number;
};

type QoSMetrics = {
  throughput: number;
  latency: number;
  jitter: number;
  packet_loss: number;
  bandwidth?: number;
};

const userIcon = L.divIcon({
  className: "user-location-marker",
  html: `
    <div style="
      width: 18px;
      height: 18px;
      background: #22c55e;
      border: 3px solid white;
      border-radius: 9999px;
      box-shadow: 0 0 0 8px rgba(34,197,94,0.25);
    "></div>
  `,
  iconSize: [18, 18],
  iconAnchor: [9, 9],
});

function getQoSHeatColor(metrics: QoSMetrics | null) {
  if (!metrics) return "#22c55e";

  if (
    metrics.latency > 120 ||
    metrics.jitter > 40 ||
    metrics.packet_loss > 3 ||
    metrics.throughput < 5
  ) {
    return "#ef4444";
  }

  if (
    metrics.latency > 80 ||
    metrics.jitter > 25 ||
    metrics.packet_loss > 1 ||
    metrics.throughput < 15
  ) {
    return "#f59e0b";
  }

  return "#22c55e";
}

function getQoSHeatLabel(metrics: QoSMetrics | null) {
  if (!metrics) return "QoS Normal";

  if (
    metrics.latency > 120 ||
    metrics.jitter > 40 ||
    metrics.packet_loss > 3 ||
    metrics.throughput < 5
  ) {
    return "Critical QoS Degradation";
  }

  if (
    metrics.latency > 80 ||
    metrics.jitter > 25 ||
    metrics.packet_loss > 1 ||
    metrics.throughput < 15
  ) {
    return "QoS Warning / Degraded";
  }

  return "QoS Normal";
}

function getProviderColor(provider: string) {
  const p = provider.toLowerCase();

  if (p.includes("telkomsel")) return "#ef4444";
  if (p.includes("xl")) return "#3b82f6";
  if (p.includes("indosat")) return "#facc15";
  if (p.includes("smartfren")) return "#ec4899";
  if (p.includes("tri")) return "#a855f7";

  return "#22c55e";
}

const providerLegend = [
  { name: "Telkomsel", color: "#ef4444" },
  { name: "XL Axiata", color: "#3b82f6" },
  { name: "Indosat Ooredoo Hutchison", color: "#facc15" },
  { name: "Smartfren", color: "#ec4899" },
  { name: "Tri Indonesia", color: "#a855f7" },
  { name: "Other / Unknown", color: "#22c55e" },
];

const satelliteLayer = [
  { name: "Telkom-4 Merah Putih", type: "GEO Communication Satellite", lat: -0.2, lon: 108.0 },
  { name: "SATRIA-1", type: "HTS Broadband Satellite", lat: -0.1, lon: 146.0 },
  { name: "Nusantara Satu", type: "Broadband Communication Satellite", lat: 0.0, lon: 146.0 },
  { name: "Palapa-D Legacy Orbit", type: "Legacy Telecom Orbit Slot", lat: 0.1, lon: 113.0 },
  { name: "LEO Broadband Pass", type: "LEO Internet Satellite Track", lat: -6.2, lon: 106.8 },
  { name: "GNSS Reference Visibility", type: "Navigation Satellite Footprint", lat: -2.5, lon: 118.0 },
];

<div className="mb-3 rounded-lg border border-slate-700 bg-slate-900/70 p-3">
  <p className="mb-1 text-xs font-semibold text-slate-300">
    RF Intelligence Mode
  </p>

  <p className="text-[11px] text-slate-500">
    Band and coverage type are inferred from public OpenCellID radio records,
    provider identity, and estimated range. Exact EARFCN/PCI/SINR requires
    drive-test or operator OSS data.
  </p>
</div>

function estimateBand(tower: Tower) {
  const provider = tower.provider.toLowerCase();
  const radio = tower.radio.toUpperCase();

  if (radio === "GSM") {
    if (provider.includes("telkomsel")) return "GSM 900 / 1800 MHz";
    if (provider.includes("xl")) return "GSM 900 / 1800 MHz";
    if (provider.includes("indosat")) return "GSM 900 / 1800 MHz";
    return "GSM band unknown";
  }

  if (radio === "UMTS") {
    if (provider.includes("telkomsel")) return "UMTS B1 2100 MHz";
    if (provider.includes("xl")) return "UMTS B1 2100 MHz";
    if (provider.includes("indosat")) return "UMTS B1 2100 MHz";
    return "UMTS band unknown";
  }

  if (radio === "LTE") {
    if (provider.includes("telkomsel")) {
      return "LTE B3 1800 / B8 900 / B40 2300 MHz";
    }

    if (provider.includes("xl")) {
      return "LTE B1 2100 / B3 1800 / B8 900 MHz";
    }

    if (provider.includes("indosat")) {
      return "LTE B1 2100 / B3 1800 / B8 900 MHz";
    }

    if (provider.includes("smartfren")) {
      return "LTE B5 850 / B40 2300 MHz";
    }

    if (provider.includes("tri")) {
      return "LTE B1 2100 / B3 1800 MHz";
    }

    return "LTE band unknown";
  }

  if (radio === "NR") {
    return "NR/5G band available in dataset";
  }

  return "Unknown band";
}

function classifyCoverage(tower: Tower) {
  if (tower.range >= 5000) return "Macro / wide-area coverage";
  if (tower.range >= 1500) return "Urban macro coverage";
  if (tower.range >= 500) return "Micro / dense urban coverage";
  return "Small cell / local coverage";
}

function classifySignal(tower: Tower) {
  if (tower.average_signal === 0) {
    return {
      label: "Unknown",
      className: "text-slate-400",
    };
  }

  if (tower.average_signal >= -70) {
    return {
      label: "Excellent",
      className: "text-emerald-400",
    };
  }

  if (tower.average_signal >= -85) {
    return {
      label: "Good",
      className: "text-lime-400",
    };
  }

  if (tower.average_signal >= -100) {
    return {
      label: "Fair",
      className: "text-yellow-400",
    };
  }

  return {
    label: "Weak",
    className: "text-red-400",
  };
}

function boundsToPayload(bounds: LatLngBounds): BoundsPayload {
  const sw = bounds.getSouthWest();
  const ne = bounds.getNorthEast();

  return {
    min_lat: sw.lat,
    max_lat: ne.lat,
    min_lon: sw.lng,
    max_lon: ne.lng,
  };
}

function getLimitByZoom(zoom: number) {
  if (zoom <= 6) return 600;
  if (zoom <= 8) return 1000;
  if (zoom <= 10) return 1800;
  if (zoom <= 12) return 3000;
  return 4500;
}

function radiusToBounds(lat: number, lon: number, km: number) {
  const latDelta = km / 111;
  const lonDelta = km / (111 * Math.cos((lat * Math.PI) / 180));

  return {
    min_lat: lat - latDelta,
    max_lat: lat + latDelta,
    min_lon: lon - lonDelta,
    max_lon: lon + lonDelta,
  };
}

function getDistanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
) {
  const earthRadius = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;

  return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}


function MapResizeFix() {
  const map = useMap();

  useEffect(() => {
    const resize = () => {
      setTimeout(() => {
        map.invalidateSize();
      }, 150);
    };

    resize();

    window.addEventListener("resize", resize);

    const interval = setInterval(resize, 1000);

    return () => {
      window.removeEventListener("resize", resize);
      clearInterval(interval);
    };
  }, [map]);

  return null;
}

function ViewportLoader({
  onViewportChange,
}: {
  onViewportChange: (bounds: BoundsPayload, zoom: number) => void;
}) {
  const map = useMapEvents({
    moveend: () => {
      onViewportChange(boundsToPayload(map.getBounds()), map.getZoom());
    },
    zoomend: () => {
      onViewportChange(boundsToPayload(map.getBounds()), map.getZoom());
    },
  });

  useEffect(() => {
    onViewportChange(boundsToPayload(map.getBounds()), map.getZoom());
  }, [map, onViewportChange]);

  return null;
}

function LocateController({
  userLocation,
}: {
  userLocation: UserLocation | null;
}) {
  const map = useMap();

  useEffect(() => {
    if (!userLocation) return;

    map.flyTo([userLocation.lat, userLocation.lon], 14, {
      animate: true,
      duration: 1.2,
    });
  }, [userLocation, map]);

  return null;
}


function createHexagonPoints(lat: number, lon: number, radiusMeters: number) {
  const earthRadius = 6378137;
  const points: [number, number][] = [];
  const latRad = (lat * Math.PI) / 180;

  for (let i = 0; i < 6; i++) {
    const angle = ((60 * i - 30) * Math.PI) / 180;

    const dx = radiusMeters * Math.cos(angle);
    const dy = radiusMeters * Math.sin(angle);

    const dLat = (dy / earthRadius) * (180 / Math.PI);
    const dLon = (dx / (earthRadius * Math.cos(latRad))) * (180 / Math.PI);

    points.push([lat + dLat, lon + dLon]);
  }

  return points;
}

export default function CoverageMap() {
  const [towers, setTowers] = useState<Tower[]>([]);
  const [providerFilter, setProviderFilter] = useState("All");
  const [radioFilter, setRadioFilter] = useState("All");
  const [showRadius, setShowRadius] = useState(false);
  const [showSatellites, setShowSatellites] = useState(true);
  const [showQoSHeatmap, setShowQoSHeatmap] = useState(true);
  const [qosMetrics, setQosMetrics] = useState<QoSMetrics | null>(null);
  const [loading, setLoading] = useState(false);
  const [currentZoom, setCurrentZoom] = useState(5);
  const [userLocation, setUserLocation] = useState<UserLocation | null>(null);
  const [locationStatus, setLocationStatus] = useState("");
  const [nearbyRadius, setNearbyRadius] = useState(10);
  const [isBtsPopupOpen, setIsBtsPopupOpen] = useState(false);

  const loadCoverage = useCallback(
    async (bounds: BoundsPayload, zoom: number) => {
      if (isBtsPopupOpen) {
        return;
      }

      try {
        setLoading(true);
        setCurrentZoom(zoom);

        const api =
          "https://qos-api-gh3tn2a6oa-et.a.run.app";

        const limit = getLimitByZoom(zoom);

        const params = new URLSearchParams({
          limit: String(limit),
          min_lat: String(bounds.min_lat),
          max_lat: String(bounds.max_lat),
          min_lon: String(bounds.min_lon),
          max_lon: String(bounds.max_lon),
        });

        const res = await fetch(`${api}/api/coverage?${params.toString()}`);

        if (!res.ok) {
          throw new Error("Coverage API failed");
        }

        const data = await res.json();
        const nextTowers = data.towers || [];

        if (nextTowers.length > 0) {
          setTowers(nextTowers);
        } else {
          console.warn("No BTS found in current viewport. Keeping previous BTS data.");
        }
      } catch (error) {
        console.error("Failed loading viewport coverage:", error);
      } finally {
        setLoading(false);
      }
    },
    [isBtsPopupOpen]
  );

  const locateMe = () => {
    if (!navigator.geolocation) {
      setLocationStatus("Geolocation is not supported by this browser.");
      return;
    }

    setLocationStatus("Requesting location permission...");

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const nextLocation = {
          lat: position.coords.latitude,
          lon: position.coords.longitude,
        };

        setUserLocation(nextLocation);

        const bounds = radiusToBounds(
          nextLocation.lat,
          nextLocation.lon,
          nearbyRadius
        );

        loadCoverage(bounds, 13);

        setLocationStatus(
          `Location acquired • ${nearbyRadius} km coverage`
        );
      },
      (error) => {
        console.error(error);
        setLocationStatus("Location permission denied or unavailable.");
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 0,
      }
    );
  };

  const providers = useMemo(() => {
    return ["All", ...Array.from(new Set(towers.map((t) => t.provider)))];
  }, [towers]);

  const radios = useMemo(() => {
    return ["All", ...Array.from(new Set(towers.map((t) => t.radio)))];
  }, [towers]);

  const filteredTowers = useMemo(() => {
    return towers.filter((tower) => {
      const matchProvider =
        providerFilter === "All" || tower.provider === providerFilter;

      const matchRadio =
        radioFilter === "All" || tower.radio === radioFilter;

      return matchProvider && matchRadio;
    });
  }, [towers, providerFilter, radioFilter]);

  const nearestTowers = useMemo(() => {
    if (!userLocation) return [];

    return filteredTowers
      .map((tower) => ({
        ...tower,
        distanceKm: getDistanceKm(
          userLocation.lat,
          userLocation.lon,
          tower.lat,
          tower.lon
        ),
      }))
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, 5);
  }, [filteredTowers, userLocation]);

  const loadQoSMetrics = useCallback(async () => {
    try {
      const response = await fetch(
        `${"https://qos-api-gh3tn2a6oa-et.a.run.app"}/api/qos/metrics?qosHeat=${Date.now()}`,
        { cache: "no-store" }
      );

      const data = await response.json();

      setQosMetrics({
        throughput: Number(data.throughput || 0),
        latency: Number(data.latency || 0),
        jitter: Number(data.jitter || 0),
        packet_loss: Number(data.packet_loss || 0),
        bandwidth: Number(data.bandwidth || 0),
      });
    } catch (error) {
      console.error("Failed to load QoS heatmap metrics:", error);
    }
  }, []);

  useEffect(() => {
    loadQoSMetrics();

    const interval = setInterval(loadQoSMetrics, 3000);

    return () => clearInterval(interval);
  }, [loadQoSMetrics]);

  const stats = useMemo(() => {
    return {
      total: filteredTowers.length,
      lte: filteredTowers.filter((t) => t.radio === "LTE").length,
      gsm: filteredTowers.filter((t) => t.radio === "GSM").length,
      umts: filteredTowers.filter((t) => t.radio === "UMTS").length,
      nr: filteredTowers.filter((t) => t.radio === "NR").length,
      providers: new Set(filteredTowers.map((t) => t.provider)).size,
    };
  }, [filteredTowers]);

  return (
    <div className="relative h-full min-h-[650px] w-full overflow-hidden rounded-2xl bg-slate-950">
      <div className="absolute left-4 top-4 z-[1000] max-h-[480px] w-[350px] overflow-y-auto rounded-xl border border-slate-700 bg-slate-950/90 p-4 text-sm text-slate-200 shadow-xl backdrop-blur">
        <div className="mb-3 flex items-start justify-between gap-3">
          <div>
            <p className="font-bold text-white">
              Dynamic Coverage Intelligence
            </p>
            <p className="text-xs text-slate-400">
              Viewport-based OpenCellID BTS loading
            </p>
          </div>

          <span className="rounded-full bg-emerald-500/10 px-2 py-1 text-[11px] text-emerald-300">
            Zoom {currentZoom}
          </span>
        </div>

        <div className="mb-3 grid grid-cols-2 gap-2">
          <Stat label="Visible BTS" value={stats.total} />
          <Stat label="Providers" value={stats.providers} />
          <Stat label="LTE" value={stats.lte} />
          <Stat label="GSM" value={stats.gsm} />
          <Stat label="NR/5G" value={stats.nr} />
          <Stat label="UMTS" value={stats.umts} />
        </div>

        <div className="mb-3 rounded-lg border border-slate-700 bg-slate-900/70 p-3">
  <p className="mb-2 text-xs font-semibold text-slate-300">
    Provider Legend
  </p>

  <div className="grid grid-cols-2 gap-2">
    {providerLegend.map((item) => (
      <div key={item.name} className="flex items-center gap-2">
        <span
          className="h-3 w-3 rounded-full"
          style={{ backgroundColor: item.color }}
        />
        <span className="text-[11px] text-slate-400">
          {item.name}
        </span>
      </div>
    ))}
  </div>
</div>

        <button
          onClick={locateMe}
          className="mb-3 w-full rounded-lg border border-cyan-500/30 bg-cyan-500/10 px-3 py-2 text-cyan-300 hover:bg-cyan-500/20"
        >
          Locate Me via GPS
        </button>

        <label className="mb-1 block text-xs text-slate-400">
          Nearby Radius
        </label>

        <select
          value={nearbyRadius}
          onChange={(e) => setNearbyRadius(Number(e.target.value))}
          className="mb-3 w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-white"
        >
          <option value={5}>5 km</option>
          <option value={10}>10 km</option>
          <option value={25}>25 km</option>
        </select>

        {locationStatus && (
          <p className="mb-3 text-[11px] text-slate-400">
            {locationStatus}
          </p>
        )}

        <label className="mb-1 block text-xs text-slate-400">
          Provider
        </label>

        <select
          value={providerFilter}
          onChange={(e) => setProviderFilter(e.target.value)}
          className="mb-3 w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-white"
        >
          {providers.map((provider) => (
            <option key={provider} value={provider}>
              {provider}
            </option>
          ))}
        </select>

        <label className="mb-1 block text-xs text-slate-400">
          Radio Technology
        </label>

        <select
          value={radioFilter}
          onChange={(e) => setRadioFilter(e.target.value)}
          className="mb-3 w-full rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-white"
        >
          {radios.map((radio) => (
            <option key={radio} value={radio}>
              {radio}
            </option>
          ))}
        </select>

        <button
          onClick={() => setShowRadius((v) => !v)}
          className="mb-2 w-full rounded-lg border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-emerald-300 hover:bg-emerald-500/20"
        >
          {showRadius ? "Hide Coverage Radius" : "Show Coverage Radius"}
        </button>

        <button
          onClick={() => setShowSatellites((v) => !v)}
          className="mb-2 w-full rounded-lg border border-violet-500/30 bg-violet-500/10 px-3 py-2 text-violet-300 hover:bg-violet-500/20"
        >
          {showSatellites ? "Hide Satellite Layer" : "Show Satellite Layer"}
        </button>

        <button
          onClick={() => setShowQoSHeatmap((v) => !v)}
          className="w-full rounded-lg border border-rose-500/30 bg-rose-500/10 px-3 py-2 text-rose-300 hover:bg-rose-500/20"
        >
          {showQoSHeatmap ? "Hide QoS Heatmap Layer" : "Show QoS Heatmap Layer"}
        </button>

        <div className="mt-3 rounded-lg border border-slate-700 bg-slate-900/70 p-3">
          <p className="text-xs font-semibold text-slate-300">
            QoS Heatmap Status
          </p>
          <p className="mt-1 text-[11px] text-slate-400">
            {getQoSHeatLabel(qosMetrics)}
          </p>
          <p className="mt-1 text-[11px] text-slate-500">
            TP {qosMetrics?.throughput?.toFixed(2) || "0.00"} Mbps •
            LAT {qosMetrics?.latency?.toFixed(2) || "0.00"} ms •
            JIT {qosMetrics?.jitter?.toFixed(2) || "0.00"} ms
          </p>
        </div>

        {userLocation && (
          <div className="mt-4 rounded-xl border border-slate-700 bg-slate-900/80 p-3">
            <p className="mb-2 font-semibold text-white">
              Nearest Cell Sites
            </p>

            <div className="space-y-2">
              {nearestTowers.map((tower) => (
                <div
                  key={`${tower.cellid}-${tower.distanceKm}`}
                  className="rounded-lg border border-slate-800 bg-slate-950/70 p-2"
                >
                  <p className="font-medium text-slate-100">
                    {tower.provider}
                  </p>

                  <p className="text-xs text-slate-400">
                    {tower.radio} • {estimateBand(tower)}
                  </p>

                  <p className="text-xs text-slate-500">
                    Cell ID {tower.cellid} • {classifyCoverage(tower)}
                  </p>

                  <p className="text-xs text-emerald-400">
                    {tower.distanceKm.toFixed(2)} km away
                  </p>

                  <p className={`text-xs ${classifySignal(tower).className}`}>
                     Signal: {classifySignal(tower).label}
                  </p>
                </div>
              ))}
            </div>
          </div>
        )}

        <p className="mt-3 text-[11px] text-slate-500">
          5G/NR appears only if public OpenCellID export contains NR records.
        </p>

        {loading && (
          <p className="mt-2 text-xs text-cyan-300">
            Loading viewport data...
          </p>
        )}
      </div>

      <MapContainer
        center={[-2.5, 118]}
        zoom={5}
        scrollWheelZoom={true}
        className="h-full w-full"
        style={{
          height: "100%",
          width: "100%",
          background: "#020617",
        }}
      >
        <MapResizeFix />
        <ViewportLoader onViewportChange={loadCoverage} />
        <LocateController userLocation={userLocation} />

        <TileLayer
          attribution="© OpenStreetMap"
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {userLocation && (
          <Marker
            position={[userLocation.lat, userLocation.lon]}
            icon={userIcon}
          >
            <Popup>
              <div className="text-sm">
                <b>Your Current Location</b>
                <br />
                Lat: {userLocation.lat.toFixed(6)}
                <br />
                Lon: {userLocation.lon.toFixed(6)}
              </div>
            </Popup>
          </Marker>
        )}

        {showQoSHeatmap && (
          <Circle
            center={[
              userLocation?.lat || -6.2,
              userLocation?.lon || 106.8
            ]}
            radius={
              qosMetrics && qosMetrics.latency > 120
                ? 9000
                : qosMetrics && qosMetrics.latency > 80
                ? 6500
                : 4500
            }
            pathOptions={{
              color: getQoSHeatColor(qosMetrics),
              fillColor: getQoSHeatColor(qosMetrics),
              fillOpacity: 0.18,
              weight: 2,
            }}
          >
            <Popup>
              <div className="min-w-[220px] text-sm">
                <h3 className="mb-2 font-bold text-slate-900">
                  Live QoS Heatmap
                </h3>
                <p><b>Status:</b> {getQoSHeatLabel(qosMetrics)}</p>
                <p><b>Throughput:</b> {qosMetrics?.throughput?.toFixed(2)} Mbps</p>
                <p><b>Latency:</b> {qosMetrics?.latency?.toFixed(2)} ms</p>
                <p><b>Jitter:</b> {qosMetrics?.jitter?.toFixed(2)} ms</p>
                <p><b>Packet Loss:</b> {qosMetrics?.packet_loss?.toFixed(2)}%</p>
                <p><b>Source:</b> Real browser QoS probe via Cloud Run</p>
              </div>
            </Popup>
          </Circle>
        )}

        {showSatellites &&
          satelliteLayer.map((sat) => (
            <CircleMarker
              key={sat.name}
              center={[sat.lat, sat.lon]}
              radius={7}
              pathOptions={{
                color: "#22d3ee",
                fillColor: "#8b5cf6",
                fillOpacity: 0.9,
                weight: 2,
              }}
            >
              <Popup>
                <div className="min-w-[220px] text-sm">
                  <h3 className="mb-2 font-bold text-slate-900">
                    {sat.name}
                  </h3>
                  <p><b>Layer:</b> Satellite / Space Segment</p>
                  <p><b>Type:</b> {sat.type}</p>
                  <p><b>Latitude:</b> {sat.lat}</p>
                  <p><b>Longitude:</b> {sat.lon}</p>
                  <p><b>Function:</b> Broadband backhaul, broadcast, navigation, or orbital visibility reference.</p>
                </div>
              </Popup>
            </CircleMarker>
          ))}

        {filteredTowers.map((tower, index) => {
          const color = getProviderColor(tower.provider);
          const allowRadius = showRadius && filteredTowers.length <= 300;
          const safeRange = Math.max(250, Math.min(Number(tower.range || 500), 900));
          const markerRadius = currentZoom <= 6 ? 3 : currentZoom <= 9 ? 5 : 7;

          return (
            <Fragment key={`${tower.cellid}-${tower.lat}-${tower.lon}-${index}`}>
              {allowRadius && tower.range > 0 && (
                <Polygon
                  positions={createHexagonPoints(tower.lat, tower.lon, safeRange)}
                  interactive={false}
                  bubblingMouseEvents={false}
                  pathOptions={{
                    color,
                    fillColor: color,
                    fillOpacity: 0.055,
                    weight: 1.3,
                  }}
                />
              )}

              <CircleMarker
                center={[tower.lat, tower.lon]}
                radius={markerRadius}
                interactive={true}
                bubblingMouseEvents={false}
                eventHandlers={{
                  popupopen: () => setIsBtsPopupOpen(true),
                  popupclose: () => setIsBtsPopupOpen(false),
                }}
                pathOptions={{
                  color: "#ffffff",
                  fillColor: color,
                  fillOpacity: 0.95,
                  weight: 1.8,
                }}
              >
                <Popup closeButton={true} autoPan={false} keepInView={false} closeOnClick={false}>
                  <div className="min-w-[260px] text-sm">
                    <h3 className="mb-2 font-bold text-slate-900">
                      {tower.provider}
                    </h3>

                    <p><b>Radio:</b> {tower.radio}</p>
                    <p><b>MCC/MNC:</b> {tower.mcc}/{tower.mnc}</p>
                    <p><b>LAC/TAC:</b> {tower.lac}</p>
                    <p><b>Cell ID:</b> {tower.cellid}</p>
                    <p><b>Latitude:</b> {tower.lat}</p>
                    <p><b>Longitude:</b> {tower.lon}</p>
                    <p><b>Estimated Range:</b> {tower.range} m</p>
                    <p><b>Samples:</b> {tower.samples}</p>
                    <p><b>Average Signal:</b> {tower.average_signal}</p>
                    <p><b>Estimated Band:</b> {estimateBand(tower)}</p>
                    <p><b>Coverage Type:</b> {classifyCoverage(tower)}</p>
                    <p>
                      <b>Signal Class:</b>{" "}
                      <span className={classifySignal(tower).className}>
                        {classifySignal(tower).label}
                      </span>
                    </p>

                    <div className="mt-3 grid grid-cols-1 gap-2">
                      <button
                        type="button"
                        className="rounded-md bg-slate-900 px-3 py-2 text-xs font-semibold text-white hover:bg-slate-700"
                        onClick={(event) => {
                          event.stopPropagation();
                          navigator.clipboard.writeText(`${tower.lat}, ${tower.lon}`);
                        }}
                      >
                        Copy Coordinates
                      </button>

                      <a
                        className="rounded-md bg-emerald-600 px-3 py-2 text-center text-xs font-semibold text-white hover:bg-emerald-700"
                        href={`https://www.google.com/maps?q=${tower.lat},${tower.lon}`}
                        target="_blank"
                        rel="noreferrer"
                      >
                        Open in Google Maps
                      </a>

                      <a
                        className="rounded-md bg-blue-600 px-3 py-2 text-center text-xs font-semibold text-white hover:bg-blue-700"
                        href={`https://www.google.com/maps/@${tower.lat},${tower.lon},18z`}
                        target="_blank"
                        rel="noreferrer"
                      >
                        Zoom BTS Location
                      </a>
                    </div>
                  </div>
                </Popup>
              </CircleMarker>
            </Fragment>
          );
        })}
      </MapContainer>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-lg border border-slate-700 bg-slate-900/80 p-2">
      <p className="text-[11px] text-slate-400">{label}</p>
      <p className="text-lg font-bold text-white">{value}</p>
    </div>
  );
}