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
  photo_url?: string | null;
}

export interface TerminatedEmployee extends Employee {
  last_working_day: string;
  termination_reason?: string | null;
}

export interface Suspension {
  id: number;
  employee_id: number;
  from: string;
  to?: string | null;
  reason?: string | null;
  active: boolean;
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
