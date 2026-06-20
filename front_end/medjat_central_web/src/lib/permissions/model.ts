import type { AdminRole } from "@/lib/stores/auth-store";

/** Every permission code the backend knows (mirrors RoleModel::getAvailablePermissions). */
export const PERMISSION_CODES = [
  "manage_employees",
  "manage_deduction_rules",
  "manage_attendance",
  "view_reports",
  "manage_documents",
  "documents_manage_types",
  "documents_verify",
  "documents_view_reports",
  "manage_payroll",
  "manage_leaves",
  "manage_assets",
  "add_managers",
  "manage_company_settings",
  "manage_support",
] as const;

export type PermissionCode = (typeof PERMISSION_CODES)[number];

/** Role → default permissions (`*` means all — General Manager). */
export const ROLE_DEFAULTS: Record<AdminRole, "*" | PermissionCode[]> = {
  general_manager: "*",
  hr: [
    "manage_employees",
    "manage_deduction_rules",
    "manage_attendance",
    "view_reports",
    "manage_documents",
    "manage_payroll",
    "manage_leaves",
    "manage_assets",
  ],
  branch_manager: [
    "manage_employees",
    "manage_attendance",
    "manage_documents",
    "view_reports",
    "manage_assets",
  ],
  attendance: ["manage_attendance"],
  viewer: ["view_reports"],
};

export const ALL_PERMISSIONS: PermissionCode[] = [...PERMISSION_CODES];

/**
 * Resolve whether a user has a permission. Override map (booleans keyed by code) takes
 * precedence over the role default. General Manager (`*`) has everything and is locked.
 *
 * NOTE: client checks are UX-only; the backend is the authoritative enforcer (D7).
 */
export function hasPermission(
  role: AdminRole | null | undefined,
  overrides: Record<string, boolean> | null | undefined,
  code: PermissionCode,
): boolean {
  if (!role) return false;
  if (role === "general_manager") return true;
  const defaults = ROLE_DEFAULTS[role];
  const hasDefault =
    defaults === "*" || (Array.isArray(defaults) && defaults.includes(code));
  if (overrides && code in overrides) return overrides[code] === true;
  return hasDefault;
}

/** Resolve the full effective permission map for a user (for matrix display). */
export function resolvePermissions(
  role: AdminRole | null | undefined,
  overrides: Record<string, boolean> | null | undefined,
): Record<PermissionCode, boolean> {
  const result = {} as Record<PermissionCode, boolean>;
  for (const code of ALL_PERMISSIONS) {
    result[code] = hasPermission(role, overrides, code);
  }
  return result;
}
