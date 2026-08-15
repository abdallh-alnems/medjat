import { apiClient, apiGet, apiPost, unwrapList } from "./client";
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
  const rows = unwrapList<Record<string, unknown>>(raw, [
    "records",
    "items",
    "data",
  ]);

  // The endpoint names these `check_in_time` / `check_out_time`; the rest of the
  // app (and the manual-entry payload) speaks `check_in` / `check_out`. Without
  // this the day table renders "—" in both columns for every employee, which is
  // what it did until now — the row was there, the field name was not.
  return rows.map((r) => ({
    ...(r as unknown as AttendanceRecord),
    check_in: (r.check_in ?? r.check_in_time ?? null) as string | null,
    check_out: (r.check_out ?? r.check_out_time ?? null) as string | null,
  }));
}

/**
 * Fetch a browser-punch photo as an object URL.
 *
 * These images are not public: uploads/ is closed at the web server and this
 * endpoint re-checks that the caller may review the employee, so an `<img src>`
 * pointed at a path would fetch nothing. Same shape as support attachments.
 */
export async function fetchPunchPhoto(
  attendanceId: number,
  which: "check_in" | "check_out",
): Promise<string> {
  const res = await apiClient.get<Blob>("app/attendance/punch_photo.php", {
    params: { attendance_id: attendanceId, which },
    responseType: "blob",
  });
  return URL.createObjectURL(res.data);
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
