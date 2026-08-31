import type { Payslip } from "./payroll";

export interface DashboardOverview {
  present: number;
  absent: number;
  late: number;
  on_leave: number;
  attendance_rate: number;
  total_employees: number;
  active_in_scope: number;
  present_yesterday: number;
  total_branches: number;
  branch_comparison: BranchPerformance[];
  pending_leaves: number;
  pending_breaks: number;
  pending_loans: number;
  assets_to_return: number;
  payroll: DashboardPayrollSummary;
  category_distribution: { category: string; count: number }[];
  expiring_compliance: number;
}

export interface BranchPerformance {
  branch_id: number;
  branch_name: string;
  present: number;
  absent: number;
  late: number;
  total: number;
  rate: number;
  late_rate: number;
}

export interface DashboardPayrollSummary {
  net: number;
  base: number;
  bonuses: number;
  deductions: number;
  covers: number;
}

export interface ReportData {
  title: string;
  period: string;
  columns: string[];
  rows: (string | number)[][];
  totals?: Record<string, number>;
}

export interface PayrollAuditEntry {
  id: number;
  actor: string;
  action: string;
  employee_id?: number;
  month: string;
  amount?: number;
  created_at: string;
}

export type { Payslip };
