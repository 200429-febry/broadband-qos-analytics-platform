#!/bin/bash

API="https://qos-api-gh3tn2a6oa-et.a.run.app"
FRONTEND="https://qos-frontend-gh3tn2a6oa-et.a.run.app"

echo "=================================================="
echo "REAL DATA AUDIT — QoS Platform"
echo "=================================================="
echo "API      : $API"
echo "FRONTEND : $FRONTEND"
echo ""

echo "=================================================="
echo "[1] BACKEND ROUTE CHECK"
echo "=================================================="
curl -s "$API/openapi.json" | grep -o '"/api/[^"]*' | sed 's/"//g' | sort -u | head -120
echo ""

echo "=================================================="
echo "[2] CORE API DATA CHECK"
echo "=================================================="

echo "--- Health ---"
curl -s "$API/api/health"
echo -e "\n"

echo "--- QoS Metrics ---"
curl -s "$API/api/qos/metrics"
echo -e "\n"

echo "--- QoS History first 500 chars ---"
curl -s "$API/api/qos/history" | head -c 500
echo -e "\n"

echo "--- Alerts first 800 chars ---"
curl -s "$API/api/alerts" | head -c 800
echo -e "\n"

echo "--- Coverage first 500 chars ---"
curl -s "$API/api/coverage" | head -c 500
echo -e "\n"

echo "--- QoE Latest ---"
curl -s "$API/api/qoe/latest"
echo -e "\n"

echo "--- QoE Ping ---"
curl -s "$API/api/qoe/ping"
echo -e "\n"

echo "--- QoE Download Test ---"
curl -s -o /tmp/qoe-download.bin \
  -w "HTTP=%{http_code} SIZE=%{size_download} bytes TIME=%{time_total}s SPEED=%{speed_download} Bps\n" \
  "$API/api/qoe/download-fixed?size_kb=2048"
echo ""

echo "--- QoE Upload Test ---"
head -c 524288 /dev/zero | curl -s -X POST "$API/api/qoe/upload" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @-
echo -e "\n"

echo "=================================================="
echo "[3] FRONTEND PAGE CHECK"
echo "=================================================="
for path in "/" "/monitoring" "/streaming-qoe" "/analytics" "/coverage" "/predictions" "/alerts" "/database" "/topology" "/observability" "/users"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND$path")
  echo "$path => HTTP $code"
done
echo ""

echo "=================================================="
echo "[4] SOURCE CODE DUMMY / MOCK / RANDOM SCAN"
echo "=================================================="
grep -RniE "dummy|mock|fake|hardcoded|placeholder|sample data|Math.random|random\(|fallback|localhost:8000|static data|11" app components backend \
  --exclude-dir=node_modules \
  --exclude-dir=.next \
  --exclude-dir=venv \
  --exclude-dir=__pycache__ \
  --exclude="*.bak" \
  --exclude="*.bak-real-probe" \
  | head -250
echo ""

echo "=================================================="
echo "[5] FRONTEND API URL SCAN"
echo "=================================================="
grep -RniE "NEXT_PUBLIC_API_URL|localhost:8000|qos-api|API_URL" app components lib \
  --exclude-dir=node_modules \
  --exclude-dir=.next \
  --exclude="*.bak" \
  --exclude="*.bak-real-probe" \
  | head -150
echo ""

echo "=================================================="
echo "[6] BACKEND GENERATOR / SIMULATION SCAN"
echo "=================================================="
grep -RniE "random|simulate|generator|seed|fake|dummy|mock|sample|latency|throughput|jitter|packet_loss" backend \
  --exclude-dir=venv \
  --exclude-dir=__pycache__ \
  --exclude="*.bak" \
  | head -250
echo ""

echo "=================================================="
echo "AUDIT DONE"
echo "=================================================="
