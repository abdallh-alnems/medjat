import { apiGet, apiPost, unwrapList } from "./client";
import type { Branch, Shift, ScheduleAssignment } from "@/lib/types";

export async function listBranches(): Promise<Branch[]> {
  // Backend returns `{ branches }`.
  const raw = await apiGet<unknown>("app/branches/list.php");
  return unwrapList<Branch>(raw, ["branches", "items", "data"]);
}

export async function getBranch(id: number): Promise<Branch | undefined> {
  const raw = await apiGet<unknown>("app/branches/list.php", { id });
  return unwrapList<Branch>(raw, ["branches", "items", "data"]).find(
    (b) => b.id === id,
  );
}

export function createBranch(data: Partial<Branch>) {
  return apiPost<Branch>("app/branches/create.php", data);
}

export function updateBranch(id: number, data: Partial<Branch>) {
  return apiPost<Branch>("app/branches/update.php", { id, ...data });
}

export function updateBranchAttendanceMethod(
  id: number,
  methods: string[],
) {
  return apiPost<Branch>("app/branches/update_attendance_method.php", {
    id,
    attendance_methods: methods,
  });
}

export function generateBranchQr(id: number) {
  return apiGet<{ qr_token: string }>("app/branches/generate_qr.php", { id });
}

/** Turn the rotating branch QR on or off for one branch. */
export function setBranchRotatingQr(branchId: number, enabled: boolean) {
  return apiPost<{ message: string }>(
    "app/branches/update_attendance_method.php",
    { branch_id: branchId, rotating_qr_enabled: enabled },
  );
}

export type RotatingQrCode = {
  nonce: string;
  /** Seconds this code stays valid. Longer than `rotate_in`, so windows overlap. */
  expires_in: number;
  /** Seconds the display should wait before asking for the next code. */
  rotate_in: number;
  branch: string;
};

/**
 * Mint the next rotating code for a branch display.
 *
 * POST, not GET: this writes a row. Every backend mutation in this codebase is
 * POST (Auth::requirePost).
 */
export function fetchBranchRotatingQr(branchId: number) {
  return apiPost<RotatingQrCode>("app/attendance/branch_qr_code.php", {
    branch_id: branchId,
  });
}

export async function listShifts(): Promise<Shift[]> {
  // Backend returns `{ items }`.
  const raw = await apiGet<unknown>("app/shifts/list.php");
  return unwrapList<Shift>(raw, ["items", "data"]);
}

export function createShift(data: Partial<Shift>) {
  return apiPost<Shift>("app/shifts/create.php", data);
}

export function updateShift(id: number, data: Partial<Shift>) {
  return apiPost<Shift>("app/shifts/update.php", { id, ...data });
}

export function deleteShift(id: number) {
  return apiPost<{ status?: string }>("app/shifts/delete.php", { id });
}

export function assignShift(shiftId: number, employeeIds: number[]) {
  return apiPost<{ status?: string }>("app/shifts/assign.php", {
    shift_id: shiftId,
    employee_ids: employeeIds,
  });
}

export function unassignShift(shiftId: number, employeeIds: number[]) {
  return apiPost<{ status?: string }>("app/shifts/unassign.php", {
    shift_id: shiftId,
    employee_ids: employeeIds,
  });
}

export function getWeeklySchedule(week: string) {
  return apiGet<{ week: string; published: boolean; assignments: ScheduleAssignment[] }>(
    "app/schedule/week.php",
    { week },
  );
}

export function assignSchedule(data: ScheduleAssignment) {
  return apiPost<{ status?: string }>("app/schedule/assign.php", data);
}

export function clearSchedule(data: ScheduleAssignment) {
  return apiPost<{ status?: string }>("app/schedule/clear.php", data);
}

export function copyWeek(fromWeek: string, toWeek: string) {
  return apiPost<{ status?: string }>("app/schedule/copy_week.php", {
    from: fromWeek,
    to: toWeek,
  });
}

export function publishSchedule(week: string) {
  return apiPost<{ status?: string }>("app/schedule/publish.php", { week });
}
