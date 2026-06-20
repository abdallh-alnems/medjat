"use client";

import { useQuery } from "@tanstack/react-query";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  listAdmins,
  listInvitations,
  inviteAdmin,
  cancelInvitation,
  resendInvitation,
  setAdminActive,
  removeAdmin,
  getAdminPermissions,
  updateAdminPermissions,
  resetAdminPermissions,
} from "@/lib/api/managers";
import type { ManagerInvitation } from "@/lib/types";

const QK = ["managers"] as const;

export function useAdmins() {
  return useQuery({ queryKey: [...QK, "admins"], queryFn: listAdmins });
}

export function useInvitations() {
  return useQuery({
    queryKey: [...QK, "invitations"],
    queryFn: listInvitations,
  });
}

export function useAdminPermissions(adminId: number | null) {
  return useQuery({
    queryKey: [...QK, "permissions", adminId],
    queryFn: () => getAdminPermissions(adminId as number),
    enabled: adminId != null,
  });
}

export function useInviteAdmin() {
  return useToastMutation(
    (data: { email: string; role: string }) => inviteAdmin(data),
    { invalidate: [[...QK, "invitations"] as const] },
  );
}

export function useCancelInvitation() {
  return useToastMutation(
    (id: number) => cancelInvitation(id),
    { invalidate: [[...QK, "invitations"] as const] },
  );
}

export function useResendInvitation() {
  return useToastMutation(
    (id: number) => resendInvitation(id),
    { invalidate: [[...QK, "invitations"] as const] },
  );
}

export function useSetAdminActive() {
  return useToastMutation(
    (args: { id: number; active: boolean }) => setAdminActive(args.id, args.active),
    { invalidate: [[...QK, "admins"] as const] },
  );
}

export function useRemoveAdmin() {
  return useToastMutation(
    (id: number) => removeAdmin(id),
    { invalidate: [[...QK, "admins"] as const] },
  );
}

export function useUpdateAdminPermissions() {
  return useToastMutation(
    (args: { adminId: number; permissions: Record<string, boolean> }) =>
      updateAdminPermissions(args.adminId, args.permissions as never),
    {
      invalidate: [
        [...QK, "permissions"] as const,
        [...QK, "admins"] as const,
      ],
    },
  );
}

export function useResetAdminPermissions() {
  return useToastMutation(
    (adminId: number) => resetAdminPermissions(adminId),
    {
      invalidate: [
        [...QK, "permissions"] as const,
        [...QK, "admins"] as const,
      ],
    },
  );
}

export type { ManagerInvitation };
