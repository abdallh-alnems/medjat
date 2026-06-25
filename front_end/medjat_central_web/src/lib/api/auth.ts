import { apiGet, apiPost } from "./client";
import type { Admin, NotificationPrefs } from "@/lib/types";

/** Firebase ID token → backend session + user/tenant context. */
export function login(idToken: string) {
  return apiPost<{
    user?: Admin;
    tenant_id?: number | null;
    tenant_name?: string | null;
    // The live backend nests the tenant as an object; mocks send tenant_id/name flat.
    tenant?: { id: number; name: string } | null;
    message?: string;
    status?: string;
  }>("app/auth/login.php", { token: idToken });
}

export function logout() {
  return apiPost<{ status?: string }>("app/auth/logout.php");
}

export function sendVerification(email?: string) {
  return apiPost<{ status?: string }>("app/auth/send_verification.php", {
    email,
  });
}

export function sendPasswordReset(email: string) {
  return apiPost<{ status?: string }>("app/auth/send_password_reset.php", {
    email,
  });
}

export function updateProfile(data: Partial<Pick<Admin, "name" | "phone">>) {
  return apiPost<{ user?: Admin }>("app/auth/update_profile.php", data);
}

export function getNotificationPrefs() {
  return apiGet<NotificationPrefs>("app/auth/notification_prefs.php");
}

export function setNotificationPrefs(prefs: NotificationPrefs) {
  return apiPost<NotificationPrefs>("app/auth/notification_prefs.php", prefs);
}

export function deleteAccount(password?: string) {
  return apiPost<{ status?: string; last_gm?: boolean }>(
    "app/auth/delete_account.php",
    { password },
  );
}

export function me() {
  return apiGet<{ user?: Admin; tenant_id?: number | null }>(
    "app/auth/login.php",
  );
}
