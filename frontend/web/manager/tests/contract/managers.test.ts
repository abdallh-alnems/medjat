import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  inviteAdmin,
  listAdmins,
  listInvitations,
  updateAdminPermissions,
} from "@/lib/api/managers";

const API = "/api";

describe("managers contract", () => {
  it("list admins: success", async () => {
    server.use(
      http.get(`${API}/v1/team`, () =>
        HttpResponse.json([
          {
            id: 1,
            name: "مدير",
            email: "a@b.com",
            firebase_uid: "u1",
            role: "hr",
            is_active: true,
            tenant_id: 1,
          },
        ]),
      ),
    );
    const res = await listAdmins();
    expect(res[0]?.role).toBe("hr");
  });

  it("list invitations: empty", async () => {
    server.use(
      http.get(`${API}/v1/team/invitations`, () =>
        HttpResponse.json([]),
      ),
    );
    const res = await listInvitations();
    expect(res).toHaveLength(0);
  });

  it("list admins: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/v1/team`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await listAdmins();
    expect(res).toEqual([]);
  });

  it("invite admin: success", async () => {
    server.use(
      http.post(`${API}/v1/team/invitations`, () =>
        HttpResponse.json({
          invitation_id: 1,
          invitation_code: "CODE-123",
          expires_at: "2026-06-23 00:00:00",
          expires_in_hours: 72,
        }),
      ),
    );
    const res = await inviteAdmin({ email: "x@y.com", role: "hr" });
    expect(res.invitation_code).toBe("CODE-123");
  });

  it("update permissions: success", async () => {
    server.use(
      http.post(`${API}/v1/team/permissions`, () =>
        HttpResponse.json({ status: "ok" }),
      ),
    );
    const res = await updateAdminPermissions(1, ["manage_employees"]);
    expect(res.status).toBe("ok");
  });

  it("list admins: offline rejects", async () => {
    server.use(
      http.get(`${API}/v1/team`, () =>
        HttpResponse.error(),
      ),
    );
    await expect(listAdmins()).rejects.toBeDefined();
  });
});
