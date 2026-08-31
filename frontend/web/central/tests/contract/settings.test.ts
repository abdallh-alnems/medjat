import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  getCompanySettings,
  updateCompanySettings,
  getLeaveSettings,
  getStatutoryPayroll,
} from "@/lib/api/settings";
import { getRequiredDocuments } from "@/lib/api/required-documents";

const API = "/api";

describe("settings contract", () => {
  it("company settings: success", async () => {
    server.use(
      http.get(`${API}/v1/settings/company`, () =>
        HttpResponse.json({
          id: 1,
          name: "شركة اختبار",
          radius: 100,
          currency: "EGP",
        }),
      ),
    );
    const res = await getCompanySettings();
    expect(res.name).toBe("شركة اختبار");
  });

  it("leave settings: success", async () => {
    server.use(
      http.get(`${API}/v1/settings/leave`, () =>
        HttpResponse.json({
          default_annual_leave_days: 21,
          carryover_enabled: true,
          leave_carryover_max_days: 7,
          carryover_expiry_months: null,
          carryover_encash_excess: false,
          carryover_legal_min_days: null,
          auto_rollover_enabled: false,
          apply_legal_seniority_entitlement: true,
        }),
      ),
    );
    const res = await getLeaveSettings();
    expect(res.default_annual_leave_days).toBe(21);
  });

  it("statutory payroll: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/v1/settings/statutory-payroll`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await getStatutoryPayroll();
    expect((res as { message?: string }).message).toBe("denied");
  });

  it("update company settings: success", async () => {
    server.use(
      http.post(`${API}/v1/settings/company`, () =>
        HttpResponse.json({ id: 1, name: "محّدث", radius: 100 }),
      ),
    );
    const res = await updateCompanySettings({ name: "محّدث" });
    expect(res.name).toBe("محّدث");
  });

  it("required documents: success", async () => {
    server.use(
      http.get(`${API}/v1/documents/required`, () =>
        HttpResponse.json([
          { id: 1, name: "إقامة", required: true, expires: true },
        ]),
      ),
    );
    const res = await getRequiredDocuments();
    expect(res[0]?.name).toBe("إقامة");
  });

  it("required documents: offline rejects", async () => {
    server.use(
      http.get(`${API}/v1/documents/required`, () =>
        HttpResponse.error(),
      ),
    );
    await expect(getRequiredDocuments()).rejects.toBeDefined();
  });
});
