export const dynamic = "force-dynamic";
export const revalidate = 0;

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function POST(request: Request) {
  const body = await request.text();

  const response = await fetch(`${API_URL}/api/ml/predict?x=${Date.now()}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
    cache: "no-store",
  });

  const data = await response.text();

  return new Response(data, {
    status: response.status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
