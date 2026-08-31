import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import { login, logout, sendPasswordReset, sendVerification } from "@/lib/api/auth";
import { createCompany, joinCompany } from "@/lib/api/tenant";

const API = "/api";

describe("auth + tenant contract", () => {
  it("login: success returns user + tenant", async () => {
    const res = await login("valid-id-token");
    expect(res.user).toBeDefined();
    expect(res.user?.role).toBe("general_manager");
    expect(res.tenant_id).toBe(1);
  });

  it("login: session superseded forces sign-out response", async () => {
    server.use(
      http.post(`${API}/v1/auth/admin/login`, () =>
        HttpResponse.json(
          { status: "superseded", message: "session superseded" },
          { status: 401 },
        ),
      ),
    );
    const res = await login("superseded");
    expect(res.status).toBe("superseded");
  });

  it("login: 4xx permission-denied / unauthorized", async () => {
    server.use(
      http.post(`${API}/v1/auth/admin/login`, () =>
        HttpResponse.json({ status: "error", message: "unauthorized" }),
      ),
    );
    const res = await login("bad");
    expect(res.status).toBe("error");
  });

  it("login: offline returns a network error", async () => {
    server.use(
      http.post(`${API}/v1/auth/admin/login`, () => HttpResponse.error()),
    );
    await expect(login("offline")).rejects.toBeDefined();
  });

  it("logout / verification / reset return ok", async () => {
    await expect(logout()).resolves.toBeDefined();
    await expect(sendVerification("a@b.com")).resolves.toBeDefined();
    await expect(sendPasswordReset("a@b.com")).resolves.toBeDefined();
  });

  it("tenant: create returns a new tenant id", async () => {
    const res = await createCompany("شركة جديدة");
    expect(res.tenant?.id).toBe(2);
  });

  it("tenant: join returns a tenant id", async () => {
    const res = await joinCompany("INVITE");
    expect(res.tenant?.id).toBe(3);
  });

  it("tenant: empty/missing-data response", async () => {
    server.use(
      http.post(`${API}/v1/tenants`, () =>
        HttpResponse.json({ status: "success", data: null }),
      ),
    );
    const res = await createCompany("");
    expect(res).toBeDefined();
  });
});
