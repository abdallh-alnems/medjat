"use client";

import { useQuery } from "@tanstack/react-query";
import {
  listLeaves,
  createLeave,
  createRecurringLeave,
  approveLeave,
  rejectLeave,
  convertToAbsence,
  getLeaveBalance,
} from "@/lib/api/leaves";
import { useToastMutation } from "@/lib/hooks/use-org";
import type { LeaveRequest } from "@/lib/types";

const QK = ["leaves"] as const;

export function useLeaves() {
  return useQuery({ queryKey: [...QK, "list"], queryFn: listLeaves });
}

export function useLeaveBalance(employeeId: number | null) {
  return useQuery({
    queryKey: [...QK, "balance", employeeId],
    queryFn: () => getLeaveBalance(employeeId as number),
    enabled: employeeId != null,
  });
}

export function useCreateLeave() {
  return useToastMutation(
    (data: Partial<LeaveRequest>) => createLeave(data),
    { invalidate: [QK, ["dashboard"] as const] },
  );
}

export function useCreateRecurringLeave() {
  return useToastMutation(
    (data: Partial<LeaveRequest>) => createRecurringLeave(data),
    { invalidate: [QK] },
  );
}

export function useApproveLeave() {
  return useToastMutation((id: number) => approveLeave(id), {
    invalidate: [QK, ["dashboard"] as const],
  });
}

export function useRejectLeave() {
  return useToastMutation((id: number) => rejectLeave(id), {
    invalidate: [QK, ["dashboard"] as const],
  });
}

export function useConvertToAbsence() {
  return useToastMutation((id: number) => convertToAbsence(id), { invalidate: [QK] });
}
