"use client";

import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { AppShell } from "@/components/layout/app-shell";
import { LoadingState, EmptyState } from "@/components/ui/states";
import { useAuthStore } from "@/lib/stores/auth-store";
import { useTenantStore } from "@/lib/stores/tenant-store";
import { hasPermission, type PermissionCode } from "@/lib/permissions/model";
import { useT } from "@/lib/i18n/use-t";

/**
 * Route → required permission map. A restricted admin hitting any of these
 * (even via a direct URL) is blocked (SC-008). Client checks are UX-only; the
 * backend remains the authoritative enforcer.
 */
const ROUTE_PERMISSIONS: { match: string; permission: PermissionCode }[] = [
  { match: "/employees", permission: "manage_employees" },
  { match: "/terminated", permission: "manage_employees" },
  { match: "/attendance", permission: "manage_attendance" },
  { match: "/payroll", permission: "manage_payroll" },
  { match: "/loans", permission: "manage_payroll" },
  { match: "/leaves", permission: "manage_leaves" },
  { match: "/breaks", permission: "manage_leaves" },
  { match: "/branches", permission: "manage_company_settings" },
  { match: "/shifts", permission: "manage_company_settings" },
  { match: "/settings", permission: "manage_company_settings" },
  { match: "/team", permission: "add_managers" },
  { match: "/activity-log", permission: "manage_company_settings" },
];

function routePermission(pathname: string): PermissionCode | null {
  // Find the longest matching prefix so /settings/company matches /settings.
  let best: PermissionCode | null = null;
  let bestLen = 0;
  for (const r of ROUTE_PERMISSIONS) {
    if (pathname === r.match || pathname.startsWith(`${r.match}/`)) {
      if (r.match.length > bestLen) {
        best = r.permission;
        bestLen = r.match.length;
      }
    }
  }
  return best;
}

/**
 * Auth + tenant guard for the authenticated `(app)` shell.
 *  - Not logged in → /login
 *  - Logged in but no tenant (and not already on /onboarding) → /onboarding
 *  - /onboarding itself is allowed without a tenant (sets it during the flow)
 *  - Restricted route without permission → access-denied screen (SC-008)
 *  - Waits for persisted Zustand stores to hydrate before deciding.
 */
export function AppGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const { t } = useT();
  const [hydrated, setHydrated] = useState(false);
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const user = useAuthStore((s) => s.user);
  const tenantId = useTenantStore((s) => s.tenantId);

  useEffect(() => {
    // Zustand persisted stores hydrate on the client; flip the flag once mounted.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    if (!isLoggedIn) {
      router.replace("/login");
      return;
    }
    const hasTenant = !!user?.tenantId || !!tenantId;
    if (!hasTenant && pathname !== "/onboarding") {
      router.replace("/onboarding");
    }
  }, [hydrated, isLoggedIn, user, tenantId, pathname, router]);

  if (!hydrated || !isLoggedIn) {
    return <LoadingState />;
  }
  const hasTenant = !!user?.tenantId || !!tenantId;
  // Onboarding is reachable without a tenant; everything else requires one.
  if (!hasTenant && pathname !== "/onboarding") {
    return <LoadingState />;
  }

  const required = routePermission(pathname);
  if (
    required &&
    !hasPermission(user?.role, user?.permissions ?? null, required)
  ) {
    return (
      <AppShell>
        <EmptyState message={t("restricted_access_message")} />
      </AppShell>
    );
  }

  return <AppShell>{children}</AppShell>;
}
