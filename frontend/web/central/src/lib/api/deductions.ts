import { apiGet, apiPost, unwrapList } from "./client";
import type { DeductionRule, ManualEntry } from "@/lib/types";

export async function getDeductionRules(): Promise<DeductionRule[]> {
  // Backend returns `{ rules, config }`.
  const raw = await apiGet<unknown>("app/deductions/get_rules.php");
  return unwrapList<DeductionRule>(raw, ["rules", "items", "data"]);
}

export function saveDeductionConfig(rules: Partial<DeductionRule>[]) {
  return apiPost<{ status?: string }>("app/deductions/save_config.php", {
    rules,
  });
}

export function addManualDeduction(data: Partial<ManualEntry>) {
  return apiPost<ManualEntry>("app/deductions/add_manual.php", data);
}

export function updateManualDeduction(id: number, data: Partial<ManualEntry>) {
  return apiPost<ManualEntry>("app/deductions/update_manual.php", {
    id,
    ...data,
  });
}

export function deleteManualDeduction(id: number) {
  return apiPost<{ status?: string }>("app/deductions/delete_manual.php", { id });
}

export function addManualBonus(data: Partial<ManualEntry>) {
  return apiPost<ManualEntry>("app/bonuses/add_manual.php", data);
}

export function updateManualBonus(id: number, data: Partial<ManualEntry>) {
  return apiPost<ManualEntry>("app/bonuses/update_manual.php", { id, ...data });
}

export function deleteManualBonus(id: number) {
  return apiPost<{ status?: string }>("app/bonuses/delete_manual.php", { id });
}
