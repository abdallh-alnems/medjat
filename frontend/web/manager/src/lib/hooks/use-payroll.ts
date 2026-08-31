"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  listSlips,
  getLivePayroll,
  getLivePayrollOverview,
  generatePayroll,
  approveSlip,
  approveBulkSlips,
  revertSlip,
  markPaid,
  disburse,
  disburseEmployee,
  disburseAll,
  overrideLine,
  getPayrollAudit,
  bankFilePreview,
  type PayrollPeriodParams,
} from "@/lib/api/payroll";
import { useToastMutation } from "@/lib/hooks/use-org";
import type { PayslipLine } from "@/lib/types";

const QK = ["payroll"] as const;

export function usePayrollSlips(params: PayrollPeriodParams) {
  return useQuery({
    queryKey: [...QK, "slips", params],
    queryFn: () => listSlips(params),
  });
}

export function useLivePayroll(month: string) {
  return useQuery({
    queryKey: [...QK, "live", month],
    queryFn: () => getLivePayroll(month),
  });
}

export function useLivePayrollOverview(month: string, enabled = true) {
  return useQuery({
    queryKey: [...QK, "live-overview", month],
    queryFn: () => getLivePayrollOverview(month),
    enabled,
  });
}

export function useDisburseEmployee() {
  return useToastMutation(
    (args: { employeeId: number; month: string }) =>
      disburseEmployee(args.employeeId, args.month),
    { invalidate: [QK] },
  );
}

export function useGeneratePayroll() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (month: string) => generatePayroll(month),
    onSuccess: () => qc.invalidateQueries({ queryKey: [...QK], exact: false }),
  });
}

export function useApproveSlip() {
  return useToastMutation(
    (id: number) => approveSlip(id),
    { invalidate: [QK] },
  );
}

export function useApproveBulk() {
  return useToastMutation(
    (ids: number[]) => approveBulkSlips(ids),
    { invalidate: [QK] },
  );
}

export function useRevertSlip() {
  return useToastMutation((id: number) => revertSlip(id), { invalidate: [QK] });
}

export function useMarkPaid() {
  return useToastMutation((id: number) => markPaid(id), { invalidate: [QK] });
}

export function useDisburse() {
  return useToastMutation((ids: number[]) => disburse(ids), { invalidate: [QK] });
}

export function useDisburseAll() {
  return useToastMutation(
    (month: string) => disburseAll(month),
    { invalidate: [QK] },
  );
}

export function useOverrideLine() {
  return useToastMutation(
    (args: { employeeId: number; month: string; lines: PayslipLine[] }) =>
      overrideLine(args.employeeId, args.month, args.lines),
    { invalidate: [QK] },
  );
}

export function usePayrollAudit(month: string) {
  return useQuery({
    queryKey: [...QK, "audit", month],
    queryFn: () => getPayrollAudit(month),
  });
}

export function useBankFilePreview(month: string | null) {
  return useQuery({
    queryKey: [...QK, "bank-preview", month],
    queryFn: () => bankFilePreview(month as string),
    enabled: !!month,
  });
}
