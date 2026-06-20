import { apiGet, apiPost } from "./client";
import type { BulkAdjustment } from "@/lib/types";

export function listBulkAdjustments() {
  return apiGet<BulkAdjustment[]>("app/bulk_adjustments/list.php");
}

export function getBulkAdjustment(id: number) {
  return apiGet<BulkAdjustment>("app/bulk_adjustments/get.php", { id });
}

export function createBulkAdjustment(data: Partial<BulkAdjustment>) {
  return apiPost<BulkAdjustment>("app/bulk_adjustments/create.php", data);
}

export function updateBulkAdjustment(id: number, data: Partial<BulkAdjustment>) {
  return apiPost<BulkAdjustment>("app/bulk_adjustments/update.php", {
    id,
    ...data,
  });
}

export function deleteBulkAdjustment(id: number) {
  return apiPost<{ status?: string }>("app/bulk_adjustments/delete.php", { id });
}

export function removeBulkAdjustmentMember(id: number, employeeId: number) {
  return apiPost<{ status?: string }>(
    "app/bulk_adjustments/remove_member.php",
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
  return apiPost<{ status?: string }>("app/payroll/bulk_adjust.php", data);
}
