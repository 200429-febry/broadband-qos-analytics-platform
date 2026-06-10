export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

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
