import { apiGet, apiPost, unwrapList } from "./client";
import type { AttendanceRecord } from "@/lib/types";

export interface AttendanceParams {
  branch_id?: number;
  date?: string;
}

export async function getBranchAttendance(
  params: AttendanceParams = {},
): Promise<AttendanceRecord[]> {
  // Backend returns `{ records, date }`.
  const raw = await apiGet<unknown>(
    "app/attendance/get_branch_attendance.php",
    params,
  );
  return unwrapList<AttendanceRecord>(raw, ["records", "items", "data"]);
}

export interface ManualCheckInData {
  employee_id: number;
  date: string;
  check_in?: string;
  check_out?: string;
  status?: string;
  note?: string;
}

export function manualCheckIn(data: ManualCheckInData) {
  return apiPost<AttendanceRecord>("app/attendance/manual_check_in.php", data);
}

export function manualCheckInBatch(records: ManualCheckInData[]) {
  return apiPost<{ status?: string }>("app/attendance/manual_check_in.php", {
    batch: records,
  });
}

export function setDayStatus(
  employeeId: number,
  date: string,
  status: string,
) {
  return apiPost<AttendanceRecord>("app/attendance/set_day_status.php", {
    employee_id: employeeId,
    date,
    status,
  });
}

export function updateNote(
  employeeId: number,
  date: string,
  note: string | null,
) {
  return apiPost<AttendanceRecord>("app/attendance/update_note.php", {
    employee_id: employeeId,
    date,
    note,
  });
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
