"use client";

import { useCallback, useEffect } from "react";
import {
  onAuthChange,
  signOut as fbSignOut,
} from "@/lib/firebase/auth";
import { login as apiLogin, logout as apiLogout } from "@/lib/api/auth";
import { useAuthStore } from "@/lib/stores/auth-store";
import { useTenantStore } from "@/lib/stores/tenant-store";

/**
 * Orchestrates the full auth lifecycle:
 *  - Firebase sign-in → v1/auth/admin/login → set user + tenant
 *  - onAuthStateChanged(null) → clear session
 *  - logout → backend logout + Firebase signOut + clear stores
 *  - surfaces "session superseded" responses by signing out
 */
export function useAuth() {
  const user = useAuthStore((s) => s.user);
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const setUser = useAuthStore((s) => s.setUser);
  const setPendingInvitation = useAuthStore((s) => s.setPendingInvitation);
  const logoutStore = useAuthStore((s) => s.logout);
  const setTenant = useTenantStore((s) => s.setTenant);
  const clearTenant = useTenantStore((s) => s.clearTenant);

  // React to Firebase auth state. When a user signs in elsewhere we keep the store
  // as the source of truth; when Firebase reports null we clear the session.
  useEffect(() => {
    const unsub = onAuthChange((fbUser) => {
      if (!fbUser) {
        // Only clear if we thought we were logged in (avoid wiping a fresh load).
        if (useAuthStore.getState().isLoggedIn) {
          logoutStore();
          clearTenant();
        }
      }
    });
    return () => unsub();
  }, [logoutStore, clearTenant]);

  /** Complete sign-in: exchange Firebase token → backend session + stores. */
  const completeLogin = useCallback(async () => {
    const { auth } = await import("@/lib/firebase/config");
    const fbUser = auth.currentUser;
    if (!fbUser) throw new Error("Not signed in");
    const idToken = await fbUser.getIdToken();
    const res = await apiLogin(idToken);

    // "Session superseded" → force sign out.
    if (res.status === "superseded" || res.status === "unauthorized") {
      await fbSignOut();
      logoutStore();
      clearTenant();
      throw new Error(res.message ?? "session_expired");
    }

    if (res.user) {
      setUser({
        id: res.user.id ?? null,
        name: res.user.name ?? null,
        email: res.user.email ?? null,
        phone: res.user.phone ?? null,
        photoUrl: res.user.photo_url ?? null,
        firebaseUid: res.user.firebase_uid ?? null,
        role: res.user.role ?? null,
        branchId: res.user.branch_id ?? null,
        isActive: res.user.is_active ?? true,
        tenantId: res.user.tenant_id ?? null,
        permissions: res.user.permissions ?? null,
      });
      // Tenant id/name may arrive flat (mocks) or nested on the live backend.
      const tenantId =
        res.tenant_id ?? res.tenant?.id ?? res.user?.tenant_id ?? null;
      const tenantName = res.tenant_name ?? res.tenant?.name ?? undefined;
      if (tenantId) {
        setTenant(tenantId, tenantName);
      } else {
        clearTenant();
      }
      // No company yet → remember any invitation waiting for this email so the
      // onboarding screen can offer a one-tap "Join {company}".
      setPendingInvitation(tenantId ? null : (res.pending_invitation ?? null));
    }
    return res;
  }, [setUser, setTenant, clearTenant, logoutStore, setPendingInvitation]);

  const logout = useCallback(async () => {
    try {
      await apiLogout();
    } catch {
      /* best effort */
    }
    try {
      await fbSignOut();
    } catch {
      /* ignore */
    }
    logoutStore();
    clearTenant();
  }, [logoutStore, clearTenant]);

  return {
    user,
    isLoggedIn,
    hasTenant: !!user?.tenantId || !!useTenantStore.getState().tenantId,
    completeLogin,
    logout,
  };
}
