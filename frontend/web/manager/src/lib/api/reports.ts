import { apiGet, asObject, unwrapList } from "./client";
import type {
  OvertimeLateDay,
  OvertimeLateReport,
  OvertimeLateRow,
  OvertimeLateSummary,
  ReportData,
} from "@/lib/types";

export interface ReportPeriod {
  from?: string;
  to?: string;
  month?: string;
  year?: number;
  branch_id?: number;
}

/**
 * The report endpoints read `start_date` / `end_date`; the UI carries the period
 * as `from` / `to`. Translate here — sending `from`/`to` silently fell back to
 * the backend default (first of the month → today) and ignored the picker.
 */
function periodParams(params: ReportPeriod): Record<string, unknown> {
  const { from, to, ...rest } = params;
  return {
    ...rest,
    ...(from ? { start_date: from } : {}),
    ...(to ? { end_date: to } : {}),
  };
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
    "v1/reports/attendance",
    periodParams(params),
  );
  return toReportData(raw, "attendance_report");
}

export async function getPayrollReport(
  params: ReportPeriod,
): Promise<ReportData> {
  // Payroll cycles are monthly: the endpoint takes `month`, not a free range,
  // so the period picker's "from" decides which month is reported on.
  const raw = await apiGet<unknown>("v1/reports/payroll", {
    branch_id: params.branch_id,
    month: params.month ?? (params.from ? params.from.slice(0, 7) : undefined),
  });
  return toReportData(raw, "payroll_report");
}

export async function getEmployeesReport(
  params: ReportPeriod,
): Promise<ReportData> {
  const raw = await apiGet<unknown>(
    "v1/reports/employees",
    params as Record<string, unknown>,
  );
  return toReportData(raw, "employees_report");
}

export async function getLeavesReport(
  params: ReportPeriod,
): Promise<ReportData> {
  const raw = await apiGet<unknown>(
    "v1/reports/leaves",
    periodParams(params),
  );
  return toReportData(raw, "leaves_report");
}

export interface OvertimeLateParams extends ReportPeriod {
  /** Server-side ordering of the rows. */
  sort?: "overtime" | "late" | "name";
  /** Set to also fetch that employee's day-by-day breakdown under `days`. */
  employee_id?: number;
}

/**
 * Overtime & lateness: per-employee totals plus a company-wide summary. Unlike
 * the other reports this keeps its typed shape (rather than being flattened to
 * a generic table) because the page renders summary cards and a drill-down.
 */
export async function getOvertimeLateReport(
  params: OvertimeLateParams,
): Promise<OvertimeLateReport> {
  const raw = await apiGet<unknown>(
    "v1/reports/overtime-late",
    periodParams(params),
  );
  const obj = asObject(raw) ?? {};
  const summary = asObject(obj.summary);
  return {
    start_date: typeof obj.start_date === "string" ? obj.start_date : "",
    end_date: typeof obj.end_date === "string" ? obj.end_date : "",
    items: unwrapList<OvertimeLateRow>(raw, ["items"]),
    summary: (summary ?? {
      total_overtime_minutes: 0,
      total_late_minutes: 0,
      overtime_days: 0,
      late_days: 0,
      employees_with_overtime: 0,
      employees_late: 0,
    }) as unknown as OvertimeLateSummary,
    days: Array.isArray(obj.days) ? (obj.days as OvertimeLateDay[]) : undefined,
  };
}
