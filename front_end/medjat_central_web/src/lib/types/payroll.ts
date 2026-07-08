// "live" = an unsaved cycle figure straight from the calculator (no payroll
// row generated yet), matching the live overview the mobile app shows.
export type PayslipStatus = "live" | "draft" | "approved" | "paid";

export interface Payslip {
  id: number;
  employee_id: number;
  employee_name?: string;
  month: string;
  base: number;
  allowances_total: number;
  bonuses_total: number;
  deductions_total: number;
  loan_installment: number;
  net: number;
  status: PayslipStatus;
  lines?: PayslipLine[];
  // ── Live-overview extras (populated only via getLivePayrollOverview) ──
  branch_id?: number | null;
  branch_name?: string | null;
  shift_id?: number | null;
  category_ids?: number[];
  job_title?: string | null;
  /** Full-cycle projection (vs the prorated "net so far"). */
  projected_net?: number;
  /** This employee's net for the previous label month, if generated. */
  previous_net?: number | null;
  /** Sum of overtime bonus lines this cycle (for the row chip). */
  overtime_total?: number;
  /** Sum of lateness deduction lines this cycle (for the row chip). */
  late_total?: number;
}

export interface PayslipLine {
  label: string;
  amount: number;
  type: "earning" | "deduction";
}

export interface FinancialSummary {
  employee_id: number;
  month: string;
  earnings: number;
  deductions: number;
  net: number;
}

export interface YearToDate {
  employee_id: number;
  year: number;
  earnings: number;
  deductions: number;
  net: number;
}

export interface Allowance {
  id: number;
  employee_id: number;
  type: string;
  amount: number;
  active: boolean;
  start_month?: string | null;
  end_month?: string | null;
  label?: string | null;
}

export interface DeductionRule {
  id: number | string;
  name: string;
  amount: number;
  active: boolean;
}

export interface ManualEntry {
  id: number;
  employee_id: number;
  amount: number;
  reason?: string | null;
  month: string;
}

export type AdjustmentType = "deduction" | "bonus";
export type AdjustmentScope = "branch" | "shift" | "category" | "all";

export interface BulkAdjustment {
  id: number;
  type: AdjustmentType;
  scope: AdjustmentScope;
  amount: number;
  month: string;
  members: number[];
  created_by: number;
  created_at: string;
}

export type LoanStatus = "pending" | "approved" | "cancelled" | "settled";

export interface Loan {
  id: number;
  employee_id: number;
  employee_name?: string;
  principal: number;
  installment: number;
  remaining: number;
  status: LoanStatus;
  created_at: string;
}

export type SettlementStatus = "draft" | "approved" | "paid";

export interface Settlement {
  id: number;
  employee_id: number;
  last_working_day: string;
  gratuity: number;
  leave_encashment: number;
  dues: number;
  total: number;
  status: SettlementStatus;
}
