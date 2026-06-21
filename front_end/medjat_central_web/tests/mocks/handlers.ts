import { http, HttpResponse } from "msw";

const API = "/api";

/** Success payload (the whole JSON body is the typed response). */
const ok = <T,>(data: T) => HttpResponse.json(data as Record<string, unknown> | unknown[]);

const permissionDenied = () =>
  HttpResponse.json(
    { status: "error", message: "permission_denied" },
    { status: 403 },
  );

const offline = () => HttpResponse.error();

const sessionSuperseded = () =>
  HttpResponse.json(
    { status: "superseded", message: "session superseded" },
    { status: 401 },
  );

/**
 * Base handlers covering the contract-catalog expectations: success payload, empty,
 * 4xx permission-denied, offline, and (for auth) session superseded.
 * Override per-test by adding more specific handlers in the test file.
 */
export const handlers = [
  // ── Auth ──
  http.post(`${API}/app/auth/login.php`, async ({ request }) => {
    const body = (await request.json().catch(() => ({}))) as {
      token?: string;
    };
    if (body.token === "superseded") return sessionSuperseded();
    if (!body.token) return permissionDenied();
    return ok({
      user: {
        id: 1,
        name: "اختباري",
        email: "test@medjat.com",
        firebase_uid: "test-uid",
        role: "general_manager",
        branch_id: null,
        is_active: true,
        tenant_id: 1,
        permissions: null,
      },
      tenant_id: 1,
      tenant_name: "شركة اختبار",
    });
  }),

  http.post(`${API}/app/auth/logout.php`, () => ok({ status: "ok" })),
  http.post(`${API}/app/auth/send_verification.php`, () =>
    ok({ status: "ok" }),
  ),
  http.post(`${API}/app/auth/send_password_reset.php`, () =>
    ok({ status: "ok" }),
  ),
  http.post(`${API}/app/auth/delete_account.php`, () => ok({ status: "ok" })),
  http.get(`${API}/app/auth/notification_prefs.php`, () =>
    ok({ email: true, push: false, in_app: true }),
  ),

  // ── Tenant ──
  http.post(`${API}/app/tenant/create.php`, () =>
    ok({ tenant_id: 2, company: { id: 2, name: "شركة جديدة" } }),
  ),
  http.post(`${API}/app/tenant/join.php`, () =>
    ok({ tenant_id: 3, company: { id: 3, name: "شركة منضم إليها" } }),
  ),

  // ── Dashboard ──
  http.get(`${API}/app/dashboard/overview.php`, () =>
    ok({
      present: 40,
      absent: 5,
      late: 3,
      on_leave: 2,
      attendance_rate: 0.8,
      branch_comparison: [
        {
          branch_id: 1,
          branch_name: "الفرع الأول",
          present: 20,
          total: 25,
          rate: 0.8,
        },
        {
          branch_id: 2,
          branch_name: "الفرع الثاني",
          present: 22,
          total: 25,
          rate: 0.88,
        },
      ],
      pending_leaves: 4,
      pending_breaks: 2,
      payroll: {
        net: 120000,
        base: 100000,
        bonuses: 15000,
        deductions: 5000,
        covers: 120000,
      },
      category_distribution: [{ category: "بدون فئة", count: 50 }],
      expiring_compliance: 3,
    }),
  ),
  http.get(`${API}/app/dashboard/live_attendance.php`, () =>
    ok([
      {
        employee_id: 1,
        employee_name: "موظف ١",
        branch_id: 1,
        status: "present",
        check_in: "08:30",
      },
    ]),
  ),

  // ── Generic empty/error escape hatches for contract tests ──
  http.get(`${API}/app/employees/list.php`, () => ok([])),
  http.get(`${API}/app/dashboard/overview.php/empty`, () => ok(null)),
  http.get(`${API}/app/employees/list.php/denied`, () => permissionDenied()),
  http.get(`${API}/app/employees/list.php/offline`, () => offline()),
];
