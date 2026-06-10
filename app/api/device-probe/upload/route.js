export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function POST(req) {
  const start = Date.now();

  try {
    const body = await req.arrayBuffer();

    const res = await fetch(API_URL + "/api/qoe/upload?x=" + Date.now(), {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      cache: "no-store",
      body,
    });

    const data = await res.json();

    return Response.json({
      ok: true,
      frontend_proxy_ms: Date.now() - start,
      uploaded_bytes: body.byteLength,
      backend: data,
    }, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch (e) {
    return Response.json({ ok: false, error: String(e?.message || e) }, { status: 500 });
  }
}
