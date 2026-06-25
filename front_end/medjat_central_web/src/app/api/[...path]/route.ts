import { NextRequest, NextResponse } from "next/server";

/**
 * BFF proxy. All browser→backend traffic goes through here so backend Basic-auth
 * credentials (SECURITY_USER / SECURITY_KEY) never reach the browser (SC-006).
 *
 * Beyond farkha_web's Authorization-only proxy, the Medjat backend authenticates the
 * user/tenant via custom headers, so we also forward (when present on the incoming
 * request):
 *   - X-Firebase-Token  (Firebase ID token)
 *   - X-Tenant-Id       (selected company id)
 *   - X-Device-Id       (stable per-browser id)
 * while injecting `Authorization: Basic …` server-side.
 */
const API_HOST =
  process.env.NEXT_PUBLIC_API_HOST ?? "https://api.medjatapp.com/backend_medjet";

const SECURITY_USER = process.env.SECURITY_USER ?? "";
const SECURITY_KEY = process.env.SECURITY_KEY ?? "";

/** Headers we forward from the browser request to the backend. */
const PASSTHROUGH_HEADERS = [
  "x-firebase-token",
  "x-tenant-id",
  "x-device-id",
] as const;

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  return proxyRequest(request, path);
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  return proxyRequest(request, path);
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers":
        "Authorization, Content-Type, X-Firebase-Token, X-Tenant-Id, X-Device-Id",
    },
  });
}

async function proxyRequest(request: NextRequest, pathSegments: string[]) {
  const path = pathSegments.join("/");
  const url = `${API_HOST}/${path}`;

  const searchParams = request.nextUrl.searchParams.toString();
  const fullUrl = searchParams ? `${url}?${searchParams}` : url;

  const contentType = request.headers.get("content-type");
  const headers: Record<string, string> = {
    Authorization: `Basic ${btoa(`${SECURITY_USER}:${SECURITY_KEY}`)}`,
    "Content-Type": contentType ?? "application/json",
  };

  // Forward Medjat-specific auth/tenant/device headers from the browser.
  for (const name of PASSTHROUGH_HEADERS) {
    const value = request.headers.get(name);
    if (value) headers[name] = value;
  }

  const body = ["POST", "PUT", "PATCH"].includes(request.method)
    ? await request.text()
    : undefined;

  try {
    const res = await fetch(fullUrl, {
      method: request.method,
      headers,
      body,
      signal: AbortSignal.timeout(30000),
    });

    const data = await res.text();
    return new NextResponse(data, {
      status: res.status,
      headers: {
        "Content-Type":
          res.headers.get("Content-Type") ?? "application/json",
      },
    });
  } catch (error) {
    console.error("[BFF proxy error]", error);
    return NextResponse.json(
      {
        error: "Service temporarily unavailable",
        ...(process.env.NODE_ENV === "development" && {
          details: String(error),
        }),
      },
      { status: 500 },
    );
  }
}
