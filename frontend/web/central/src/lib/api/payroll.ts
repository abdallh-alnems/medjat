import { apiGet, apiPost, unwrapList, asObject } from "./client";
import type {
  Payslip,
  PayslipStatus,
  PayslipLine,
  PayrollAuditEntry,
} from "@/lib/types";

/** Raw row shape returned by `live.php` (different field names than a slip). */
interface LivePayrollRow {
  id?: number;
  employee_id: number;
  employee_name?: string;
  job_title?: string | null;
  branch_id?: number | null;
  branch_name?: string | null;
  shift_id?: number | null;
  category_ids?: number[];
  month: string;
  base_salary?: number;
  total_bonuses?: number;
  total_deductions?: number;
  net_salary?: number;
  projected_net?: number;
  previous_net?: number | null;
  status?: string;
  deductions_breakdown?: BreakdownItem[];
  bonuses_breakdown?: BreakdownItem[];
}

interface BreakdownItem {
  type?: string;
  amount?: number;
  description?: string;
  date?: string;
}

const SAVED_STATUSES: PayslipStatus[] = ["draft", "approved", "paid"];

const sumBy = (items: BreakdownItem[] | undefined, type: string) =>
  (items ?? [])
    .filter((b) => b.type === type)
    .reduce((s, b) => s + Number(b.amount ?? 0), 0);

/** Map one live-overview row onto the Payslip shape the UI renders. */
function mapLiveRow(r: LivePayrollRow): Payslip {
  const lines: Payslip["lines"] = [
    ...(r.bonuses_breakdown ?? []).map((b) => ({
      label: b.description ?? "",
      amount: Number(b.amount ?? 0),
      type: "earning" as const,
    })),
    ...(r.deductions_breakdown ?? []).map((d) => ({
      label: d.description ?? "",
      amount: Number(d.amount ?? 0),
      type: "deduction" as const,
    })),
  ];
  return {
    id: r.id ?? 0,
    employee_id: r.employee_id,
    employee_name: r.employee_name,
    month: r.month,
    base: Number(r.base_salary ?? 0),
    allowances_total: 0,
    bonuses_total: Number(r.total_bonuses ?? 0),
    deductions_total: Number(r.total_deductions ?? 0),
    loan_installment: 0,
    net: Number(r.net_salary ?? 0),
    status: SAVED_STATUSES.includes(r.status as PayslipStatus)
      ? (r.status as PayslipStatus)
      : "live",
    branch_id: r.branch_id ?? null,
    branch_name: r.branch_name ?? null,
    shift_id: r.shift_id ?? null,
    category_ids: Array.isArray(r.category_ids) ? r.category_ids : [],
    job_title: r.job_title ?? null,
    projected_net: Number(r.projected_net ?? r.net_salary ?? 0),
    previous_net: r.previous_net ?? null,
    overtime_total: sumBy(r.bonuses_breakdown, "overtime"),
    late_total: sumBy(r.deductions_breakdown, "late"),
    lines,
  };
}

export interface PreviousSummary {
  month: string;
  employee_count: number;
  total_net: number;
}

export interface LivePayrollOverview {
  slips: Payslip[];
  /** Tenant cycle start day (1–28) — drives the month default / labels. */
  cycleStartDay: number;
  /** Earliest active-employee hire date, or null. Caps the picker. */
  minHireDate: string | null;
  currency: string;
  /** Previous label month's saved totals (null when none generated). */
  previousSummary: PreviousSummary | null;
}

/**
 * Full live overview: the mapped rows plus the cycle metadata the page needs to
 * default to the completed cycle and gate disburse — same payload the app uses.
 */
export async function getLivePayrollOverview(
  month: string,
): Promise<LivePayrollOverview> {
  const raw = await apiGet<unknown>("app/payroll/live.php", { month });
  const obj = asObject(raw) ?? {};
  const rows = unwrapList<LivePayrollRow>(raw, ["items", "data"]);
  const prev = asObject(obj.previous_summary);
  return {
    slips: rows.map(mapLiveRow),
    cycleStartDay: Number(obj.cycle_start_day ?? 1),
    minHireDate:
      typeof obj.min_hire_date === "string" ? obj.min_hire_date : null,
    currency: typeof obj.currency === "string" ? obj.currency : "EGP",
    previousSummary: prev
      ? {
          month: String(prev.month ?? ""),
          employee_count: Number(prev.employee_count ?? 0),
          total_net: Number(prev.total_net ?? 0),
        }
      : null,
  };
}

/** One-tap disburse for a single employee — walks generate → approve → pay. */
export function disburseEmployee(employeeId: number, month: string) {
  return apiPost<{ result?: string; payroll_id?: number }>(
    "app/payroll/disburse.php",
    { employee_id: employeeId, month },
  );
}

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
  // Backend returns `{ items, total_count, ... }` where each row uses the
  // calculator's field names. Map them onto the Payslip shape the UI expects,
  // tagging un-generated rows as "live" (same as the mobile app's overview).
  const raw = await apiGet<unknown>("app/payroll/live.php", { month });
  const rows = unwrapList<LivePayrollRow>(raw, ["items", "data"]);
  return rows.map(mapLiveRow);
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
