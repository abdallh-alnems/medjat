import { apiGet, apiPost } from "./client";
import type { Payslip, PayslipLine, PayrollAuditEntry } from "@/lib/types";

export interface PayrollPeriodParams {
  month: string;
  branch_id?: number;
}

export function listSlips(params: PayrollPeriodParams) {
  return apiGet<Payslip[]>("app/payroll/list_slips.php", params);
}

export function getLivePayroll(month: string) {
  return apiGet<Payslip[]>("app/payroll/live.php", { month });
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

export function getPayrollAudit(month: string) {
  return apiGet<PayrollAuditEntry[]>("app/payroll/audit_log.php", { month });
}
