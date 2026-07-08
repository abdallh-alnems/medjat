import { apiGet, apiPost, unwrapList, asObject } from "./client";
import type { ComplianceItem, DocumentStats } from "@/lib/types";

/** Sweep and mark all past-expiry documents as expired. Returns the count. */
export function markExpiredDocuments() {
  return apiPost<{ marked_expired: number }>("app/documents/mark_expired.php");
}

export async function getExpiringSoon(): Promise<ComplianceItem[]> {
  // Backend returns `{ documents }`.
  const raw = await apiGet<unknown>("app/documents/reports_expiring_soon.php");
  return unwrapList<ComplianceItem>(raw, ["documents", "items", "data"]);
}

export async function getExpired(): Promise<ComplianceItem[]> {
  // Backend returns `{ documents }`.
  const raw = await apiGet<unknown>("app/documents/reports_expired.php");
  return unwrapList<ComplianceItem>(raw, ["documents", "items", "data"]);
}

export async function getMissing(): Promise<ComplianceItem[]> {
  // Backend returns `{ missing_documents }`.
  const raw = await apiGet<unknown>("app/documents/reports_missing.php");
  return unwrapList<ComplianceItem>(raw, [
    "missing_documents",
    "documents",
    "items",
    "data",
  ]);
}

export async function getDocumentStats(): Promise<DocumentStats> {
  // Backend returns `{ stats }`; a flat stats object is accepted too.
  const raw = asObject(await apiGet<unknown>("app/documents/reports_stats.php"));
  const stats = asObject(raw?.stats) ?? raw;
  if (!stats) {
    throw new Error("Unexpected document stats response");
  }
  return stats as unknown as DocumentStats;
}
