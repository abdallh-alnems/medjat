import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import { listLoans, createLoan, approveLoan } from "@/lib/api/loans";
import type { Loan } from "@/lib/types";

const API = "/api";

const SAMPLE: Loan = {
  id: 1,
  employee_id: 10,
  employee_name: "أحمد",
  principal: 5000,
  installment: 500,
  remaining: 4500,
  status: "pending",
  created_at: "2026-06-01",
};

describe("loans contract", () => {
  it("list: success", async () => {
    server.use(
      http.get(`${API}/app/loans/list.php`, () => HttpResponse.json([SAMPLE])),
    );
    const res = await listLoans();
    expect(res[0]?.principal).toBe(5000);
  });

  it("list: empty", async () => {
    server.use(
      http.get(`${API}/app/loans/list.php`, () => HttpResponse.json([])),
    );
    const res = await listLoans();
    expect(res).toHaveLength(0);
  });

  it("list: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/app/loans/list.php`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await listLoans();
    expect(res).toEqual([]);
  });

  it("list: offline rejects", async () => {
    server.use(
      http.get(`${API}/app/loans/list.php`, () => HttpResponse.error()),
    );
    await expect(listLoans()).rejects.toBeDefined();
  });

  it("create: success", async () => {
    server.use(
      http.post(`${API}/app/loans/create.php`, () => HttpResponse.json(SAMPLE)),
    );
    const res = await createLoan({ employee_id: 10, principal: 5000 });
    expect(res.status).toBe("pending");
  });

  it("approve: success", async () => {
    server.use(
      http.post(`${API}/app/loans/approve.php`, () =>
        HttpResponse.json({ ...SAMPLE, status: "approved" }),
      ),
    );
    const res = await approveLoan(1);
    expect(res.status).toBe("approved");
  });
});
