import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  getAttendanceReport,
  getPayrollReport,
  getEmployeesReport,
  getLeavesReport,
  getOvertimeLateReport,
} from "@/lib/api/reports";
import {
  getExpiringSoon,
  getDocumentStats,
} from "@/lib/api/document-reports";
import type { ReportData } from "@/lib/types";

const API = "/api";

const SAMPLE: ReportData = {
  title: "تقرير",
  period: "2026-06",
  columns: ["الاسم", "القيمة"],
  rows: [["أحمد", 100]],
};

describe("reports contract", () => {
  it("attendance report: success", async () => {
    server.use(
      http.get(`${API}/v1/reports/attendance`, () =>
        HttpResponse.json(SAMPLE),
      ),
    );
    const res = await getAttendanceReport({ month: "2026-06" });
    expect(res.rows).toHaveLength(1);
  });

  it("payroll report: empty", async () => {
    server.use(
      http.get(`${API}/v1/reports/payroll`, () =>
        HttpResponse.json({ ...SAMPLE, rows: [] }),
      ),
    );
    const res = await getPayrollReport({ month: "2026-06" });
    expect(res.rows).toHaveLength(0);
  });

  it("employees report: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/v1/reports/employees`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await getEmployeesReport({});
    // Report helpers always resolve to a ReportData with an empty table.
    expect(res.rows).toHaveLength(0);
  });

  it("leaves report: offline rejects", async () => {
    server.use(
      http.get(`${API}/v1/reports/leaves`, () => HttpResponse.error()),
    );
    await expect(getLeavesReport({})).rejects.toBeDefined();
  });

  it("overtime & lateness report: success", async () => {
    let sentUrl = "";
    server.use(
      http.get(`${API}/v1/reports/overtime-late`, ({ request }) => {
        sentUrl = request.url;
        return HttpResponse.json({
          start_date: "2026-06-01",
          end_date: "2026-06-30",
          items: [
            {
              employee_id: 5,
              employee_name: "أحمد",
              overtime_minutes: 150,
              overtime_days: 2,
              late_minutes: 35,
              late_days: 1,
              worst_late_minutes: 35,
              worked_minutes: 900,
              days_present: 3,
            },
          ],
          summary: {
            total_overtime_minutes: 150,
            total_late_minutes: 35,
            overtime_days: 2,
            late_days: 1,
            employees_with_overtime: 1,
            employees_late: 1,
          },
        });
      }),
    );
    const res = await getOvertimeLateReport({
      from: "2026-06-01",
      to: "2026-06-30",
      sort: "late",
    });
    expect(res.items).toHaveLength(1);
    expect(res.summary.total_overtime_minutes).toBe(150);
    // The UI's from/to must reach the backend as start_date/end_date.
    expect(sentUrl).toContain("start_date=2026-06-01");
    expect(sentUrl).toContain("end_date=2026-06-30");
    expect(sentUrl).toContain("sort=late");
  });

  it("overtime & lateness report: 4xx yields an empty, zeroed report", async () => {
    server.use(
      http.get(`${API}/v1/reports/overtime-late`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await getOvertimeLateReport({ from: "2026-06-01", to: "2026-06-30" });
    expect(res.items).toHaveLength(0);
    expect(res.summary.total_late_minutes).toBe(0);
  });

  it("document expiring soon: success", async () => {
    server.use(
      http.get(`${API}/v1/documents/reports/expiring-soon`, () =>
        HttpResponse.json([
          {
            id: 1,
            employee_id: 10,
            employee_name: "أحمد",
            type: "إقامة",
            status: "expiring_soon",
          },
        ]),
      ),
    );
    const res = await getExpiringSoon();
    expect(res[0]?.status).toBe("expiring_soon");
  });

  it("document stats: success", async () => {
    server.use(
      http.get(`${API}/v1/documents/reports/stats`, () =>
        HttpResponse.json({
          total: 100,
          verified: 60,
          pending: 20,
          rejected: 5,
          expiring_soon: 10,
          expired: 3,
          missing: 2,
        }),
      ),
    );
    const res = await getDocumentStats();
    expect(res.verified).toBe(60);
  });
});
