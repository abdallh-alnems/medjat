import type { AttendanceMethod } from "./tenant";

export type AttendanceStatus =
  | "present"
  | "absent"
  | "late"
  | "leave"
  | "holiday"
  | "not_arrived";

export interface AttendanceRecord {
  id: number;
  employee_id: number;
  employee_name?: string | null;
  date: string;
  status: AttendanceStatus;
  check_in?: string | null;
  check_out?: string | null;
  late_minutes: number;
  overtime_minutes: number;
  note?: string | null;
}

export type AttendanceOverride =
  | (Omit<BaseAttendanceOverride, "branch_id" | "category_id" | "employee_id"> & {
      type: "branch";
      branch_id: number;
    })
  | (Omit<BaseAttendanceOverride, "branch_id" | "category_id" | "employee_id"> & {
      type: "category";
      category_id: number;
    })
  | (Omit<BaseAttendanceOverride, "branch_id" | "category_id" | "employee_id"> & {
      type: "employee";
      employee_id: number;
    });

interface BaseAttendanceOverride {
  id: number;
  method: AttendanceMethod;
}

/** One employee's overtime / lateness totals over a period. */
export interface OvertimeLateRow {
  employee_id: number;
  employee_name: string;
  job_title?: string | null;
  branch_name?: string | null;
  overtime_minutes: number;
  overtime_days: number;
  late_minutes: number;
  late_days: number;
  worst_late_minutes: number;
  worked_minutes: number;
  days_present: number;
}

export interface OvertimeLateSummary {
  total_overtime_minutes: number;
  total_late_minutes: number;
  overtime_days: number;
  late_days: number;
  employees_with_overtime: number;
  employees_late: number;
}

/** A single day behind an employee's totals (row drill-down). */
export interface OvertimeLateDay {
  date: string;
  check_in_time?: string | null;
  check_out_time?: string | null;
  late_minutes: number;
  overtime_minutes: number;
  worked_minutes: number;
  notes?: string | null;
}

export interface OvertimeLateReport {
  start_date: string;
  end_date: string;
  items: OvertimeLateRow[];
  summary: OvertimeLateSummary;
  days?: OvertimeLateDay[];
}

export interface LiveAttendance {
  employee_id: number;
  employee_name: string;
  branch_id: number | null;
  status: AttendanceStatus;
  is_late: boolean;
  check_in?: string | null;
}
