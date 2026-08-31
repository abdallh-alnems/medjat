import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  getEmployeeDocuments,
  verifyDocument,
} from "@/lib/api/documents";
import { getBiometricStatus, deleteBiometric } from "@/lib/api/biometric";

const API = "/api";

describe("documents + biometric contract", () => {
  it("documents: list success", async () => {
    server.use(
      http.get(`${API}/v1/employees/documents`, () =>
        HttpResponse.json([
          {
            id: 1,
            employee_id: 1,
            type: "هوية",
            file_url: "https://x/y.pdf",
            status: "pending",
            uploaded_at: "2026-01-01",
          },
        ]),
      ),
    );
    const res = await getEmployeeDocuments(1);
    expect(res[0]?.type).toBe("هوية");
  });

  it("documents: empty", async () => {
    server.use(
      http.get(`${API}/v1/employees/documents`, () =>
        HttpResponse.json([]),
      ),
    );
    const res = await getEmployeeDocuments(1);
    expect(res).toHaveLength(0);
  });

  it("documents: verify returns verified", async () => {
    server.use(
      http.post(`${API}/v1/employees/documents/verify`, () =>
        HttpResponse.json({ id: 1, status: "verified" }),
      ),
    );
    const res = await verifyDocument(1);
    expect(res.status).toBe("verified");
  });

  it("biometric: status", async () => {
    server.use(
      http.get(`${API}/v1/biometric/status`, () =>
        HttpResponse.json({ employee_id: 1, type: "face", enrolled: true }),
      ),
    );
    const res = await getBiometricStatus(1);
    expect(res.enrolled).toBe(true);
  });

  it("biometric: delete returns ok", async () => {
    server.use(
      http.delete(`${API}/v1/biometric/:id`, () =>
        HttpResponse.json({ status: "ok" }),
      ),
    );
    const res = await deleteBiometric(1);
    expect(res.status).toBe("ok");
  });
});
