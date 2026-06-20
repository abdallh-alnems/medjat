"use client";

import type { PermissionCode } from "@/lib/permissions/model";
import { usePermissions } from "@/lib/hooks/use-permissions";

interface CanProps {
  permission: PermissionCode;
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

/** Conditional render guard gated by a permission code (UX-only; backend enforces). */
export function Can({ permission, children, fallback = null }: CanProps) {
  const { can } = usePermissions();
  return <>{can(permission) ? children : fallback}</>;
}
