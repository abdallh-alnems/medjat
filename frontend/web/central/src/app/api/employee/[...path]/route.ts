import { NextRequest, NextResponse } from "next/server";
import { EMPLOYEE_SESSION_COOKIE } from "../session/route";

/**
 * Proxy for authenticated employee calls.
 *
 * Reads the httpOnly session cookie server-side and presents it to the backend
 * as `X-Employee-Token`, so the token never exists in the page's JavaScript.
 * Basic credentials are injected here for the same reason they are in the admin
 * proxy: they must not reach the browser.
 */

const API_HOST =
  process.env.NEXT_PUBLIC_API_HOST ?? "https://api.medjatapp.com/backend";

const SECURITY_USER = process.env.SECURITY_USER ?? "";
const SECURITY_KEY = process.env.SECURITY_KEY ?? "";

/**
 * Explicit allow-list. Without it this route is an open relay into every backend
 * endpoint, reachable by anyone holding an employee session — including admin
 * paths that only expect to be called by the other proxy.
 */
const ALLOWED_PATHS = new Set([
  "v1/attendance/web-status",
  "v1/attendance/check-in",
  "v1/attendance/check-out",
]);

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  const target = path.join("/");

  if (!ALLOWED_PATHS.has(target)) {
    return NextResponse.json({ error: "not_allowed" }, { status: 404 });
  }

  const token = request.cookies.get(EMPLOYEE_SESSION_COOKIE)?.value;
  if (!token) {
    return NextResponse.json({ error: "no_session" }, { status: 401 });
  }

  const body = await request.text();

  try {
    const upstream = await fetch(`${API_HOST}/${target}`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${SECURITY_USER}:${SECURITY_KEY}`)}`,
        "Content-Type": "application/json",
        "X-Employee-Token": token,
      },
      body: body || "{}",
    });

    const text = await upstream.text();
    const response = new NextResponse(text, {
      status: upstream.status,
      headers: { "Content-Type": "application/json" },
    });

    // A 401 from the backend means the session is gone — expired, revoked, or
    // ended by the check-out that just succeeded. Clearing the cookie here stops
    // the page from looking signed-in while every call fails.
    if (upstream.status === 401) {
      response.cookies.delete(EMPLOYEE_SESSION_COOKIE);
    }

    return response;
  } catch (error) {
    console.error("employee proxy failed", error);
    return NextResponse.json({ error: "upstream_unreachable" }, { status: 502 });
  }
}
