import { apiGet, apiPost, unwrapList } from "./client";
import type { Admin, ManagerInvitation } from "@/lib/types";

export interface InviteAdminInput {
  email: string;
  role: string;
  name?: string;
  branch_id?: number | null;
  /** Custom permission codes chosen at invite time. Omit to use role defaults. */
  permissions?: string[];
}

export interface InviteAdminResult {
  invitation_id: number;
  invitation_code: string;
  expires_at: string;
  expires_in_hours: number;
}

export function inviteAdmin(data: InviteAdminInput) {
  return apiPost<InviteAdminResult>("app/managers/invite.php", data);
}

export async function listInvitations(): Promise<ManagerInvitation[]> {
  // All invitations; the page filters by status client-side (matches the app).
  const raw = await apiGet<unknown>("app/managers/list_invitations.php");
  return unwrapList<ManagerInvitation>(raw, ["items", "data"]);
}

export function cancelInvitation(id: number) {
  // Backend reads the id from the query string ($_GET['id']).
  return apiPost<{ status?: string }>(
    `app/managers/cancel_invitation.php?id=${id}`,
  );
}

export function resendInvitation(id: number) {
  // Returns a freshly generated code + new expiry.
  return apiPost<{
    invitation_id: number;
    invitation_code: string;
    expires_at: string;
    expires_in_hours: number;
    message?: string;
  }>("app/managers/resend_invitation.php", { id });
}

export async function listAdmins(): Promise<Admin[]> {
  // Backend returns `{ items }`.
  const raw = await apiGet<unknown>("app/managers/list_admins.php");
  return unwrapList<Admin>(raw, ["items", "data"]);
}

// The write endpoints all key on `admin_id` (and `is_active`) — not `id`.
export function updateAdmin(
  id: number,
  data: { role?: string; branch_id?: number | null },
) {
  return apiPost<{ status?: string }>("app/managers/update_admin.php", {
    admin_id: id,
    ...data,
  });
}

export function setAdminActive(id: number, active: boolean) {
  return apiPost<{ status?: string }>("app/managers/set_admin_active.php", {
    admin_id: id,
    is_active: active,
  });
}

export function removeAdmin(id: number) {
  return apiPost<{ status?: string }>("app/managers/remove_admin.php", {
    admin_id: id,
  });
}

export interface AdminPermissions {
  admin_id: number;
  role: string;
  role_defaults: string[];
  effective_permissions: string[];
  is_customized: boolean;
  all_permissions: string[];
}

export function getAdminPermissions(adminId: number) {
  return apiGet<AdminPermissions>("app/managers/get_admin_permissions.php", {
    admin_id: adminId,
  });
}

export function updateAdminPermissions(adminId: number, permissions: string[]) {
  // Backend expects an array of permission codes.
  return apiPost<{ status?: string }>(
    "app/managers/update_admin_permissions.php",
    { admin_id: adminId, permissions },
  );
}

export function resetAdminPermissions(adminId: number) {
  return apiPost<{ status?: string }>(
    "app/managers/reset_admin_permissions.php",
    { admin_id: adminId },
  );
}
