export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function POST(req) {
  try {
    const body = await req.json();

    const res = await fetch(API_URL + "/api/qoe/device-sample", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      cache: "no-store",
      body: JSON.stringify(body),
    });

    const text = await res.text();

    let data;
    try {
      data = JSON.parse(text);
    } catch {
      data = { raw: text };
    }

    return Response.json({
      ok: res.ok,
      backend_status: res.status,
      backend: data,
    }, {
      status: res.ok ? 200 : 502,
      headers: { "Cache-Control": "no-store" },
    });
  } catch (e) {
    return Response.json({ ok: false, error: String(e?.message || e) }, { status: 500 });
  }
}
