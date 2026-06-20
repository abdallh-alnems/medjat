import { apiGet, apiPost } from "./client";
import type {
  LeaveRequest,
  LeaveBalance,
  CarryoverPolicy,
} from "@/lib/types";

export function listLeaves() {
  return apiGet<LeaveRequest[]>("app/leaves/list.php");
}

export function createLeave(data: Partial<LeaveRequest>) {
  return apiPost<LeaveRequest>("app/leaves/create.php", data);
}

export function createRecurringLeave(data: Partial<LeaveRequest>) {
  return apiPost<LeaveRequest>("app/leaves/create_recurring.php", data);
}

export function approveLeave(id: number) {
  return apiPost<LeaveRequest>("app/leaves/approve.php", { id });
}

export function rejectLeave(id: number) {
  return apiPost<LeaveRequest>("app/leaves/reject.php", { id });
}

export function convertToAbsence(id: number) {
  return apiPost<LeaveRequest>("app/leaves/convert_to_absence.php", { id });
}

export function getLeaveBalance(employeeId: number) {
  return apiGet<LeaveBalance>("app/leaves/get_balance.php", {
    employee_id: employeeId,
  });
}

export function rolloverLeaves() {
  return apiPost<{ status?: string }>("app/leaves/rollover.php", {});
}

export function listCarryoverPolicies() {
  return apiGet<CarryoverPolicy[]>("app/leaves/carryover_policies_list.php");
}

export function saveCarryoverPolicy(data: Partial<CarryoverPolicy>) {
  return apiPost<CarryoverPolicy>("app/leaves/carryover_policy_save.php", data);
}

export function deleteCarryoverPolicy(id: number) {
  return apiPost<{ status?: string }>(
    "app/leaves/carryover_policy_delete.php",
    { id },
  );
}

export function listEncashments() {
  return apiGet<{ employee_id: number; amount: number }[]>(
    "app/leaves/encashments_list.php",
  );
}
