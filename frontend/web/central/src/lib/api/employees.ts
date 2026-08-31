import {
  apiGet,
  apiPatch,
  apiPost,
  asObject,
  unwrapList,
} from "./client";
import type {
  Employee,
  TerminatedEmployee,
  ComplianceItem,
  AttendanceRecord,
  FinancialSummary,
  YearToDate,
  RequiredDocument,
  Suspension,
  SuspensionPayMode,
} from "@/lib/types";

export interface EmployeeListParams {
  search?: string;
  branch_id?: number;
  shift_id?: number;
  category_id?: number;
  status?: string;
  sort?: string;
  page?: number;
  per_page?: number;
}

export interface EmployeeListResponse {
  data: Employee[];
  total?: number;
  current_page?: number;
  last_page?: number;
}

export async function listEmployees(
  params: EmployeeListParams = {},
): Promise<EmployeeListResponse> {
  // Backend returns `{ items, stats, total, page }`; normalise to the
  // `EmployeeListResponse` shape (`data`) the page already understands.
  const raw = await apiGet<unknown>("v1/employees", params);
  const meta = (raw ?? {}) as {
    total?: number;
    page?: number;
    last_page?: number;
  };
  return {
    data: unwrapList<Employee>(raw, ["items", "data"]),
    total: meta.total,
    current_page: meta.page,
    last_page: meta.last_page,
  };
}

export async function getEmployeeProfile(id: number): Promise<Employee> {
  // Backend returns `{ employee, documents, warnings, leave_balance, ... }`;
  // the detail page reads the employee fields at the top level. A flat object
  // (already an employee) is accepted too.
  const raw = asObject(await apiGet<unknown>(`v1/employees/profile`, { id }));
  const employee = asObject(raw?.employee) ?? raw;
  if (!employee || typeof employee.id !== "number") {
    throw new Error("Unexpected employee profile response");
  }
  // Attach the leave balance from the detail envelope (top-level, next to the
  // employee) so the detail page can show it without a second request.
  const leaveBalance = asObject(raw?.leave_balance);
  return {
    ...employee,
    leave_balance: leaveBalance ?? null,
  } as unknown as Employee;
}

/** Full field set accepted by v1/employees (superset of the Employee shape). */
export interface EmployeeCreateFields {
  name: string;
  phone: string;
  national_id: string;
  job_title: string;
  hire_date: string;
  branch_id: number;
  shift_id: number;
  category_ids: number[];
  base_salary: number;
  annual_leave_days: number | null;
  work_start_time: string;
  work_end_time: string;
  weekly_off_days: number[];
  bank_name: string;
  bank_account_number: string;
  bank_iban: string;
  bank_swift: string;
  auto_terminate_at: string | null;
}

export function createEmployee(data: Partial<EmployeeCreateFields>) {
  return apiPost<Employee>("v1/employees", data);
}

export function updateEmployee(id: number, data: Partial<Employee>) {
  return apiPatch<Employee>(`v1/employees/${id}`, data);
}

/**
 * Assign (or clear, with null) the supervisor allowed to record this employee's
 * attendance on site.
 *
 * Its own endpoint rather than a field on updateEmployee: this is the control
 * that grants the only employee-credential exception in the backend, so it
 * carries its own permission check, its own supervision-loop guard and its own
 * audit entry.
 */
export function setCrewSupervisor(employeeId: number, supervisorId: number | null) {
  return apiPost<{ message: string }>("v1/employees/crew-supervisor", {
    employee_id: employeeId,
    supervisor_id: supervisorId,
  });
}

export function deleteEmployee(id: number) {
  return apiPost<{ status?: string }>(`v1/employees/${id}/terminate`);
}

export async function listTerminated(): Promise<TerminatedEmployee[]> {
  // Backend returns `{ items, total, currency }`.
  const raw = await apiGet<unknown>("v1/employees/terminated");
  return unwrapList<TerminatedEmployee>(raw, ["items", "data"]);
}

export function reactivateEmployee(id: number) {
  return apiPost<Employee>("v1/employees/reactivate", { id });
}

export async function getSuspensions(
  employeeId: number,
): Promise<{ suspensions: Suspension[]; active: Suspension | null }> {
  const raw = await apiGet<{
    suspensions?: Suspension[];
    active?: Suspension | null;
  }>("v1/employees/suspensions", { employee_id: employeeId });
  return {
    suspensions: Array.isArray(raw?.suspensions) ? raw.suspensions : [],
    active: raw?.active ?? null,
  };
}

export function suspendEmployee(data: {
  employee_id: number;
  reason: string;
  pay_mode: SuspensionPayMode;
  pay_percentage?: number | null;
  start_date: string;
  end_date?: string | null;
}) {
  return apiPost<{ id: number; message?: string }>(
    "v1/employees/suspend",
    data,
  );
}

export function endSuspension(employeeId: number) {
  return apiPost<{ status?: string }>("v1/employees/end-suspension", {
    employee_id: employeeId,
  });
}

export async function getAttendanceHistory(
  employeeId: number,
  range: { month?: string; from?: string; to?: string },
): Promise<AttendanceRecord[]> {
  // Backend returns `{ records, summary, from, to }`.
  const raw = await apiGet<unknown>(
    "v1/employees/attendance-history",
    { employee_id: employeeId, ...range },
  );
  return unwrapList<AttendanceRecord>(raw, ["records", "items", "data"]);
}

const num = (v: unknown): number => (typeof v === "number" ? v : Number(v) || 0);

export async function getFinancialSummary(
  employeeId: number,
  month: string,
): Promise<FinancialSummary> {
  // Backend returns `{ month, employee, current: { net_salary, total_deductions, … }, … }`.
  const raw = asObject(
    await apiGet<unknown>("v1/employees/financial-summary", {
      employee_id: employeeId,
      month,
    }),
  );
  const current = asObject(raw?.current) ?? {};
  const net = num(current.net_salary);
  const deductions = num(current.total_deductions);
  return {
    employee_id: employeeId,
    month: (raw?.month as string) ?? month,
    deductions,
    net,
    earnings: net + deductions,
  };
}

export async function getYearToDate(
  employeeId: number,
  year: number,
): Promise<YearToDate> {
  // Backend returns `{ year, employee, totals: { total_net, total_deductions, … }, monthly }`.
  const raw = asObject(
    await apiGet<unknown>("v1/employees/year-to-date", {
      employee_id: employeeId,
      year,
    }),
  );
  const totals = asObject(raw?.totals) ?? {};
  return {
    employee_id: employeeId,
    year: num(raw?.year) || year,
    deductions: num(totals.total_deductions),
    net: num(totals.total_net),
    earnings: num(totals.total_base) + num(totals.total_bonuses),
  };
}

export function getMissingDocuments(employeeId: number) {
  return apiGet<RequiredDocument[]>(
    "v1/employees/documents/missing",
    { employee_id: employeeId },
  );
}

export interface ActivationInfo {
  activation_code: string | null;
  activation_token: string | null;
  join_link: string | null;
  expires_at: string | null;
  employee_status: string;
  device_bound: boolean;
  device: {
    platform?: string | null;
    device_model?: string | null;
    last_used_at?: string | null;
  } | null;
}

export function getActivationCode(id: number) {
  return apiGet<ActivationInfo>("v1/employees/activation-code", { id });
}

/** Regenerate the activation code. For an active employee this also revokes the
 *  bound device (id must go in the query string — the endpoint reads $_GET). */
export function regenerateActivationCode(id: number) {
  return apiPost<ActivationInfo>(
    `v1/employees/activation-code?id=${id}`,
  );
}

export async function getExpiringCompliance(): Promise<ComplianceItem[]> {
  // Backend returns `{ items, count, expired_count, expiring_count, days }`.
  const raw = await apiGet<unknown>("v1/employees/expiring-compliance");
  return unwrapList<ComplianceItem>(raw, ["items", "data"]);
}
