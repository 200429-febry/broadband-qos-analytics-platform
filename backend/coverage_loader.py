import csv
import gzip
from pathlib import Path
from functools import lru_cache

PROVIDER_MAP = {
    1: "Indosat Ooredoo Hutchison",
    10: "Telkomsel",
    11: "XL Axiata",
    28: "Smartfren",
    89: "Tri Indonesia",
}

DATA_FILE_CANDIDATES = [
    Path(__file__).resolve().parent / "data" / "510.csv.gz",
    Path(__file__).resolve().parent.parent / "data" / "510.csv.gz",
]


def get_data_file():
    for path in DATA_FILE_CANDIDATES:
        if path.exists():
            return path
    return DATA_FILE_CANDIDATES[0]


@lru_cache(maxsize=1)
def read_all_towers():
    towers = []

    data_file = get_data_file()

    if not data_file.exists():
        print(f"Coverage data file not found. Tried: {DATA_FILE_CANDIDATES}")
        return towers

    print(f"Using coverage data file: {data_file}")

    with gzip.open(data_file, "rt", encoding="utf-8", errors="ignore") as f:
        reader = csv.reader(f)

        for row in reader:
            if len(row) < 14:
                continue

            try:
                radio = row[0].strip()
                mcc = int(row[1])
                mnc = int(row[2])
                lac = int(row[3])
                cellid = int(row[4])
                lon = float(row[6])
                lat = float(row[7])
                range_m = int(float(row[8] or 0))
                samples = int(float(row[9] or 0))
                average_signal = int(float(row[13] or 0))
            except Exception:
                continue

            towers.append({
                "radio": radio,
                "mcc": mcc,
                "mnc": mnc,
                "provider": PROVIDER_MAP.get(mnc, "Other / Unknown"),
                "lac": lac,
                "cellid": cellid,
                "lon": lon,
                "lat": lat,
                "range": range_m,
                "samples": samples,
                "average_signal": average_signal,
            })

    print(f"Loaded OpenCellID towers: {len(towers)}")
    return towers


def load_coverage_data(
    limit=5000,
    min_lat=-6.7,
    max_lat=-5.9,
    min_lon=106.4,
    max_lon=107.2,
):
    all_towers = read_all_towers()

    result = []

    for tower in all_towers:
        lat = tower["lat"]
        lon = tower["lon"]

        if min_lat <= lat <= max_lat and min_lon <= lon <= max_lon:
            result.append(tower)

            if len(result) >= limit:
                break

    return result
