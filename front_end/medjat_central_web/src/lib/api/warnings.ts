import { apiGet, apiPost, unwrapList } from "./client";
import type { Warning } from "@/lib/types";

export async function listWarnings(employeeId: number): Promise<Warning[]> {
  // There is no dedicated warnings list endpoint on the backend; warnings are
  // returned inside the employee profile payload (`{ ..., warnings }`).
  const raw = await apiGet<unknown>("app/employees/get_profile.php", {
    id: employeeId,
  });
  return unwrapList<Warning>(raw, ["warnings", "items", "data"]);
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
