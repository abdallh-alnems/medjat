import { apiGet, apiPost } from "./client";
import type { Admin, NotificationPrefs } from "@/lib/types";
import type { PendingInvitation } from "@/lib/stores/auth-store";

/** Firebase ID token → backend session + user/tenant context. */
export function login(idToken: string) {
  return apiPost<{
    user?: Admin;
    tenant_id?: number | null;
    tenant_name?: string | null;
    // The live backend nests the tenant as an object; mocks send tenant_id/name flat.
    tenant?: { id: number; name: string } | null;
    // Surfaced when the (company-less) user has a team invitation waiting.
    pending_invitation?: PendingInvitation | null;
    message?: string;
    status?: string;
  }>("v1/auth/admin/login", { token: idToken });
}

export function logout() {
  return apiPost<{ status?: string }>("v1/auth/admin/logout");
}

/**
 * Desktop sign-in, step 1 — called in the *browser* right after a successful
 * login that carried a ?desktop=<state> parameter. Returns a single-use code to
 * hand back to the desktop app over its medjat:// link.
 */
export function desktopAuthorize(state: string) {
  return apiPost<{ code: string; expires_in_seconds: number }>(
    "v1/auth/desktop/authorize",
    { state },
  );
}

/**
 * Desktop sign-in, step 2 — called inside the *app* window. Trades the code for
 * a Firebase custom token. Unauthenticated by design: the code is the credential.
 */
export function desktopExchange(code: string, state: string) {
  return apiPost<{ token: string }>("v1/auth/desktop/exchange", { code, state });
}

export function sendVerification(email?: string) {
  return apiPost<{ status?: string }>("v1/auth/verification", {
    email,
  });
}

export function sendPasswordReset(email: string) {
  return apiPost<{ status?: string }>("v1/auth/password-reset", {
    email,
  });
}

export function updateProfile(data: Partial<Pick<Admin, "name" | "phone">>) {
  return apiPost<{ user?: Admin }>("v1/auth/profile", data);
}

export function getNotificationPrefs() {
  return apiGet<NotificationPrefs>("v1/auth/notification-prefs");
}

export function setNotificationPrefs(prefs: NotificationPrefs) {
  return apiPost<NotificationPrefs>("v1/auth/notification-prefs", prefs);
}

export function deleteAccount(password?: string) {
  return apiPost<{ status?: string; last_gm?: boolean }>(
    "v1/auth/account",
    { password },
  );
}

