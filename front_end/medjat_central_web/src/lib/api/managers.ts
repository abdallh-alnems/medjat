import { apiGet, apiPost } from "./client";
import type { Admin, ManagerInvitation } from "@/lib/types";

export function inviteAdmin(data: {
  email: string;
  role: string;
  branch_id?: number | null;
}) {
  return apiPost<ManagerInvitation>("app/managers/invite.php", data);
}

export function listInvitations() {
  return apiGet<ManagerInvitation[]>("app/managers/list_invitations.php");
}

export function cancelInvitation(id: number) {
  return apiPost<{ status?: string }>("app/managers/cancel_invitation.php", { id });
}

export function resendInvitation(id: number) {
  return apiPost<{ status?: string }>("app/managers/resend_invitation.php", { id });
}

export function listAdmins() {
  return apiGet<Admin[]>("app/managers/list_admins.php");
}

export function updateAdmin(id: number, data: Partial<Admin>) {
  return apiPost<Admin>("app/managers/update_admin.php", { id, ...data });
}

export function setAdminActive(id: number, active: boolean) {
  return apiPost<{ status?: string }>("app/managers/set_admin_active.php", {
    id,
    active,
  });
}

export function removeAdmin(id: number) {
  return apiPost<{ status?: string }>("app/managers/remove_admin.php", { id });
}

export function getAdminPermissions(adminId: number) {
  return apiGet<Record<string, boolean>>(
    "app/managers/get_admin_permissions.php",
    { admin_id: adminId },
  );
}

export function updateAdminPermissions(
  adminId: number,
  permissions: Record<string, boolean>,
) {
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
