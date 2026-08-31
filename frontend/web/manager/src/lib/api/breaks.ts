import { apiGet, apiPost, unwrapList } from "./client";
import type { BreakRequest } from "@/lib/types";

export async function listBreaks(): Promise<BreakRequest[]> {
  // Backend returns `{ breaks }`.
  const raw = await apiGet<unknown>("v1/breaks");
  return unwrapList<BreakRequest>(raw, ["breaks", "items", "data"]);
}

export function approveBreak(id: number) {
  return apiPost<BreakRequest>("v1/breaks/approve", { id });
}

export function rejectBreak(id: number) {
  return apiPost<BreakRequest>("v1/breaks/reject", { id });
}

export function postponeBreak(id: number) {
  return apiPost<BreakRequest>("v1/breaks/postpone", { id });
}

export function createBreakFor(data: Partial<BreakRequest>) {
  return apiPost<BreakRequest>("v1/breaks", data);
}
