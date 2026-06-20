import { apiGet } from "./client";
import type { ReportData } from "@/lib/types";

export interface ReportPeriod {
  from?: string;
  to?: string;
  month?: string;
  year?: number;
  branch_id?: number;
}

/** Reports return the shared ReportData shape (title/period/columns/rows). */
export function getAttendanceReport(params: ReportPeriod) {
  return apiGet<ReportData>(
    "app/reports/attendance.php",
    params as unknown as Record<string, unknown>,
  );
}

export function getPayrollReport(params: ReportPeriod) {
  return apiGet<ReportData>(
    "app/reports/payroll.php",
    params as unknown as Record<string, unknown>,
  );
}

export function getEmployeesReport(params: ReportPeriod) {
  return apiGet<ReportData>(
    "app/reports/employees.php",
    params as unknown as Record<string, unknown>,
  );
}

export function getLeavesReport(params: ReportPeriod) {
  return apiGet<ReportData>(
    "app/reports/leaves.php",
    params as unknown as Record<string, unknown>,
  );
}
