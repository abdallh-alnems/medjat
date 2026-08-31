import type { AttendanceMethod } from "./tenant";

export type EmployeeStatus = "active" | "suspended" | "terminated";

export interface Employee {
  id: number;
  name: string;
  code?: string | null;
  email?: string | null;
  phone?: string | null;
  branch_id: number;
  shift_id?: number | null;
  category_id?: number | null;
  status: EmployeeStatus;
  base_salary: number;
  hire_date: string;
  job_title?: string | null;
  identity_number?: string | null;
  attendance_method?: AttendanceMethod | null;
  /**
   * The supervisor permitted to record this person's attendance on site.
   * NULL means nobody — which is also how "is not in any crew" is expressed;
   * there is no separate flag that could disagree with it.
   */
  crew_supervisor_id?: number | null;
  photo_url?: string | null;
  annual_leave_days?: number | null;
  /** Attached by getEmployeeProfile from the detail envelope. */
  leave_balance?: EmployeeLeaveBalance | null;
}

export interface TerminatedEmployee extends Employee {
  last_working_day: string;
  termination_reason?: string | null;
}

export interface EmployeeLeaveBalance {
  year?: number;
  used_days?: number;
  remaining_days?: number;
  total_days?: number;
  carried_over_days?: number;
  entitlement_days?: number;
}

export type SuspensionPayMode = "unpaid" | "partial" | "full";

export interface Suspension {
  id: number;
  employee_id: number;
  reason: string;
  pay_mode: SuspensionPayMode;
  pay_percentage?: number | null;
  start_date: string;
  end_date?: string | null;
  previous_status?: string | null;
  status: "active" | "ended";
  created_by_name?: string | null;
  ended_by_name?: string | null;
}

export interface EmployeeCategory {
  id: number;
  name: string;
  color?: string | null;
  member_count?: number;
}

export interface BiometricEnrollment {
  employee_id: number;
  type: "face" | "fingerprint";
  enrolled: boolean;
  enrolled_at?: string | null;
}

export interface Warning {
  id: number;
  employee_id: number;
  reason: string;
  date: string;
}

export interface PerformanceReview {
  id: number;
  employee_id: number;
  period: string;
  rating: number;
  notes?: string | null;
}
