import { apiGet, apiPost } from "./client";
import type { BreakRequest } from "@/lib/types";

export function listBreaks() {
  return apiGet<BreakRequest[]>("app/breaks/list.php");
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
