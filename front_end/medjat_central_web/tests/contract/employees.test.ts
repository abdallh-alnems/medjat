import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  listEmployees,
  getEmployeeProfile,
  createEmployee,
  reactivateEmployee,
} from "@/lib/api/employees";
import type { Employee } from "@/lib/types";

const API = "/api";

const SAMPLE = {
  id: 1,
  name: "أحمد",
  branch_id: 1,
  status: "active",
  base_salary: 5000,
  hire_date: "2024-01-01",
  firebase_uid: "x",
  role: "viewer",
  is_active: true,
  tenant_id: 1,
};

describe("employees contract", () => {
  it("list: success", async () => {
    server.use(
      http.get(`${API}/app/employees/list.php`, () => HttpResponse.json([SAMPLE])),
    );
    const res = await listEmployees();
    expect((res as Employee[])[0]).toBeTypeOf("object");
  });

  it("list: empty", async () => {
    server.use(
      http.get(`${API}/app/employees/list.php`, () => HttpResponse.json([])),
    );
    const res = await listEmployees();
    expect(res).toHaveLength(0);
  });

  it("list: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/app/employees/list.php`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await listEmployees();
    expect((res as { message?: string }).message).toBe("denied");
  });

  it("list: offline rejects", async () => {
    server.use(
      http.get(`${API}/app/employees/list.php`, () => HttpResponse.error()),
    );
    await expect(listEmployees()).rejects.toBeDefined();
  });

  it("get_profile: success", async () => {
    server.use(
      http.get(`${API}/app/employees/get_profile.php`, () =>
        HttpResponse.json(SAMPLE),
      ),
    );
    const res = await getEmployeeProfile(1);
    expect(res.name).toBe("أحمد");
  });

  it("create: returns created employee", async () => {
    server.use(
      http.post(`${API}/app/employees/create.php`, () =>
        HttpResponse.json({ ...SAMPLE, id: 2, name: "جديد" }),
      ),
    );
    const res = await createEmployee({ name: "جديد" });
    expect(res.id).toBe(2);
  });

  it("reactivate: returns reactivated employee", async () => {
    server.use(
      http.post(`${API}/app/employees/reactivate.php`, () =>
        HttpResponse.json({ ...SAMPLE, status: "active" }),
      ),
    );
    const res = await reactivateEmployee(1);
    expect(res.status).toBe("active");
  });
});
