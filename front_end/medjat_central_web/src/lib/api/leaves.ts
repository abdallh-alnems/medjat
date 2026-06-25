import { apiGet, apiPost, unwrapList } from "./client";
import type {
  LeaveRequest,
  LeaveBalance,
  CarryoverPolicy,
} from "@/lib/types";

export interface LeaveListParams {
  status?: string;
  branch_id?: number;
  category_id?: number;
  q?: string;
}

/** Raw leave row (backend `leaves.*`): dates are start_date/end_date, no days. */
interface RawLeave {
  id: number;
  employee_id: number;
  employee_name?: string;
  type: string;
  start_date?: string;
  end_date?: string;
  from?: string;
  to?: string;
  days?: number;
  status: LeaveRequest["status"];
  reason?: string | null;
}

/** Calendar-day span (inclusive), matching the backend report's DATEDIFF+1. */
function spanDays(from?: string, to?: string): number {
  if (!from || !to) return 0;
  const a = new Date(from).getTime();
  const b = new Date(to).getTime();
  if (Number.isNaN(a) || Number.isNaN(b)) return 0;
  return Math.max(0, Math.round((b - a) / 86_400_000) + 1);
}

function toLeave(r: RawLeave): LeaveRequest {
  const from = r.start_date ?? r.from ?? "";
  const to = r.end_date ?? r.to ?? "";
  return {
    ...r,
    from,
    to,
    days: r.days ?? spanDays(from, to),
  };
}

export async function listLeaves(
  params: LeaveListParams = {},
): Promise<LeaveRequest[]> {
  // Backend returns `{ items, page }` with `start_date`/`end_date` (no `days`).
  const raw = await apiGet<unknown>("app/leaves/list.php", params);
  return unwrapList<RawLeave>(raw, ["items", "data"]).map(toLeave);
}

/** Backend create.php expects `start_date`/`end_date` (end defaults to start). */
export interface CreateLeaveInput {
  employee_id: number;
  type: string;
  start_date: string;
  end_date?: string;
  reason?: string;
}

export function createLeave(data: CreateLeaveInput) {
  return apiPost<LeaveRequest>("app/leaves/create.php", {
    ...data,
    end_date: data.end_date ?? data.start_date,
  });
}

export function createRecurringLeave(data: Partial<LeaveRequest>) {
  return apiPost<LeaveRequest>("app/leaves/create_recurring.php", data);
}

export function approveLeave(id: number) {
  // Backend expects `leave_id` in the body.
  return apiPost<LeaveRequest>("app/leaves/approve.php", { leave_id: id });
}

export function rejectLeave(id: number, reason?: string) {
  return apiPost<LeaveRequest>("app/leaves/reject.php", {
    leave_id: id,
    rejection_reason: reason,
  });
}

export function convertToAbsence(id: number) {
  return apiPost<LeaveRequest>("app/leaves/convert_to_absence.php", { leave_id: id });
}

export function getLeaveBalance(employeeId: number) {
  return apiGet<LeaveBalance>("app/leaves/get_balance.php", {
    employee_id: employeeId,
  });
}

export function rolloverLeaves() {
  return apiPost<{ status?: string }>("app/leaves/rollover.php", {});
}

export async function listCarryoverPolicies(): Promise<CarryoverPolicy[]> {
  // Backend returns `{ policies }`.
  const raw = await apiGet<unknown>("app/leaves/carryover_policies_list.php");
  return unwrapList<CarryoverPolicy>(raw, ["policies", "items", "data"]);
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

export async function listEncashments(): Promise<
  { employee_id: number; employee_name?: string | null; amount: number }[]
> {
  // Backend returns `{ encashments }`.
  const raw = await apiGet<unknown>("app/leaves/encashments_list.php");
  return unwrapList<{
    employee_id: number;
    employee_name?: string | null;
    amount: number;
  }>(raw, ["encashments", "items", "data"]);
}
