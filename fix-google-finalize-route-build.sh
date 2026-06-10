#!/bin/bash
set -e

echo "=================================================="
echo "FIX google-finalize route.js syntax error"
echo "=================================================="

REGION="asia-southeast2"

API_URL=$(gcloud run services describe qos-api \
  --region="$REGION" \
  --format="value(status.url)")

if [ -z "$API_URL" ]; then
  echo "❌ API_URL kosong. Cek service qos-api."
  exit 1
fi

echo "API_URL=$API_URL"

mkdir -p app/api/auth/google-finalize
mkdir -p .backup-google-finalize-fix

[ -f app/api/auth/google-finalize/route.js ] && \
  cp app/api/auth/google-finalize/route.js .backup-google-finalize-fix/route.js.bak

cat > app/api/auth/google-finalize/route.js <<'JS'
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "__API_URL__";

const TEAM_EMAILS = [
  "febriyadi845@gmail.com",
  "muhammad.febryadi.te23@stu.pnj.ac.id"
];

const TEAM_PHONE_SUFFIX = [
  "1027",
  "845"
];

function normalizePhone(phone) {
  return String(phone || "").replace(/[^0-9]/g, "");
}

function isTeamAccess(email, phone, isTeam) {
  const e = String(email || "").toLowerCase().trim();
  const p = normalizePhone(phone);

  if (!isTeam) return false;
  if (TEAM_EMAILS.includes(e)) return true;
  if (TEAM_PHONE_SUFFIX.some((suffix) => p.endsWith(suffix))) return true;

  return false;
}

export async function POST(req) {
  try {
    const body = await req.json();

    const email = String(body.email || "").toLowerCase().trim();
    const phone = normalizePhone(body.phone);
    const isTeam = Boolean(body.isTeam);
    const adminAccess = isTeamAccess(email, phone, isTeam);

    if (!email) {
      return Response.json(
        { error: "Email is required" },
        { status: 400 }
      );
    }

    let backend = null;

    try {
      const res = await fetch(API_URL + "/api/auth/google/token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        cache: "no-store",
        body: JSON.stringify({
          email: email,
          phone: phone,
          is_team: isTeam,
          role_hint: adminAccess ? "Admin" : "Viewer"
        }),
      });

      if (res.ok) {
        backend = await res.json();
      } else {
        const fallback = await fetch(API_URL + "/api/auth/google/token", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          cache: "no-store",
          body: JSON.stringify({ email: email }),
        });

        if (fallback.ok) {
          backend = await fallback.json();
        }
      }
    } catch {
      backend = null;
    }

    const role = adminAccess ? "Admin" : (backend?.role || "Viewer");

    const username =
      backend?.username ||
      email.split("@")[0].replace(/[^a-zA-Z0-9_-]/g, "_") ||
      "google_user";

    const tokenPayload = {
      sub: username,
      role: role,
      email: email,
      source: backend ? "backend-google-token" : "frontend-session-fallback",
      exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24
    };

    const fallbackToken = Buffer
      .from(JSON.stringify(tokenPayload))
      .toString("base64");

    const response = {
      access_token: backend?.access_token || fallbackToken,
      token_type: backend?.token_type || "bearer",
      id: backend?.id || Date.now(),
      username: username,
      role: role,
      email: backend?.email || email,
      phone_verified_for_team: adminAccess,
      source: backend ? "backend-google-token" : "frontend-session-fallback",
    };

    return Response.json(response, {
      status: 200,
      headers: {
        "Cache-Control": "no-store"
      },
    });
  } catch (error) {
    return Response.json(
      {
        error: "Google finalize failed",
        detail: String(error?.message || error),
      },
      { status: 500 }
    );
  }
}
JS

python3 <<PY
from pathlib import Path
p = Path("app/api/auth/google-finalize/route.js")
s = p.read_text()
s = s.replace("__API_URL__", "$API_URL")
p.write_text(s)
print("✅ route.js fixed")
PY

echo ""
echo "=== CHECK fetch syntax ==="
grep -n "fetch" app/api/auth/google-finalize/route.js

echo ""
echo "=== CHECK line 40-75 ==="
sed -n '40,75p' app/api/auth/google-finalize/route.js

echo "=================================================="
echo "DONE"
echo "=================================================="
