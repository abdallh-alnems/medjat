import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  unwrapList,
} from "./client";
import type { Allowance } from "@/lib/types";

export async function listAllowances(employeeId: number): Promise<Allowance[]> {
  // Backend returns `{ allowances, types }`.
  const raw = await apiGet<unknown>("v1/allowances", {
    employee_id: employeeId,
  });
  return unwrapList<Allowance>(raw, ["allowances", "items", "data"]);
}

export function createAllowance(data: Partial<Allowance>) {
  return apiPost<Allowance>("v1/allowances", data);
}

export function updateAllowance(id: number, data: Partial<Allowance>) {
  return apiPatch<Allowance>(`v1/allowances/${id}`, data);
}

export function deleteAllowance(id: number) {
  return apiDelete<{ status?: string }>(`v1/allowances/${id}`);
}
