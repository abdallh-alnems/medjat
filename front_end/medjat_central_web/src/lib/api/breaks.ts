import { apiGet, apiPost, unwrapList } from "./client";
import type { BreakRequest } from "@/lib/types";

export async function listBreaks(): Promise<BreakRequest[]> {
  // Backend returns `{ breaks }`.
  const raw = await apiGet<unknown>("app/breaks/list.php");
  return unwrapList<BreakRequest>(raw, ["breaks", "items", "data"]);
}

export function approveBreak(id: number) {
  return apiPost<BreakRequest>("app/breaks/approve.php", { id });
}

export function rejectBreak(id: number) {
  return apiPost<BreakRequest>("app/breaks/reject.php", { id });
}

export function postponeBreak(id: number) {
  return apiPost<BreakRequest>("app/breaks/postpone.php", { id });
}

export function createBreakFor(data: Partial<BreakRequest>) {
  return apiPost<BreakRequest>("app/breaks/create_for.php", data);
}
