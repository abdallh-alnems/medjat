import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  getAttendanceReport,
  getPayrollReport,
  getEmployeesReport,
  getLeavesReport,
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
      http.get(`${API}/app/reports/attendance.php`, () =>
        HttpResponse.json(SAMPLE),
      ),
    );
    const res = await getAttendanceReport({ month: "2026-06" });
    expect(res.rows).toHaveLength(1);
  });

  it("payroll report: empty", async () => {
    server.use(
      http.get(`${API}/app/reports/payroll.php`, () =>
        HttpResponse.json({ ...SAMPLE, rows: [] }),
      ),
    );
    const res = await getPayrollReport({ month: "2026-06" });
    expect(res.rows).toHaveLength(0);
  });

  it("employees report: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/app/reports/employees.php`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await getEmployeesReport({});
    expect((res as { message?: string }).message).toBe("denied");
  });

  it("leaves report: offline rejects", async () => {
    server.use(
      http.get(`${API}/app/reports/leaves.php`, () => HttpResponse.error()),
    );
    await expect(getLeavesReport({})).rejects.toBeDefined();
  });

  it("document expiring soon: success", async () => {
    server.use(
      http.get(`${API}/app/documents/reports_expiring_soon.php`, () =>
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
      http.get(`${API}/app/documents/reports_stats.php`, () =>
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
