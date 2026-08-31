import {
  apiDelete,
  apiGet,
  apiPost,
  unwrapList,
} from "./client";
import type { PerformanceReview } from "@/lib/types";

export async function listPerformanceReviews(
  employeeId: number,
): Promise<PerformanceReview[]> {
  // Backend returns `{ items }`.
  const raw = await apiGet<unknown>("v1/performance/reviews", {
    employee_id: employeeId,
  });
  return unwrapList<PerformanceReview>(raw, ["items", "data"]);
}

export function createPerformanceReview(
  employeeId: number,
  data: { period: string; rating: number; notes?: string },
) {
  return apiPost<PerformanceReview>("v1/performance/reviews", {
    employee_id: employeeId,
    ...data,
  });
}

export function deletePerformanceReview(id: number) {
  return apiDelete<{ status?: string }>(`v1/performance/reviews/${id}`);
}
