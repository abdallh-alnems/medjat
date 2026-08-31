import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  listBranches,
  createBranch,
  generateBranchQr,
  listShifts,
  createShift,
  getWeeklySchedule,
} from "@/lib/api/branches";
import type { Branch, Shift } from "@/lib/types";

const API = "/api";

const BRANCH: Branch = {
  id: 1,
  name: "الفرع الأول",
  lat: 30.04,
  lng: 31.23,
  radius: 100,
};

const SHIFT: Shift = {
  id: 1,
  name: "الوردية الصباحية",
  start_time: "08:00",
  end_time: "16:00",
};

describe("branches & shifts contract", () => {
  it("branches list: success", async () => {
    server.use(
      http.get(`${API}/v1/branches`, () => HttpResponse.json([BRANCH])),
    );
    const res = await listBranches();
    expect(res[0]?.name).toBe("الفرع الأول");
  });

  it("branches list: empty", async () => {
    server.use(
      http.get(`${API}/v1/branches`, () => HttpResponse.json([])),
    );
    const res = await listBranches();
    expect(res).toHaveLength(0);
  });

  it("branches list: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/v1/branches`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await listBranches();
    expect(res).toEqual([]);
  });

  it("branches list: offline rejects", async () => {
    server.use(
      http.get(`${API}/v1/branches`, () => HttpResponse.error()),
    );
    await expect(listBranches()).rejects.toBeDefined();
  });

  it("create branch: success", async () => {
    server.use(
      http.post(`${API}/v1/branches`, () => HttpResponse.json(BRANCH)),
    );
    const res = await createBranch({ name: "الفرع الأول" });
    expect(res.id).toBe(1);
  });

  it("generate qr: success", async () => {
    server.use(
      http.get(`${API}/v1/branches/generate-qr`, () =>
        HttpResponse.json({ qr_token: "tok-123" }),
      ),
    );
    const res = await generateBranchQr(1);
    expect(res.qr_token).toBe("tok-123");
  });

  it("shifts list: success", async () => {
    server.use(
      http.get(`${API}/v1/shifts`, () => HttpResponse.json([SHIFT])),
    );
    const res = await listShifts();
    expect(res[0]?.start_time).toBe("08:00");
  });

  it("create shift: success", async () => {
    server.use(
      http.post(`${API}/v1/shifts`, () => HttpResponse.json(SHIFT)),
    );
    const res = await createShift({ name: "صباحية" });
    expect(res.id).toBe(1);
  });

  it("weekly schedule: success", async () => {
    server.use(
      http.get(`${API}/v1/schedule/week`, () =>
        HttpResponse.json({
          week: "2026-06-20",
          published: false,
          assignments: [],
        }),
      ),
    );
    const res = await getWeeklySchedule("2026-06-20");
    expect(res.published).toBe(false);
  });
});
