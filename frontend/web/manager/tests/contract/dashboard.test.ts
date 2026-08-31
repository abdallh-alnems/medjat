import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import { getDashboardOverview, getLiveAttendance } from "@/lib/api/dashboard";

const API = "/api";

describe("dashboard contract", () => {
  it("overview: success payload has expected shape", async () => {
    const res = await getDashboardOverview();
    expect(res.present).toBe(40);
    expect(res.branch_comparison).toHaveLength(2);
    expect(res.payroll.net).toBe(120000);
    expect(res.expiring_compliance).toBe(3);
  });

  it("overview: empty/no-data response", async () => {
    server.use(
      http.get(`${API}/v1/dashboard/overview`, () => HttpResponse.json(null)),
    );
    const res = await getDashboardOverview();
    expect(res).toBeNull();
  });

  it("overview: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/v1/dashboard/overview`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await getDashboardOverview();
    expect((res as { message?: string }).message).toBe("denied");
  });

  it("overview: offline rejects", async () => {
    server.use(
      http.get(`${API}/v1/dashboard/overview`, () => HttpResponse.error()),
    );
    await expect(getDashboardOverview()).rejects.toBeDefined();
  });

  it("live attendance: returns board rows", async () => {
    const res = await getLiveAttendance();
    expect(res[0]?.status).toBe("present");
  });
});
