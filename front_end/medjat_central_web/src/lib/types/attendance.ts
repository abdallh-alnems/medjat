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

export interface LiveAttendance {
  employee_id: number;
  employee_name: string;
  branch_id: number | null;
  status: AttendanceStatus;
  is_late: boolean;
  check_in?: string | null;
}
