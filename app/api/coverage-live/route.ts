export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

import fs from "fs";
import path from "path";
import zlib from "zlib";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

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

const PROVIDERS: Record<number, string> = {
  1: "Indosat Ooredoo Hutchison",
  10: "Telkomsel",
  11: "XL Axiata",
  21: "Indosat Ooredoo Hutchison",
  89: "Tri Indonesia",
  99: "Esia / Legacy",
};

function splitCsvLine(line: string) {
  const result: string[] = [];
  let current = "";
  let inQuotes = false;

  for (const char of line) {
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      result.push(current);
      current = "";
    } else {
      current += char;
    }
  }

  result.push(current);
  return result.map((item) => item.trim().replace(/^"|"$/g, ""));
}

function toNumber(value: unknown, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function parseOpenCellCsv(text: string) {
  const lines = text.split(/\r?\n/).filter(Boolean);
  if (!lines.length) return [];

  const first = splitCsvLine(lines[0]).map((v) => v.toLowerCase());
  const hasHeader = first.includes("radio") || first.includes("mcc") || first.includes("lon");

  const start = hasHeader ? 1 : 0;
  const idx = (name: string, fallback: number) => {
    if (!hasHeader) return fallback;
    const i = first.indexOf(name);
    return i >= 0 ? i : fallback;
  };

  const radioIdx = idx("radio", 0);
  const mccIdx = idx("mcc", 1);
  const mncIdx = idx("net", 2);
  const areaIdx = idx("area", 3);
  const cellIdx = idx("cell", 4);
  const lonIdx = idx("lon", 6);
  const latIdx = idx("lat", 7);
  const rangeIdx = idx("range", 8);
  const samplesIdx = idx("samples", 9);
  const signalIdx = idx("averageSignal".toLowerCase(), 13);

  const towers: Tower[] = [];

  for (let i = start; i < lines.length && towers.length < 8000; i++) {
    const cols = splitCsvLine(lines[i]);
    if (cols.length < 8) continue;

    const mcc = toNumber(cols[mccIdx]);
    const mnc = toNumber(cols[mncIdx]);
    const lon = toNumber(cols[lonIdx]);
    const lat = toNumber(cols[latIdx]);

    if (mcc !== 510) continue;
    if (lon < 94 || lon > 142 || lat < -12 || lat > 8) continue;

    towers.push({
      radio: cols[radioIdx] || "LTE",
      mcc,
      mnc,
      provider: PROVIDERS[mnc] || "Other / Unknown",
      lac: toNumber(cols[areaIdx]),
      cellid: toNumber(cols[cellIdx]),
      lon,
      lat,
      range: toNumber(cols[rangeIdx], 1000),
      samples: toNumber(cols[samplesIdx], 1),
      average_signal: toNumber(cols[signalIdx], -90),
    });
  }

  return towers;
}

function readLocalCoverage() {
  const candidates = [
    path.join(process.cwd(), "public", "data", "510.csv.gz"),
    path.join(process.cwd(), "public", "data", "coverage.csv.gz"),
    path.join(process.cwd(), "public", "data", "coverage.csv"),
    path.join(process.cwd(), "public", "510.csv.gz"),
    path.join(process.cwd(), "510.csv.gz"),
  ];

  for (const file of candidates) {
    if (!fs.existsSync(file)) continue;

    const buffer = fs.readFileSync(file);
    const text = file.endsWith(".gz")
      ? zlib.gunzipSync(buffer).toString("utf-8")
      : buffer.toString("utf-8");

    const towers = parseOpenCellCsv(text);

    return {
      found: true,
      file,
      towers,
    };
  }

  return {
    found: false,
    file: null,
    towers: [] as Tower[],
  };
}

export async function GET() {
  try {
    const backendResponse = await fetch(`${API_URL}/api/coverage?x=${Date.now()}`, {
      cache: "no-store",
    });

    if (backendResponse.ok) {
      const backendData = await backendResponse.json();
      const backendTowers = Array.isArray(backendData?.towers) ? backendData.towers : [];
      const backendCount = Number(backendData?.count ?? backendTowers.length ?? 0);

      if (backendCount > 0 || backendTowers.length > 0) {
        return Response.json({
          ...backendData,
          count: backendCount || backendTowers.length,
          source: backendData.source || "backend-coverage-api",
          dataset_status: "loaded_from_backend",
        });
      }
    }
  } catch {
    // fallback to local dataset
  }

  const local = readLocalCoverage();

  if (local.found && local.towers.length > 0) {
    const providers = Array.from(new Set(local.towers.map((tower) => tower.provider)));

    return Response.json({
      count: local.towers.length,
      towers: local.towers,
      providers,
      source: "local-opencellid-dataset",
      dataset_status: "loaded_from_local_file",
      dataset_file: local.file,
    });
  }

  return Response.json({
    count: 0,
    towers: [],
    providers: [],
    source: "coverage-dataset-not-loaded",
    dataset_status: "dataset_not_loaded",
    message:
      "No OpenCellID/coverage CSV dataset was found. Upload 510.csv.gz or coverage.csv to public/data/ to enable real BTS coverage.",
  });
}
