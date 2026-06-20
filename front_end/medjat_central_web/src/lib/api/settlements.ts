import { apiGet, apiPost } from "./client";
import type { Settlement } from "@/lib/types";

export function getSettlement(employeeId: number) {
  return apiGet<Settlement>("app/settlements/get.php", {
    employee_id: employeeId,
  });
}

export function previewSettlement(employeeId: number, lastWorkingDay: string) {
  return apiGet<Settlement>("app/settlements/preview.php", {
    employee_id: employeeId,
    last_working_day: lastWorkingDay,
  });
}

export function saveSettlement(data: Partial<Settlement> & { employee_id: number }) {
  return apiPost<Settlement>("app/settlements/save.php", data);
}

export function approveSettlement(employeeId: number) {
  return apiPost<Settlement>("app/settlements/approve.php", {
    employee_id: employeeId,
  });
}

export function markSettlementPaid(employeeId: number) {
  return apiPost<Settlement>("app/settlements/mark_paid.php", {
    employee_id: employeeId,
  });
}
