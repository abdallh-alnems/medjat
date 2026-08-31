import axios, {
  type AxiosInstance,
  type AxiosRequestConfig,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from "axios";

const API_HOST =
  process.env.NEXT_PUBLIC_API_HOST ?? "https://api.medjatapp.com/backend";

const SECURITY_USER = process.env.SECURITY_USER ?? "";
const SECURITY_KEY = process.env.SECURITY_KEY ?? "";

// These are server-only credentials (not exposed to the browser bundle), so only
// warn on the server where serverClient actually needs them. The browser routes
// through the /api proxy and never reads these.
if (typeof window === "undefined" && (!SECURITY_USER || !SECURITY_KEY)) {
  console.warn(
    "SECURITY_USER and SECURITY_KEY are not set — server-side API calls will fail authentication.",
  );
}

/** Server-side client (Basic auth injected directly; used in server components). */
const serverClient: AxiosInstance = axios.create({
  baseURL: API_HOST,
  headers: {
    Authorization: `Basic ${btoa(`${SECURITY_USER}:${SECURITY_KEY}`)}`,
    "Content-Type": "application/json",
  },
});

/** Browser client — baseURL `/api` so all calls go through the proxy. */
const browserClient: AxiosInstance = axios.create({
  baseURL: "/api",
  headers: {
    "Content-Type": "application/json",
  },
});

/**
 * Request interceptor (browser only): attach the current Firebase ID token, tenant id,
 * and stable device id on every call. The proxy forwards them to the backend.
 *
 * Token/tenant/device are read lazily (via dynamic import) to avoid circular deps with
 * firebase/auth and the zustand stores.
 */
async function attachMedjatHeaders(
  config: InternalAxiosRequestConfig,
): Promise<InternalAxiosRequestConfig> {
  if (typeof window === "undefined") return config;

  try {
    const { auth } = await import("@/lib/firebase/config");
    // Wait for Firebase to finish restoring the persisted session before reading
    // the current user. On a hard refresh `auth.currentUser` is briefly null
    // while the SDK rehydrates, so without this the first request after a reload
    // goes out unauthenticated — the backend returns an error and list pages
    // render empty ("no records") until the next navigation.
    await auth.authStateReady();
    const currentUser = auth.currentUser;
    if (currentUser) {
      const token = await currentUser.getIdToken();
      if (token) config.headers.set("X-Firebase-Token", token);
    }
  } catch {
    /* firebase not ready yet — header omitted */
  }

  try {
    const { useTenantStore } = await import("@/lib/stores/tenant-store");
    const { useAuthStore } = await import("@/lib/stores/auth-store");
    // Prefer the explicitly selected tenant; fall back to the logged-in user's
    // tenant so a session restored from persistence (where setTenant never ran)
    // still scopes its requests.
    const tenantId =
      useTenantStore.getState().tenantId ??
      useAuthStore.getState().user?.tenantId ??
      null;
    if (tenantId) config.headers.set("X-Tenant-Id", String(tenantId));
  } catch {
    /* stores not hydrated yet */
  }

  config.headers.set("X-Device-Id", getDeviceId());
  return config;
}

browserClient.interceptors.request.use(attachMedjatHeaders);

/**
 * Unwrap the backend success envelope. The Medjat backend wraps every successful
 * payload as `{ status: "success", data: <payload> }` (see the ApiResponse envelope), while
 * the whole frontend (and its contract mocks) treats the JSON body itself as the typed
 * payload. So on a 2xx success envelope we hoist `data` up to be the response body.
 * Error/fail/superseded bodies (`status !== "success"`) are left untouched so callers
 * can still read `status`/`message`. Non-2xx are also resolved (matches farkha) so
 * callers can read error bodies.
 */
const onFulfilled = (response: AxiosResponse) => {
  const body = response.data;
  if (
    body &&
    typeof body === "object" &&
    !Array.isArray(body) &&
    (body as { status?: string }).status === "success" &&
    "data" in (body as Record<string, unknown>)
  ) {
    response.data = (body as { data: unknown }).data;
  }
  return response;
};
/**
 * Force a sign-out when the backend invalidates this device's session and bounce
 * to /login (instead of leaving the user on a generic "try again" error):
 *  - `session_superseded` (401): the admin signed in on another device.
 *  - `account_removed` / `account_deactivated` (403): the admin was removed from
 *    the company or suspended.
 */
let handlingForceLogout = false;
async function forceLogout(message: string) {
  try {
    const [{ useAuthStore }, { useTenantStore }, { auth }] = await Promise.all([
      import("@/lib/stores/auth-store"),
      import("@/lib/stores/tenant-store"),
      import("@/lib/firebase/config"),
    ]);
    try {
      await auth.signOut();
    } catch {
      /* ignore */
    }
    useAuthStore.getState().logout();
    useTenantStore.getState().clearTenant();
  } catch {
    /* stores/firebase unavailable */
  }
  try {
    const { toast } = await import("sonner");
    toast.error(message);
  } catch {
    /* ignore */
  }
  if (window.location.pathname !== "/login") {
    window.location.href = "/login";
  }
}

const onRejected = (error: unknown) => {
  if (axios.isAxiosError(error) && error.response) {
    const res = error.response;
    const body = res.data as
      | { error_code?: string; message?: string }
      | undefined;
    const code = body?.error_code;
    if (typeof window !== "undefined" && !handlingForceLogout) {
      if (res.status === 401 && code === "session_superseded") {
        handlingForceLogout = true;
        void forceLogout(body?.message || "تم تسجيل الدخول من جهاز آخر");
      } else if (
        (res.status === 403 || res.status === 401) &&
        (code === "account_removed" || code === "account_deactivated")
      ) {
        handlingForceLogout = true;
        void forceLogout(
          body?.message || "تمت إزالتك من الشركة من قِبل المسؤول",
        );
      }
    }
    return res;
  }
  return Promise.reject(error);
};
browserClient.interceptors.response.use(onFulfilled, onRejected);
serverClient.interceptors.response.use(onFulfilled, onRejected);

export const apiClient: AxiosInstance =
  typeof window !== "undefined" ? browserClient : serverClient;

export async function apiGet<T>(
  endpoint: string,
  params?: object,
) {
  const res = await apiClient.get<T>(endpoint, {
    params: params as Record<string, unknown> | undefined,
  });
  return res.data;
}

export async function apiPost<T>(
  endpoint: string,
  data?: Record<string, unknown> | object,
  config?: AxiosRequestConfig,
) {
  const res = await apiClient.post<T>(endpoint, data, config);
  return res.data;
}

/**
 * Replaces part of a resource. The id goes in the path, not the body: the API
 * addresses resources rather than taking an action named "update".
 */
export async function apiPatch<T>(
  endpoint: string,
  data?: Record<string, unknown> | object,
  config?: AxiosRequestConfig,
) {
  const res = await apiClient.patch<T>(endpoint, data, config);
  return res.data;
}

export async function apiDelete<T>(endpoint: string, config?: AxiosRequestConfig) {
  const res = await apiClient.delete<T>(endpoint, config);
  return res.data;
}

/**
 * Pull the array out of a backend list payload. The Medjat backend wraps list
 * results under a top-level key that varies per endpoint (`items`, `records`,
 * `branches`, `breaks`, `tickets`, …) *inside* the success envelope. Once the
 * envelope is unwrapped (see onFulfilled) the caller is left with
 * `{ <key>: [...], ...meta }` rather than a bare array — so a page that does
 * `Array.isArray(data) ? data : []` silently renders an empty list.
 *
 * Given the candidate keys, return the first array found. Tolerate a payload
 * that is already an array, and return `[]` for null / error / permission-denied
 * bodies so callers never crash on `.map`.
 */
export function unwrapList<T>(
  payload: unknown,
  keys: readonly string[] = ["items", "data", "records", "rows", "results"],
): T[] {
  if (Array.isArray(payload)) return payload as T[];
  if (payload && typeof payload === "object") {
    for (const key of keys) {
      const value = (payload as Record<string, unknown>)[key];
      if (Array.isArray(value)) return value as T[];
    }
  }
  return [];
}

/**
 * Narrow an unknown payload to a plain object (not null, not an array), or null.
 * Used by the single-object adapters to validate a backend response shape at
 * runtime before casting, instead of trusting `as Type` blindly.
 */
export function asObject(payload: unknown): Record<string, unknown> | null {
  return payload !== null &&
    typeof payload === "object" &&
    !Array.isArray(payload)
    ? (payload as Record<string, unknown>)
    : null;
}

/** Stable per-browser device id, generated once and stored in localStorage. */
export function getDeviceId(): string {
  if (typeof window === "undefined") return "ssr";
  const KEY = "medjat-device-id";
  try {
    let id = window.localStorage?.getItem?.(KEY);
    if (!id) {
      id = `web-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
      window.localStorage?.setItem?.(KEY, id);
    }
    return id;
  } catch {
    // Storage unavailable (private mode / test env) — fall back to a session id.
    return `web-session-${Math.random().toString(36).slice(2, 10)}`;
  }
}

export { API_HOST };
