import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  unwrapList,
} from "./client";
import type { Branch, Shift, ScheduleAssignment } from "@/lib/types";

export async function listBranches(): Promise<Branch[]> {
  // Backend returns `{ branches }`.
  const raw = await apiGet<unknown>("v1/branches");
  return unwrapList<Branch>(raw, ["branches", "items", "data"]);
}

export async function getBranch(id: number): Promise<Branch | undefined> {
  const raw = await apiGet<unknown>("v1/branches", { id });
  return unwrapList<Branch>(raw, ["branches", "items", "data"]).find(
    (b) => b.id === id,
  );
}

export function createBranch(data: Partial<Branch>) {
  return apiPost<Branch>("v1/branches", data);
}

export function updateBranch(id: number, data: Partial<Branch>) {
  return apiPatch<Branch>(`v1/branches/${id}`, data);
}

export function updateBranchAttendanceMethod(
  id: number,
  methods: string[],
) {
  return apiPost<Branch>("v1/branches/attendance-method", {
    id,
    attendance_methods: methods,
  });
}

export function generateBranchQr(id: number) {
  return apiPost<{ qr_token: string }>("v1/branches/generate-qr", { id });
}

/** Turn the rotating branch QR on or off for one branch. */
export function setBranchRotatingQr(branchId: number, enabled: boolean) {
  return apiPost<{ message: string }>(
    "v1/branches/attendance-method",
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
  return apiPost<RotatingQrCode>("v1/attendance/branch-qr", {
    branch_id: branchId,
  });
}

export async function listShifts(): Promise<Shift[]> {
  // Backend returns `{ items }`.
  const raw = await apiGet<unknown>("v1/shifts");
  return unwrapList<Shift>(raw, ["items", "data"]);
}

export function createShift(data: Partial<Shift>) {
  return apiPost<Shift>("v1/shifts", data);
}

export function updateShift(id: number, data: Partial<Shift>) {
  return apiPatch<Shift>(`v1/shifts/${id}`, data);
}

export function deleteShift(id: number) {
  return apiDelete<{ status?: string }>(`v1/shifts/${id}`);
}

export function assignShift(shiftId: number, employeeIds: number[]) {
  return apiPost<{ status?: string }>("v1/shifts/assign", {
    shift_id: shiftId,
    employee_ids: employeeIds,
  });
}

export function unassignShift(shiftId: number, employeeIds: number[]) {
  return apiPost<{ status?: string }>("v1/shifts/unassign", {
    shift_id: shiftId,
    employee_ids: employeeIds,
  });
}

export function getWeeklySchedule(week: string) {
  return apiGet<{ week: string; published: boolean; assignments: ScheduleAssignment[] }>(
    "v1/schedule/week",
    { week },
  );
}

export function assignSchedule(data: ScheduleAssignment) {
  return apiPost<{ status?: string }>("v1/schedule/assign", data);
}

export function clearSchedule(data: ScheduleAssignment) {
  return apiPost<{ status?: string }>("v1/schedule/clear", data);
}

export function copyWeek(fromWeek: string, toWeek: string) {
  return apiPost<{ status?: string }>("v1/schedule/copy-week", {
    from: fromWeek,
    to: toWeek,
  });
}

export function publishSchedule(week: string) {
  return apiPost<{ status?: string }>("v1/schedule/publish", { week });
}
