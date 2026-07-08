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

  // ── Tenant ── (mirrors live backend shape: { success, tenant, user })
  http.post(`${API}/app/tenant/create.php`, () =>
    ok({
      success: true,
      tenant: { id: 2, name: "شركة جديدة" },
      user: { id: 1, tenant_id: 2, role: "general_manager", role_key: "general_manager" },
    }),
  ),
  http.post(`${API}/app/tenant/join.php`, () =>
    ok({
      success: true,
      tenant: { id: 3, name: "شركة منضم إليها" },
      user: { id: 1, tenant_id: 3, role: "hr", role_key: "hr" },
    }),
  ),
  http.post(`${API}/app/tenant/accept_invitation.php`, () =>
    ok({
      success: true,
      tenant: { id: 4, name: "شركة الدعوة" },
      user: { id: 1, tenant_id: 4, role: "hr", role_key: "hr" },
    }),
  ),

  // ── Dashboard ──
  // Mirrors the live backend shape (app/dashboard/overview.php); the api layer
  // adapts it to the DashboardOverview the UI consumes.
  http.get(`${API}/app/dashboard/overview.php`, () =>
    ok({
      total_employees: 50,
      active_in_scope: 50,
      present_today: 40,
      present_yesterday: 38,
      absent_today: 5,
      late_today: 3,
      on_leave_today: 2,
      branch_stats: [
        {
          branch_id: 1,
          branch_name: "الفرع الأول",
          total_employees: 25,
          present: 20,
          absent: 3,
          late: 2,
          attendance_rate: 80,
          late_rate: 8,
        },
        {
          branch_id: 2,
          branch_name: "الفرع الثاني",
          total_employees: 25,
          present: 22,
          absent: 2,
          late: 1,
          attendance_rate: 88,
          late_rate: 4,
        },
      ],
      total_branches: 2,
      pending_leaves: 4,
      pending_loans: 1,
      pending_breaks: 2,
      assets_to_return: 0,
      expiring_compliance: 3,
      payroll_summary: {
        employee_count: 50,
        total_base: 100000,
        total_deductions: 5000,
        total_bonuses: 15000,
        total_net: 120000,
      },
      current_month: "2026-06",
    }),
  ),
  http.get(`${API}/app/dashboard/live_attendance.php`, () =>
    ok({
      employees: [
        {
          employee_id: 1,
          name: "موظف ١",
          branch_id: 1,
          derived_status: "in",
          is_late: false,
          check_in_time: "08:30",
        },
      ],
      summary: { total: 1, in: 1 },
      date: "2026-06-24",
    }),
  ),

  // ── Generic empty/error escape hatches for contract tests ──
  http.get(`${API}/app/employees/list.php`, () => ok([])),
  http.get(`${API}/app/dashboard/overview.php/empty`, () => ok(null)),
  http.get(`${API}/app/employees/list.php/denied`, () => permissionDenied()),
  http.get(`${API}/app/employees/list.php/offline`, () => offline()),
];
