import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  listLeaves,
  createLeave,
  approveLeave,
  rejectLeave,
  getLeaveBalance,
} from "@/lib/api/leaves";
import type { LeaveRequest, LeaveBalance } from "@/lib/types";

const API = "/api";

const SAMPLE: LeaveRequest = {
  id: 1,
  employee_id: 10,
  employee_name: "أحمد",
  type: "annual",
  from: "2026-06-20",
  to: "2026-06-22",
  days: 2,
  status: "pending",
};

describe("leaves contract", () => {
  it("list: success", async () => {
    server.use(
      http.get(`${API}/app/leaves/list.php`, () =>
        HttpResponse.json([SAMPLE]),
      ),
    );
    const res = await listLeaves();
    expect(res[0]?.days).toBe(2);
  });

  it("list: empty", async () => {
    server.use(
      http.get(`${API}/app/leaves/list.php`, () => HttpResponse.json([])),
    );
    const res = await listLeaves();
    expect(res).toHaveLength(0);
  });

  it("list: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/app/leaves/list.php`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await listLeaves();
    expect(res).toEqual([]);
  });

  it("list: offline rejects", async () => {
    server.use(
      http.get(`${API}/app/leaves/list.php`, () => HttpResponse.error()),
    );
    await expect(listLeaves()).rejects.toBeDefined();
  });

  it("create: success", async () => {
    server.use(
      http.post(`${API}/app/leaves/create.php`, () =>
        HttpResponse.json(SAMPLE),
      ),
    );
    const res = await createLeave({
      employee_id: 10,
      type: "annual",
      start_date: "2026-07-01",
    });
    expect(res.status).toBe("pending");
  });

  it("approve: success", async () => {
    server.use(
      http.post(`${API}/app/leaves/approve.php`, () =>
        HttpResponse.json({ ...SAMPLE, status: "approved" }),
      ),
    );
    const res = await approveLeave(1);
    expect(res.status).toBe("approved");
  });

  it("reject: success", async () => {
    server.use(
      http.post(`${API}/app/leaves/reject.php`, () =>
        HttpResponse.json({ ...SAMPLE, status: "rejected" }),
      ),
    );
    const res = await rejectLeave(1);
    expect(res.status).toBe("rejected");
  });

  it("balance: success", async () => {
    const BALANCE: LeaveBalance = {
      employee_id: 10,
      entitlement: 21,
      used: 5,
      remaining: 16,
      carried_over: 3,
    };
    server.use(
      http.get(`${API}/app/leaves/get_balance.php`, () =>
        HttpResponse.json(BALANCE),
      ),
    );
    const res = await getLeaveBalance(10);
    expect(res.remaining).toBe(16);
  });
});
