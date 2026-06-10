export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET() {
  const start = Date.now();

  try {
    const res = await fetch(API_URL + "/api/qoe/ping?x=" + Date.now(), {
      cache: "no-store",
    });

    const data = await res.json();

    return Response.json({
      ok: true,
      frontend_proxy_ms: Date.now() - start,
      backend: data,
    }, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch (e) {
    return Response.json({
      ok: false,
      error: String(e?.message || e),
      frontend_proxy_ms: Date.now() - start,
    }, { status: 500 });
  }
}
