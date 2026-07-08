import type { AttendanceMethod } from "./tenant";

export interface Branch {
  id: number;
  name: string;
  lat?: number | null;
  lng?: number | null;
  radius: number;
  address?: string | null;
  attendance_methods?: AttendanceMethod[];
  qr_token?: string | null;
  employee_count?: number;
}

export interface Shift {
  id: number;
  name: string;
  start_time: string;
  end_time: string;
  branch_id?: number | null;
  branch_name?: string | null;
  employee_count?: number;
  members?: number[];
}

export interface ScheduleAssignment {
  employee_id: number;
  shift_id: number;
  day: number;
}

export interface WeeklySchedule {
  week: string;
  published: boolean;
  assignments: ScheduleAssignment[];
}
