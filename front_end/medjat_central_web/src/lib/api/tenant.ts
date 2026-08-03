import { apiPost } from "./client";

/**
 * The current Firebase ID token, fetched lazily (dynamic import) so this module
 * never pulls firebase into the graph at import time — keeps unit tests and SSR
 * safe. Mirrors the lazy pattern in the API client interceptor.
 */
async function firebaseIdToken(): Promise<string | null> {
  try {
    const { auth } = await import("@/lib/firebase/config");
    await auth.authStateReady?.();
    return (await auth.currentUser?.getIdToken()) ?? null;
  } catch {
    return null;
  }
}

/** Shared shape of the onboarding endpoints (create / join / accept). */
export interface OnboardingResult {
  success?: boolean;
  tenant?: {
    id: number;
    name: string;
    currency?: string;
    timezone?: string;
  } | null;
  user?: {
    id: number;
    tenant_id: number;
    role: string;
    role_key: string;
    branch_id?: number | null;
  };
  message?: string;
  error_code?: string;
}

// The backend onboarding endpoints verify the Firebase token from the request
// body (they run before a tenant context exists), so we send it explicitly.

/**
 * Locale settings are sent at creation so the company never runs on a guessed
 * default — the backend treats them as optional and falls back to the column
 * defaults, which is what older app builds still rely on.
 */
export async function createCompany(
  name: string,
  locale?: {
    timezone: string;
    currency: string;
    cycle_start_day: number;
    week_start_day: number;
  },
) {
  const token = await firebaseIdToken();
  return apiPost<OnboardingResult>("app/tenant/create.php", {
    token,
    company_name: name,
    ...(locale ?? {}),
  });
}

export async function joinCompany(code: string) {
  const token = await firebaseIdToken();
  return apiPost<OnboardingResult>("app/tenant/join.php", {
    token,
    invite_code: code,
  });
}

/** Accept a pending invitation addressed to the signed-in email (no code). */
export async function acceptInvitation(invitationId?: number) {
  const token = await firebaseIdToken();
  return apiPost<OnboardingResult>("app/tenant/accept_invitation.php", {
    token,
    ...(invitationId ? { invitation_id: invitationId } : {}),
  });
}
