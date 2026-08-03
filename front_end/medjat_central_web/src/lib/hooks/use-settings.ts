"use client";

import { useQuery } from "@tanstack/react-query";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  getCompanySettings,
  updateCompanySettings,
  getStatutoryPayroll,
  updateStatutoryPayroll,
  getLeaveSettings,
  updateLeaveSettings,
  getDeductionSettings,
  saveDeductionSettings,
  getAttendanceMethodConfig,
  updateAttendanceConfig,
  updateFaceSettings,
  getBranchNetworks,
  approveBranchNetworks,
  setCompanyGeofence,
  updateBranchAttendanceConfig,
  setScopeMethodOverride,
  type CompanySettings,
  type LeaveSettings,
  type StatutoryPayroll,
} from "@/lib/api/settings";
import type { DeductionRule } from "@/lib/types";

const QK = ["settings"] as const;

export function useCompanySettings() {
  return useQuery({
    queryKey: [...QK, "company"],
    queryFn: getCompanySettings,
  });
}
export function useUpdateCompanySettings() {
  return useToastMutation(
    (data: Partial<CompanySettings>) => updateCompanySettings(data),
    { successMessage: undefined, invalidate: [[...QK, "company"] as const] },
  );
}

export function useStatutoryPayroll() {
  return useQuery({
    queryKey: [...QK, "statutory"],
    queryFn: getStatutoryPayroll,
  });
}
export function useUpdateStatutoryPayroll() {
  return useToastMutation(
    (data: Partial<StatutoryPayroll>) => updateStatutoryPayroll(data),
    { invalidate: [[...QK, "statutory"] as const] },
  );
}

export function useLeaveSettings() {
  return useQuery({
    queryKey: [...QK, "leave"],
    queryFn: getLeaveSettings,
  });
}
export function useUpdateLeaveSettings() {
  return useToastMutation(
    (data: Partial<LeaveSettings>) => updateLeaveSettings(data),
    { invalidate: [[...QK, "leave"] as const] },
  );
}

export function useDeductionSettings() {
  return useQuery({
    queryKey: [...QK, "deductions"],
    queryFn: getDeductionSettings,
  });
}
export function useSaveDeductionSettings() {
  return useToastMutation(
    (rules: Partial<DeductionRule>[]) => saveDeductionSettings(rules),
    { invalidate: [[...QK, "deductions"] as const] },
  );
}

const AM_KEY = [...QK, "attendance-method"] as const;

export function useAttendanceMethodConfig() {
  return useQuery({
    queryKey: AM_KEY,
    queryFn: getAttendanceMethodConfig,
  });
}

export function useUpdateAttendanceConfig() {
  return useToastMutation(
    (data: Parameters<typeof updateAttendanceConfig>[0]) =>
      updateAttendanceConfig(data),
    { invalidate: [AM_KEY, [...QK, "company"] as const] },
  );
}

export function useUpdateFaceSettings() {
  return useToastMutation(
    (data: Parameters<typeof updateFaceSettings>[0]) => updateFaceSettings(data),
    { invalidate: [AM_KEY] },
  );
}

export function useBranchNetworks(branchId: number | null, days?: number) {
  return useQuery({
    queryKey: [...QK, "branch-networks", branchId, days] as const,
    queryFn: () => getBranchNetworks(branchId!, days),
    enabled: branchId != null,
  });
}

export function useApproveBranchNetworks() {
  return useToastMutation(
    (data: Parameters<typeof approveBranchNetworks>[0]) =>
      approveBranchNetworks(data),
    { invalidate: [AM_KEY, [...QK, "branch-networks"] as const] },
  );
}

export function useSetCompanyGeofence() {
  return useToastMutation(
    (data: Parameters<typeof setCompanyGeofence>[0]) =>
      setCompanyGeofence(data),
    { invalidate: [AM_KEY] },
  );
}

export function useUpdateBranchAttendanceConfig() {
  return useToastMutation(
    (data: Parameters<typeof updateBranchAttendanceConfig>[0]) =>
      updateBranchAttendanceConfig(data),
    { invalidate: [AM_KEY] },
  );
}

export function useSetScopeMethodOverride() {
  return useToastMutation(
    (data: Parameters<typeof setScopeMethodOverride>[0]) =>
      setScopeMethodOverride(data),
    { invalidate: [AM_KEY] },
  );
}
