import { apiGet, apiPost, unwrapList } from "./client";
import type { Payslip, PayslipLine, PayrollAuditEntry } from "@/lib/types";

export interface PayrollPeriodParams {
  month: string;
  branch_id?: number;
}

export async function listSlips(
  params: PayrollPeriodParams,
): Promise<Payslip[]> {
  // Backend returns `{ items, page }`.
  const raw = await apiGet<unknown>("app/payroll/list_slips.php", params);
  return unwrapList<Payslip>(raw, ["items", "data"]);
}

export async function getLivePayroll(month: string): Promise<Payslip[]> {
  // Backend returns `{ items, total_count, ... }`.
  const raw = await apiGet<unknown>("app/payroll/live.php", { month });
  return unwrapList<Payslip>(raw, ["items", "data"]);
}

export function generatePayroll(month: string) {
  return apiPost<Payslip[]>("app/payroll/generate.php", { month });
}

export function approveSlip(id: number) {
  return apiPost<Payslip>("app/payroll/approve.php", { id });
}

export function approveBulkSlips(ids: number[]) {
  return apiPost<{ status?: string }>("app/payroll/approve_bulk.php", { ids });
}

export function revertSlip(id: number) {
  return apiPost<Payslip>("app/payroll/revert.php", { id });
}

export function markPaid(id: number) {
  return apiPost<Payslip>("app/payroll/mark_paid.php", { id });
}

export function disburse(ids: number[]) {
  return apiPost<{ status?: string }>("app/payroll/disburse.php", { ids });
}

export function disburseAll(month: string) {
  return apiPost<{ status?: string }>("app/payroll/disburse_all.php", { month });
}

export function overrideLine(
  employeeId: number,
  month: string,
  lines: PayslipLine[],
) {
  return apiPost<Payslip>("app/payroll/override_line.php", {
    employee_id: employeeId,
    month,
    lines,
  });
}

export function getSlipPdfUrl(employeeId: number, month: string) {
  return apiGet<{ url: string }>("app/payroll/get_slip_pdf.php", {
    employee_id: employeeId,
    month,
  });
}

export function eosbCalculate(employeeId: number) {
  return apiGet<{ gratuity: number }>("app/payroll/eosb_calculate.php", {
    employee_id: employeeId,
  });
}

export function bankFilePreview(month: string) {
  return apiGet<{ rows: (string | number)[][] }>(
    "app/payroll/bank_file_preview.php",
    { month },
  );
}

export function exportBankFile(month: string) {
  return apiGet<{ csv: string }>("app/payroll/export_bank_file.php", { month });
}

export async function getPayrollAudit(
  month: string,
): Promise<PayrollAuditEntry[]> {
  // Backend returns `{ items, page, has_more }`.
  const raw = await apiGet<unknown>("app/payroll/audit_log.php", { month });
  return unwrapList<PayrollAuditEntry>(raw, ["items", "data"]);
}
