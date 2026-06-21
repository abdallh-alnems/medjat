import axios, {
  type AxiosInstance,
  type AxiosRequestConfig,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from "axios";

const API_HOST =
  process.env.NEXT_PUBLIC_API_HOST ?? "https://api.medjat.com/backend_medjat";

const SECURITY_USER = process.env.SECURITY_USER ?? "";
const SECURITY_KEY = process.env.SECURITY_KEY ?? "";

if (!SECURITY_USER || !SECURITY_KEY) {
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
    const tenantId = useTenantStore.getState().tenantId;
    if (tenantId) config.headers.set("X-Tenant-Id", String(tenantId));
  } catch {
    /* tenant store not hydrated yet */
  }

  config.headers.set("X-Device-Id", getDeviceId());
  return config;
}

browserClient.interceptors.request.use(attachMedjatHeaders);

/** Treat non-2xx as resolved responses (so callers can read error bodies) — matches farkha. */
const onFulfilled = (response: AxiosResponse) => response;
const onRejected = (error: unknown) => {
  if (axios.isAxiosError(error) && error.response) return error.response;
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
