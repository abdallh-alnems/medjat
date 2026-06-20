import { apiGet, apiPost } from "./client";
import type { PerformanceReview } from "@/lib/types";

export function listPerformanceReviews(employeeId: number) {
  return apiGet<PerformanceReview[]>("app/performance/review_list.php", {
    employee_id: employeeId,
  });
}

export function createPerformanceReview(
  employeeId: number,
  data: { period: string; rating: number; notes?: string },
) {
  return apiPost<PerformanceReview>("app/performance/review_create.php", {
    employee_id: employeeId,
    ...data,
  });
}

export function deletePerformanceReview(id: number) {
  return apiPost<{ status?: string }>("app/performance/review_delete.php", {
    id,
  });
}
