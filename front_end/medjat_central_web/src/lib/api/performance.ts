import { apiGet, apiPost, unwrapList } from "./client";
import type { PerformanceReview } from "@/lib/types";

export async function listPerformanceReviews(
  employeeId: number,
): Promise<PerformanceReview[]> {
  // Backend returns `{ items }`.
  const raw = await apiGet<unknown>("app/performance/review_list.php", {
    employee_id: employeeId,
  });
  return unwrapList<PerformanceReview>(raw, ["items", "data"]);
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
