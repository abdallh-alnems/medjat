import { apiGet, apiPost, unwrapList, asObject } from "./client";
import type { ComplianceItem, DocumentStats } from "@/lib/types";

/** Sweep and mark all past-expiry documents as expired. Returns the count. */
export function markExpiredDocuments() {
  return apiPost<{ marked_expired: number }>("v1/documents/mark-expired");
}

export async function getExpiringSoon(): Promise<ComplianceItem[]> {
  // Backend returns `{ documents }`.
  const raw = await apiGet<unknown>("v1/documents/reports/expiring-soon");
  return unwrapList<ComplianceItem>(raw, ["documents", "items", "data"]);
}

export async function getExpired(): Promise<ComplianceItem[]> {
  // Backend returns `{ documents }`.
  const raw = await apiGet<unknown>("v1/documents/reports/expired");
  return unwrapList<ComplianceItem>(raw, ["documents", "items", "data"]);
}

export async function getMissing(): Promise<ComplianceItem[]> {
  // Backend returns `{ missing_documents }`.
  const raw = await apiGet<unknown>("v1/documents/reports/missing");
  return unwrapList<ComplianceItem>(raw, [
    "missing_documents",
    "documents",
    "items",
    "data",
  ]);
}

export async function getDocumentStats(): Promise<DocumentStats> {
  // Backend returns `{ stats }`; a flat stats object is accepted too.
  const raw = asObject(await apiGet<unknown>("v1/documents/reports/stats"));
  const stats = asObject(raw?.stats) ?? raw;
  if (!stats) {
    throw new Error("Unexpected document stats response");
  }
  return stats as unknown as DocumentStats;
}
