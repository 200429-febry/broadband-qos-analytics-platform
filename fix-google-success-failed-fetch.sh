#!/bin/bash
set -e

echo "=================================================="
echo "FIX GOOGLE SUCCESS FAILED FETCH WITH SAME-ORIGIN PROXY"
echo "=================================================="

REGION="asia-southeast2"

API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

FRONTEND_URL=$(gcloud run services describe qos-frontend \
  --region="$REGION" \
  --format="value(status.url)")

echo "API_URL=$API_URL"
echo "FRONTEND_URL=$FRONTEND_URL"

mkdir -p .backup-auth-fetch-fix
[ -f app/auth/google-success/page.tsx ] && cp app/auth/google-success/page.tsx .backup-auth-fetch-fix/google-success-page.tsx.bak

echo "=== Test backend token endpoint first ==="
curl -i -s -X POST "$API_URL/api/auth/google/token" \
  -H "Content-Type: application/json" \
  -d '{"email":"febriyadi845@gmail.com","teamAccess":false}' | head -40

echo ""
echo "=== Create frontend same-origin auth proxy ==="

mkdir -p app/api/auth-google-token

cat > app/api/auth-google-token/route.ts <<TS
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "$API_URL";

export async function POST(request: Request) {
  try {
    const body = await request.text();

    const response = await fetch(\`\${API_URL}/api/auth/google/token\`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body,
      cache: "no-store",
    });

    const text = await response.text();

    return new Response(text, {
      status: response.status,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store, no-cache, must-revalidate",
      },
    });
  } catch (error: any) {
    return Response.json(
      {
        error: "Frontend proxy failed to reach backend auth endpoint",
        detail: String(error?.message || error),
      },
      { status: 502 }
    );
  }
}
TS

echo "=== Patch google-success page to call same-origin proxy ==="

python3 <<'PY'
from pathlib import Path
import re

p = Path("app/auth/google-success/page.tsx")
s = p.read_text()

# Replace any direct backend auth fetch with same-origin proxy.
s = re.sub(
    r'fetch\(\s*`\$\{API_URL\}/api/auth/google/token`\s*,',
    'fetch(`/api/auth-google-token`,',
    s
)

s = re.sub(
    r'fetch\(\s*["\']https://[^"\']+/api/auth/google/token["\']\s*,',
    'fetch(`/api/auth-google-token`,',
    s
)

# Keep API_URL const harmless if still present, but no browser direct backend call.
p.write_text(s)
print("✅ google-success now uses /api/auth-google-token")
PY

echo "=== Check patched files ==="
grep -Rni "auth-google-token\|google/token\|Failed to fetch" app/auth/google-success app/api/auth-google-token || true

echo "=================================================="
echo "DONE. Now build and deploy frontend."
echo "=================================================="
