export const dynamic = "force-dynamic";
export const revalidate = 0;
export const runtime = "nodejs";

const API_URL = "https://qos-api-gh3tn2a6oa-et.a.run.app";

export async function POST(request: Request) {
  try {
    const body = await request.text();

    const response = await fetch(`${API_URL}/api/auth/google/token`, {
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
