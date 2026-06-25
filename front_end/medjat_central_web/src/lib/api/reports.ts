import { apiGet, unwrapList } from "./client";
import type { ReportData } from "@/lib/types";

export interface ReportPeriod {
  from?: string;
  to?: string;
  month?: string;
  year?: number;
  branch_id?: number;
}

/**
 * Raw report payload from the backend: a flat list of row objects under `items`
 * plus a `summary` map and period markers. The report UI consumes the shared
 * `ReportData` shape (columns + rows), so we derive the table from the rows.
 */
interface RawReport {
  items?: Record<string, string | number | null>[];
  rows?: Record<string, string | number | null>[];
  summary?: Record<string, number>;
  start_date?: string;
  end_date?: string;
  month?: string;
}

/** Humanise a snake_case backend key into a readable column header. */
function humanize(key: string): string {
  return key
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase())
    .trim();
}

/** Map a raw backend report payload to the `ReportData` table shape. */
function toReportData(raw: unknown, title: string): ReportData {
  const r = (raw ?? {}) as RawReport;
  const items = unwrapList<Record<string, string | number | null>>(raw, [
    "items",
    "rows",
    "data",
  ]);

  const columns = items.length > 0 ? Object.keys(items[0]) : [];
  const rows = items.map((item) =>
    columns.map((col) => {
      const v = item[col];
      return v == null ? "" : (v as string | number);
    }),
  );

  const period =
    r.start_date && r.end_date
      ? `${r.start_date} – ${r.end_date}`
      : (r.month ?? "");

  return {
    title,
    period,
    columns: columns.map(humanize),
    rows,
    totals: r.summary,
  };
}

/** Reports return the shared ReportData shape (title/period/columns/rows). */
export async function getAttendanceReport(
  params: ReportPeriod,
): Promise<ReportData> {
  const raw = await apiGet<unknown>(
    "app/reports/attendance.php",
    params as Record<string, unknown>,
  );
  return toReportData(raw, "attendance_report");
}

export async function getPayrollReport(
  params: ReportPeriod,
): Promise<ReportData> {
  const raw = await apiGet<unknown>(
    "app/reports/payroll.php",
    params as Record<string, unknown>,
  );
  return toReportData(raw, "payroll_report");
}

export async function getEmployeesReport(
  params: ReportPeriod,
): Promise<ReportData> {
  const raw = await apiGet<unknown>(
    "app/reports/employees.php",
    params as Record<string, unknown>,
  );
  return toReportData(raw, "employees_report");
}

export async function getLeavesReport(
  params: ReportPeriod,
): Promise<ReportData> {
  const raw = await apiGet<unknown>(
    "app/reports/leaves.php",
    params as Record<string, unknown>,
  );
  return toReportData(raw, "leaves_report");
}
