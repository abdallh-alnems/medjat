import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  unwrapList,
} from "./client";
import type { DeductionRule, ManualEntry } from "@/lib/types";

export async function getDeductionRules(): Promise<DeductionRule[]> {
  // Backend returns `{ rules, config }`.
  const raw = await apiGet<unknown>("v1/deduction-rules");
  return unwrapList<DeductionRule>(raw, ["rules", "items", "data"]);
}

export function saveDeductionConfig(rules: Partial<DeductionRule>[]) {
  return apiPost<{ status?: string }>("v1/deduction-rules", {
    rules,
  });
}

export function addManualDeduction(data: Partial<ManualEntry>) {
  return apiPost<ManualEntry>("v1/deductions/manual", data);
}

export function updateManualDeduction(id: number, data: Partial<ManualEntry>) {
  return apiPatch<ManualEntry>(`v1/deductions/manual/${id}`, data);
}

export function deleteManualDeduction(id: number) {
  return apiDelete<{ status?: string }>(`v1/deductions/manual/${id}`);
}

export function addManualBonus(data: Partial<ManualEntry>) {
  return apiPost<ManualEntry>("v1/bonuses/manual", data);
}

export function updateManualBonus(id: number, data: Partial<ManualEntry>) {
  return apiPatch<ManualEntry>(`v1/bonuses/manual/${id}`, data);
}

export function deleteManualBonus(id: number) {
  return apiDelete<{ status?: string }>(`v1/bonuses/manual/${id}`);
}
