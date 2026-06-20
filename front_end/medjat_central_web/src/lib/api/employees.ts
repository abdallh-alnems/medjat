import { apiGet, apiPost } from "./client";
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

export function listEmployees(params: EmployeeListParams = {}) {
  return apiGet<Employee[] | EmployeeListResponse>(
    "app/employees/list.php",
    params as Record<string, unknown>,
  );
}

export function getEmployeeProfile(id: number) {
  return apiGet<Employee>(`app/employees/get_profile.php`, { id });
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

export function listTerminated() {
  return apiGet<TerminatedEmployee[]>("app/employees/list_terminated.php");
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

export function getAttendanceHistory(
  employeeId: number,
  range: { month?: string; from?: string; to?: string },
) {
  return apiGet<AttendanceRecord[]>(
    "app/employees/get_attendance_history.php",
    { employee_id: employeeId, ...range },
  );
}

export function getFinancialSummary(employeeId: number, month: string) {
  return apiGet<FinancialSummary>(
    "app/employees/get_financial_summary.php",
    { employee_id: employeeId, month },
  );
}

export function getYearToDate(employeeId: number, year: number) {
  return apiGet<YearToDate>("app/employees/get_year_to_date.php", {
    employee_id: employeeId,
    year,
  });
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

export function getExpiringCompliance() {
  return apiGet<ComplianceItem[]>("app/employees/expiring_compliance.php");
}
