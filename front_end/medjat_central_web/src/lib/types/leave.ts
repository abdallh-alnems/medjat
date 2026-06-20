export type LeaveStatus = "pending" | "approved" | "rejected" | "absence";

export interface LeaveRequest {
  id: number;
  employee_id: number;
  employee_name?: string;
  type: string;
  from: string;
  to: string;
  days: number;
  status: LeaveStatus;
  reason?: string | null;
  recurring?: boolean;
}

export interface LeaveBalance {
  employee_id: number;
  entitlement: number;
  used: number;
  remaining: number;
  carried_over: number;
}

export interface CarryoverPolicy {
  id: number;
  max_carryover: number;
  encashable: boolean;
}

export type BreakStatus = "pending" | "approved" | "rejected" | "postponed";

export interface BreakRequest {
  id: number;
  employee_id: number;
  employee_name?: string;
  date: string;
  from_time: string;
  to_time: string;
  status: BreakStatus;
  reason?: string | null;
}
