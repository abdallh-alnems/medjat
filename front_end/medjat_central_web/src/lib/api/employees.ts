import { apiGet, apiPost, unwrapList, asObject } from "./client";
import type {
  Employee,
  TerminatedEmployee,
  ComplianceItem,
  AttendanceRecord,
  FinancialSummary,
  YearToDate,
  RequiredDocument,
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
  const raw = await apiGet<unknown>("app/employees/list.php", params);
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
  const raw = asObject(await apiGet<unknown>(`app/employees/get_profile.php`, { id }));
  const employee = asObject(raw?.employee) ?? raw;
  if (!employee || typeof employee.id !== "number") {
    throw new Error("Unexpected employee profile response");
  }
  return employee as unknown as Employee;
}

export function createEmployee(data: Partial<Employee>) {
  return apiPost<Employee>("app/employees/create.php", data);
}

export function updateEmployee(id: number, data: Partial<Employee>) {
  return apiPost<Employee>("app/employees/update.php", { id, ...data });
}

export function deleteEmployee(id: number) {
  return apiPost<{ status?: string }>("app/employees/delete.php", { id });
}

export async function listTerminated(): Promise<TerminatedEmployee[]> {
  // Backend returns `{ items, total, currency }`.
  const raw = await apiGet<unknown>("app/employees/list_terminated.php");
  return unwrapList<TerminatedEmployee>(raw, ["items", "data"]);
}

export function reactivateEmployee(id: number) {
  return apiPost<Employee>("app/employees/reactivate.php", { id });
}

export function suspendEmployee(id: number, from: string, to?: string, reason?: string) {
  return apiPost<{ status?: string }>("app/employees/suspend.php", {
    id,
    from,
    to,
    reason,
  });
}

export function endSuspension(employeeId: number) {
  return apiPost<{ status?: string }>("app/employees/end_suspension.php", {
    employee_id: employeeId,
  });
}

export async function getAttendanceHistory(
  employeeId: number,
  range: { month?: string; from?: string; to?: string },
): Promise<AttendanceRecord[]> {
  // Backend returns `{ records, summary, from, to }`.
  const raw = await apiGet<unknown>(
    "app/employees/get_attendance_history.php",
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
    await apiGet<unknown>("app/employees/get_financial_summary.php", {
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
    await apiGet<unknown>("app/employees/get_year_to_date.php", {
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
    "app/employees/get_missing_documents.php",
    { employee_id: employeeId },
  );
}

export function getActivationCode(id: number) {
  return apiGet<{ code: string }>("app/employees/activation_code.php", { id });
}

export async function getExpiringCompliance(): Promise<ComplianceItem[]> {
  // Backend returns `{ items, count, expired_count, expiring_count, days }`.
  const raw = await apiGet<unknown>("app/employees/expiring_compliance.php");
  return unwrapList<ComplianceItem>(raw, ["items", "data"]);
}
