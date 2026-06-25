import { apiGet, unwrapList } from "./client";
import type {
  DashboardOverview,
  BranchPerformance,
  LiveAttendance,
  AttendanceStatus,
} from "@/lib/types";

/** Raw shape returned by the live backend (app/dashboard/overview.php). */
interface RawOverview {
  total_employees: number;
  active_in_scope: number;
  present_today: number;
  present_yesterday: number;
  absent_today: number;
  late_today: number;
  on_leave_today: number;
  branch_stats: {
    branch_id: number;
    branch_name: string;
    total_employees: number;
    present: number;
    absent: number;
    late: number;
    attendance_rate: number;
    late_rate: number;
  }[];
  total_branches: number;
  pending_leaves: number;
  pending_loans: number;
  pending_breaks: number;
  assets_to_return: number;
  expiring_compliance: number;
  payroll_summary: {
    employee_count: number;
    total_base: number;
    total_deductions: number;
    total_bonuses: number;
    total_net: number;
  };
  current_month: string;
}

/** Map the backend overview payload to the shape the dashboard UI consumes. */
function toDashboardOverview(raw: RawOverview): DashboardOverview {
  const present = raw.present_today ?? 0;
  const denominator = raw.active_in_scope || 0;
  const attendanceRate =
    denominator > 0 ? Math.round((present / denominator) * 100) : 0;

  const branch_comparison: BranchPerformance[] = (raw.branch_stats ?? []).map(
    (b) => ({
      branch_id: b.branch_id,
      branch_name: b.branch_name,
      present: b.present,
      absent: b.absent,
      late: b.late,
      total: b.total_employees,
      rate: b.attendance_rate,
      late_rate: b.late_rate,
    }),
  );

  return {
    present,
    absent: raw.absent_today ?? 0,
    late: raw.late_today ?? 0,
    on_leave: raw.on_leave_today ?? 0,
    attendance_rate: attendanceRate,
    total_employees: raw.total_employees ?? 0,
    active_in_scope: raw.active_in_scope ?? 0,
    present_yesterday: raw.present_yesterday ?? 0,
    total_branches: raw.total_branches ?? 0,
    branch_comparison,
    pending_leaves: raw.pending_leaves ?? 0,
    pending_breaks: raw.pending_breaks ?? 0,
    pending_loans: raw.pending_loans ?? 0,
    assets_to_return: raw.assets_to_return ?? 0,
    payroll: {
      net: raw.payroll_summary?.total_net ?? 0,
      base: raw.payroll_summary?.total_base ?? 0,
      bonuses: raw.payroll_summary?.total_bonuses ?? 0,
      deductions: raw.payroll_summary?.total_deductions ?? 0,
      covers: raw.payroll_summary?.employee_count ?? 0,
    },
    // The backend overview does not (yet) return a category breakdown.
    category_distribution: [],
    expiring_compliance: raw.expiring_compliance ?? 0,
  };
}

export async function getDashboardOverview(): Promise<DashboardOverview> {
  const raw = await apiGet<RawOverview>("app/dashboard/overview.php");
  // Pass error/empty bodies (null, permission-denied, etc.) through untouched;
  // only adapt a genuine backend overview payload.
  if (!raw || typeof raw !== "object") {
    return raw as unknown as DashboardOverview;
  }
  const looksLikeOverview =
    "present_today" in raw || "payroll_summary" in raw || "branch_stats" in raw;
  return looksLikeOverview
    ? toDashboardOverview(raw)
    : (raw as unknown as DashboardOverview);
}

/** Raw live-board row from the backend (app/dashboard/live_attendance.php). */
interface RawLiveEmployee {
  employee_id: number;
  name: string;
  branch_id: number | null;
  // in | out | absent | leave | pre_shift | not_in
  derived_status: string;
  is_late?: boolean;
  check_in_time?: string | null;
}

/** Map the backend live-board payload to the normalised `LiveAttendance` shape. */
function toLiveAttendance(raw: unknown): LiveAttendance[] {
  const employees = unwrapList<RawLiveEmployee>(raw, ["employees", "items", "data"]);
  return employees.map((e) => {
    const checkedIn = e.derived_status === "in" || e.derived_status === "out";
    const status: AttendanceStatus = checkedIn
      ? e.is_late
        ? "late"
        : "present"
      : e.derived_status === "absent"
        ? "absent"
        : e.derived_status === "leave"
          ? "leave"
          : "not_arrived";
    return {
      employee_id: e.employee_id,
      employee_name: e.name,
      branch_id: e.branch_id ?? null,
      status,
      is_late: !!e.is_late,
      check_in: e.check_in_time ?? null,
    };
  });
}

export async function getLiveAttendance(): Promise<LiveAttendance[]> {
  // Backend returns `{ employees, summary, ... }` with `derived_status` per row.
  const raw = await apiGet<unknown>("app/dashboard/live_attendance.php");
  return toLiveAttendance(raw);
}
