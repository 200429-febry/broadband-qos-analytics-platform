export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET(req) {
  const url = new URL(req.url);
  const sizeKb = url.searchParams.get("size_kb") || "512";

  try {
    const res = await fetch(
      API_URL + "/api/qoe/download-fixed?size_kb=" + encodeURIComponent(sizeKb) + "&x=" + Date.now(),
      { cache: "no-store" }
    );

    const buffer = await res.arrayBuffer();

    return new Response(buffer, {
      status: 200,
      headers: {
        "Content-Type": "application/octet-stream",
        "Cache-Control": "no-store",
        "Content-Length": String(buffer.byteLength),
        "X-Probe-Proxy": "frontend-same-origin",
      },
    });
  } catch (e) {
    return Response.json({ ok: false, error: String(e?.message || e) }, { status: 500 });
  }
}
