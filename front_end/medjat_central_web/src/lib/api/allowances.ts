import { apiGet, apiPost } from "./client";
import type { Allowance } from "@/lib/types";

export function listAllowances(employeeId: number) {
  return apiGet<Allowance[]>("app/allowances/list.php", { employee_id: employeeId });
}

export function createAllowance(data: Partial<Allowance>) {
  return apiPost<Allowance>("app/allowances/create.php", data);
}

export function updateAllowance(id: number, data: Partial<Allowance>) {
  return apiPost<Allowance>("app/allowances/update.php", { id, ...data });
}

export function deleteAllowance(id: number) {
  return apiPost<{ status?: string }>("app/allowances/delete.php", { id });
}
