import { NextRequest, NextResponse } from "next/server";

/**
 * Establishes and ends an employee's browser session.
 *
 * The session token is put in an **httpOnly** cookie and never returned to the
 * page. localStorage would be readable by any script that lands on the page,
 * and this surface shares an origin with the admin application — so the token
 * is kept somewhere script cannot reach it at all.
 *
 * The backend's Basic credentials stay server-side here, exactly as they do in
 * the main proxy.
 */

const API_HOST =
  process.env.NEXT_PUBLIC_API_HOST ?? "https://api.medjatapp.com/backend/api";

const SECURITY_USER = process.env.SECURITY_USER ?? "";
const SECURITY_KEY = process.env.SECURITY_KEY ?? "";

export const EMPLOYEE_SESSION_COOKIE = "medjat_emp_session";

/** Endpoints this route is allowed to call. An open relay would let any backend path be reached. */
const ENDPOINTS = {
  activate: "app/auth/employee_web_activate.php",
  login: "app/auth/employee_web_login.php",
} as const;

type Action = keyof typeof ENDPOINTS;

export async function POST(request: NextRequest) {
  let payload: { action?: string } & Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ error: "invalid_body" }, { status: 400 });
  }

  const { action, ...body } = payload;
  if (action !== "activate" && action !== "login") {
    return NextResponse.json({ error: "unknown_action" }, { status: 400 });
  }

  const upstream = await fetch(`${API_HOST}/${ENDPOINTS[action as Action]}`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${SECURITY_USER}:${SECURITY_KEY}`)}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const text = await upstream.text();
  let data: Record<string, unknown> = {};
  try {
    data = JSON.parse(text);
  } catch {
    // Fall through: a non-JSON body is reported as-is below rather than masked.
  }

  if (!upstream.ok) {
    return NextResponse.json(data ?? { error: text }, { status: upstream.status });
  }

  const token = (data?.data as Record<string, unknown> | undefined)?.token;
  const expiresAt = (data?.data as Record<string, unknown> | undefined)?.expires_at;

  if (typeof token !== "string" || token === "") {
    return NextResponse.json({ error: "no_token_returned" }, { status: 502 });
  }

  // The token itself is stripped from the response body. The page never needs
  // it — every later call goes back through the proxy, which reads the cookie.
  const employee = (data?.data as Record<string, unknown> | undefined)?.employee ?? null;
  const response = NextResponse.json({ employee, expires_at: expiresAt ?? null });

  response.cookies.set({
    name: EMPLOYEE_SESSION_COOKIE,
    value: token,
    httpOnly: true,
    // Secure in production only, so `npm run dev` over http still works. The
    // real deployment is HTTPS-only anyway — geolocation and camera require it.
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    // Deliberately a session cookie, with no maxAge. The server decides when the
    // session is over (check-out, or 16 hours); mirroring a lifetime here would
    // give two sources of truth that drift apart.
  });

  return response;
}

/** Ends the session: tells the backend, then clears the cookie regardless. */
export async function DELETE(request: NextRequest) {
  const token = request.cookies.get(EMPLOYEE_SESSION_COOKIE)?.value;

  if (token) {
    try {
      await fetch(`${API_HOST}/app/auth/employee_web_logout.php`, {
        method: "POST",
        headers: {
          Authorization: `Basic ${btoa(`${SECURITY_USER}:${SECURITY_KEY}`)}`,
          "Content-Type": "application/json",
          "X-Employee-Token": token,
        },
        body: "{}",
      });
    } catch {
      // The cookie is cleared below whatever happens upstream. Leaving a
      // browser "signed in" because a network call failed is the worse outcome.
    }
  }

  const response = NextResponse.json({ success: true });
  response.cookies.delete(EMPLOYEE_SESSION_COOKIE);
  return response;
}
