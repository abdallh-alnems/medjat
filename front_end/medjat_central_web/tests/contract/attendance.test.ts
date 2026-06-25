import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  getBranchAttendance,
  manualCheckIn,
  setDayStatus,
  updateNote,
} from "@/lib/api/attendance";
import type { AttendanceRecord } from "@/lib/types";

const API = "/api";

const SAMPLE: AttendanceRecord = {
  id: 1,
  employee_id: 10,
  date: "2026-06-20",
  status: "present",
  check_in: "08:30",
  check_out: "16:30",
  late_minutes: 0,
  overtime_minutes: 0,
  note: null,
};

describe("attendance contract", () => {
  it("get_branch_attendance: success", async () => {
    server.use(
      http.get(`${API}/app/attendance/get_branch_attendance.php`, () =>
        HttpResponse.json([SAMPLE]),
      ),
    );
    const res = await getBranchAttendance({ branch_id: 1 });
    expect(res[0]?.status).toBe("present");
  });

  it("get_branch_attendance: empty", async () => {
    server.use(
      http.get(`${API}/app/attendance/get_branch_attendance.php`, () =>
        HttpResponse.json([]),
      ),
    );
    const res = await getBranchAttendance();
    expect(res).toHaveLength(0);
  });

  it("get_branch_attendance: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/app/attendance/get_branch_attendance.php`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await getBranchAttendance();
    expect(res).toEqual([]);
  });

  it("get_branch_attendance: offline rejects", async () => {
    server.use(
      http.get(`${API}/app/attendance/get_branch_attendance.php`, () =>
        HttpResponse.error(),
      ),
    );
    await expect(getBranchAttendance()).rejects.toBeDefined();
  });

  it("manual_check_in: success", async () => {
    server.use(
      http.post(`${API}/app/attendance/manual_check_in.php`, () =>
        HttpResponse.json(SAMPLE),
      ),
    );
    const res = await manualCheckIn({
      employee_id: 10,
      date: "2026-06-20",
      check_in: "08:30",
    });
    expect(res.id).toBe(1);
  });

  it("set_day_status: success", async () => {
    server.use(
      http.post(`${API}/app/attendance/set_day_status.php`, () =>
        HttpResponse.json({ ...SAMPLE, status: "absent" }),
      ),
    );
    const res = await setDayStatus(10, "2026-06-20", "absent");
    expect(res.status).toBe("absent");
  });

  it("update_note: success", async () => {
    server.use(
      http.post(`${API}/app/attendance/update_note.php`, () =>
        HttpResponse.json({ ...SAMPLE, note: "updated" }),
      ),
    );
    const res = await updateNote(10, "2026-06-20", "updated");
    expect(res.note).toBe("updated");
  });
});
