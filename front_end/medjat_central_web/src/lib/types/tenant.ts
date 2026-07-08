// ── Core identity & tenant ─────────────────────────────────────────────────────
import type { PermissionCode } from "@/lib/permissions/model";

export type AdminRole =
  | "general_manager"
  | "hr"
  | "branch_manager"
  | "attendance"
  | "viewer";

export interface Admin {
  id: number;
  name: string;
  email: string;
  phone?: string | null;
  photo_url?: string | null;
  firebase_uid: string;
  role: AdminRole;
  branch_id?: number | null;
  is_active: boolean;
  pending?: boolean;
  tenant_id: number;
  permissions?: Record<PermissionCode, boolean> | null;
  /** Whether the signed-in admin outranks this one and may manage them
   *  (edit / suspend / remove). Computed by the backend (`list_admins.php`). */
  can_manage?: boolean;
  branch_name?: string | null;
  last_login_at?: string | null;
}

export type User = Admin;

export interface ManagerInvitation {
  id: number;
  email: string;
  name?: string;
  role: AdminRole;
  branch_id?: number | null;
  branch_name?: string | null;
  code?: string;
  created_at: string;
  expires_at?: string;
  accepted_at?: string | null;
  cancelled_at?: string | null;
}

export interface Company {
  id: number;
  name: string;
  phone?: string | null;
  lat?: number | null;
  lng?: number | null;
  radius: number;
  attendance_methods?: AttendanceMethod[];
  address?: string | null;
}

export type AttendanceMethod = "qr_gps" | "gps_only" | "manual";
