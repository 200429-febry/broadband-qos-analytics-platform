export const dynamic = "force-dynamic";
export const revalidate = 0;

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function GET() {
  const response = await fetch(`${API_URL}/api/health?x=${Date.now()}`, {
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
