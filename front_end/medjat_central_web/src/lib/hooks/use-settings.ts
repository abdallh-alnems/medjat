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
  getAttendanceMethodSettings,
  updateAttendanceMethodSettings,
  type CompanySettings,
  type LeaveSettings,
  type StatutoryPayroll,
  type AttendanceMethodSettings,
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

export function useAttendanceMethodSettings() {
  return useQuery({
    queryKey: [...QK, "attendance-method"],
    queryFn: getAttendanceMethodSettings,
  });
}
export function useUpdateAttendanceMethodSettings() {
  return useToastMutation(
    (data: Partial<AttendanceMethodSettings>) =>
      updateAttendanceMethodSettings(data),
    { invalidate: [[...QK, "attendance-method"] as const] },
  );
}
