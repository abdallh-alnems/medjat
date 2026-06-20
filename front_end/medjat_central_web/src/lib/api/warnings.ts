import { apiGet, apiPost } from "./client";
import type { Warning } from "@/lib/types";

export function listWarnings(employeeId: number) {
  return apiGet<Warning[]>("app/employees/get_warnings.php", {
    employee_id: employeeId,
  });
}

export function addWarning(employeeId: number, reason: string, date?: string) {
  return apiPost<Warning>("app/warnings/add.php", {
    employee_id: employeeId,
    reason,
    date,
  });
}

export function deleteWarning(id: number) {
  return apiPost<{ status?: string }>("app/warnings/delete.php", { id });
}
