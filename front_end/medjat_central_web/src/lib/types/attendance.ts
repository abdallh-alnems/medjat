import type { AttendanceMethod } from "./tenant";

export type AttendanceStatus =
  | "present"
  | "absent"
  | "late"
  | "leave"
  | "holiday";

export interface AttendanceRecord {
  id: number;
  employee_id: number;
  date: string;
  status: AttendanceStatus;
  check_in?: string | null;
  check_out?: string | null;
  late_minutes: number;
  overtime_minutes: number;
  note?: string | null;
}

export interface AttendanceOverride {
  id: number;
  branch_id?: number | null;
  category_id?: number | null;
  employee_id?: number | null;
  method: AttendanceMethod;
}

export interface LiveAttendance {
  employee_id: number;
  employee_name: string;
  branch_id: number;
  status: AttendanceStatus;
  check_in?: string | null;
}
