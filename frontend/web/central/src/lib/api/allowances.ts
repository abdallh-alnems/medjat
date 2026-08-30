import { apiGet, apiPost, unwrapList } from "./client";
import type { Allowance } from "@/lib/types";

export async function listAllowances(employeeId: number): Promise<Allowance[]> {
  // Backend returns `{ allowances, types }`.
  const raw = await apiGet<unknown>("app/allowances/list.php", {
    employee_id: employeeId,
  });
  return unwrapList<Allowance>(raw, ["allowances", "items", "data"]);
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
