import { apiGet, apiPost } from "./client";
import type { Branch, Shift, ScheduleAssignment } from "@/lib/types";

export function listBranches() {
  return apiGet<Branch[]>("app/branches/list.php");
}

export function getBranch(id: number) {
  return apiGet<Branch>("app/branches/list.php", { id });
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

export function setMethodOverride(data: {
  branch_id?: number;
  category_id?: number;
  employee_id?: number;
  method: string;
}) {
  return apiPost<{ status?: string }>(
    "app/attendance/set_method_override.php",
    data,
  );
}

export function listShifts() {
  return apiGet<Shift[]>("app/shifts/list.php");
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
