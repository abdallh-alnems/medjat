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
  permissions?: Record<PermissionCode, boolean> | Record<string, boolean> | null;
}

export type User = Admin;

export interface ManagerInvitation {
  id: number;
  email: string;
  role: AdminRole;
  branch_id?: number | null;
  code: string;
  status: "pending" | "cancelled" | "accepted";
  created_at: string;
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
