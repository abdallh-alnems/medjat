import { describe, it, expect } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import {
  listEmployees,
  getEmployeeProfile,
  createEmployee,
  reactivateEmployee,
} from "@/lib/api/employees";

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
      http.get(`${API}/v1/employees`, () => HttpResponse.json([SAMPLE])),
    );
    const res = await listEmployees();
    // listEmployees normalises the backend `{ items }` payload to `{ data }`.
    expect(res.data[0]).toBeTypeOf("object");
  });

  it("list: empty", async () => {
    server.use(
      http.get(`${API}/v1/employees`, () => HttpResponse.json([])),
    );
    const res = await listEmployees();
    expect(res.data).toHaveLength(0);
  });

  it("list: 4xx permission-denied", async () => {
    server.use(
      http.get(`${API}/v1/employees`, () =>
        HttpResponse.json({ message: "denied" }, { status: 403 }),
      ),
    );
    const res = await listEmployees();
    // List helpers always resolve to a (possibly empty) array, never an error body.
    expect(res.data).toHaveLength(0);
  });

  it("list: offline rejects", async () => {
    server.use(
      http.get(`${API}/v1/employees`, () => HttpResponse.error()),
    );
    await expect(listEmployees()).rejects.toBeDefined();
  });

  it("get_profile: success", async () => {
    server.use(
      http.get(`${API}/v1/employees/profile`, () =>
        HttpResponse.json(SAMPLE),
      ),
    );
    const res = await getEmployeeProfile(1);
    expect(res.name).toBe("أحمد");
  });

  it("create: returns created employee", async () => {
    server.use(
      http.post(`${API}/v1/employees`, () =>
        HttpResponse.json({ ...SAMPLE, id: 2, name: "جديد" }),
      ),
    );
    const res = await createEmployee({ name: "جديد" });
    expect(res.id).toBe(2);
  });

  it("reactivate: returns reactivated employee", async () => {
    server.use(
      http.post(`${API}/v1/employees/reactivate`, () =>
        HttpResponse.json({ ...SAMPLE, status: "active" }),
      ),
    );
    const res = await reactivateEmployee(1);
    expect(res.status).toBe("active");
  });
});
