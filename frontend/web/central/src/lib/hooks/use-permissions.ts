"use client";

import { useAuthStore } from "@/lib/stores/auth-store";
import {
  hasPermission,
  type PermissionCode,
} from "@/lib/permissions/model";

/** Returns a `can(code)` checker bound to the current user. */
export function usePermissions() {
  const user = useAuthStore((s) => s.user);
  return {
    can: (code: PermissionCode) =>
      hasPermission(user?.role, user?.permissions, code),
    role: user?.role ?? null,
    isGM: user?.role === "general_manager",
  };
}
