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
      http.get(`${API}/app/settings/company.php`, () =>
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
      http.get(`${API}/app/settings/leave_settings.php`, () =>
        HttpResponse.json({
          annual_entitlement: 21,
          sick_entitlement: 10,
          carryover_enabled: true,
          max_carryover: 7,
          encashable: false,
        }),
      ),
    );
    const res = await getLeaveSettings();
    expect(res.annual_entitlement).toBe(21);
  });

  it("statutory payroll: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/app/settings/statutory_payroll.php`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await getStatutoryPayroll();
    expect((res as { message?: string }).message).toBe("denied");
  });

  it("update company settings: success", async () => {
    server.use(
      http.post(`${API}/app/settings/company.php`, () =>
        HttpResponse.json({ id: 1, name: "محّدث", radius: 100 }),
      ),
    );
    const res = await updateCompanySettings({ name: "محّدث" });
    expect(res.name).toBe("محّدث");
  });

  it("required documents: success", async () => {
    server.use(
      http.get(`${API}/app/documents/get_required.php`, () =>
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
      http.get(`${API}/app/documents/get_required.php`, () =>
        HttpResponse.error(),
      ),
    );
    await expect(getRequiredDocuments()).rejects.toBeDefined();
  });
});
