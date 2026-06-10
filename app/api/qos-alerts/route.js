export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET() {
  try {
    const res = await fetch(API_URL + "/api/alerts", { cache: "no-store" });
    const data = await res.json();

    return Response.json(Array.isArray(data) ? data : [], {
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return Response.json([], {
      headers: { "Cache-Control": "no-store" },
    });
  }
}
