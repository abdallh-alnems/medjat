import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  listSlips,
  generatePayroll,
  approveSlip,
  overrideLine,
} from "@/lib/api/payroll";
import type { Payslip } from "@/lib/types";

const API = "/api";

const SAMPLE: Payslip = {
  id: 1,
  employee_id: 10,
  employee_name: "أحمد",
  month: "2026-06",
  base: 5000,
  allowances_total: 500,
  bonuses_total: 200,
  deductions_total: 300,
  loan_installment: 100,
  net: 5300,
  status: "draft",
};

describe("payroll contract", () => {
  it("list_slips: success", async () => {
    server.use(
      http.get(`${API}/app/payroll/list_slips.php`, () =>
        HttpResponse.json([SAMPLE]),
      ),
    );
    const res = await listSlips({ month: "2026-06" });
    expect(res[0]?.net).toBe(5300);
  });

  it("list_slips: empty", async () => {
    server.use(
      http.get(`${API}/app/payroll/list_slips.php`, () =>
        HttpResponse.json([]),
      ),
    );
    const res = await listSlips({ month: "2026-06" });
    expect(res).toHaveLength(0);
  });

  it("list_slips: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/app/payroll/list_slips.php`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await listSlips({ month: "2026-06" });
    expect((res as { message?: string }).message).toBe("denied");
  });

  it("list_slips: offline rejects", async () => {
    server.use(
      http.get(`${API}/app/payroll/list_slips.php`, () => HttpResponse.error()),
    );
    await expect(listSlips({ month: "2026-06" })).rejects.toBeDefined();
  });

  it("generate: success", async () => {
    server.use(
      http.post(`${API}/app/payroll/generate.php`, () =>
        HttpResponse.json([SAMPLE]),
      ),
    );
    const res = await generatePayroll("2026-06");
    expect(res[0]?.month).toBe("2026-06");
  });

  it("approve: success", async () => {
    server.use(
      http.post(`${API}/app/payroll/approve.php`, () =>
        HttpResponse.json({ ...SAMPLE, status: "approved" }),
      ),
    );
    const res = await approveSlip(1);
    expect(res.status).toBe("approved");
  });

  it("override_line: success", async () => {
    server.use(
      http.post(`${API}/app/payroll/override_line.php`, () =>
        HttpResponse.json(SAMPLE),
      ),
    );
    const res = await overrideLine(10, "2026-06", [
      { label: "x", amount: 50, type: "earning" },
    ]);
    expect(res.id).toBe(1);
  });
});
