import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  asObject,
  unwrapList,
} from "./client";
import type { BulkAdjustment } from "@/lib/types";

export async function listBulkAdjustments(): Promise<BulkAdjustment[]> {
  // Backend returns `{ items }`.
  const raw = await apiGet<unknown>("v1/bulk-adjustments");
  return unwrapList<BulkAdjustment>(raw, ["items", "data"]);
}

export async function getBulkAdjustment(id: number): Promise<BulkAdjustment> {
  // Backend returns `{ batch, members }`; the detail page reads the batch fields
  // at the top level plus `members`. A flat batch object is accepted too.
  const raw = asObject(await apiGet<unknown>("v1/bulk-adjustments/get", { id }));
  const batch = asObject(raw?.batch) ?? raw;
  if (!batch || typeof batch.id !== "number") {
    throw new Error("Unexpected bulk adjustment response");
  }
  const members = Array.isArray(raw?.members)
    ? (raw.members as number[])
    : Array.isArray(batch.members)
      ? (batch.members as number[])
      : [];
  return { ...(batch as unknown as BulkAdjustment), members };
}

export function createBulkAdjustment(data: Partial<BulkAdjustment>) {
  return apiPost<BulkAdjustment>("v1/bulk-adjustments", data);
}

export function updateBulkAdjustment(id: number, data: Partial<BulkAdjustment>) {
  return apiPatch<BulkAdjustment>(`v1/bulk-adjustments/${id}`, data);
}

export function deleteBulkAdjustment(id: number) {
  return apiDelete<{ status?: string }>(`v1/bulk-adjustments/${id}`);
}

export function removeBulkAdjustmentMember(id: number, employeeId: number) {
  return apiPost<{ status?: string }>(
    "v1/bulk-adjustments/remove-member",
    { id, employee_id: employeeId },
  );
}

/** Quick in-place bulk adjust (no tracked batch). */
export function quickBulkAdjust(data: {
  type: "deduction" | "bonus";
  amount: number;
  month: string;
  employee_ids: number[];
}) {
  return apiPost<{ status?: string }>("v1/payroll/bulk-adjust", data);
}
