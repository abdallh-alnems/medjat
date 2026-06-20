import { apiGet } from "./client";
import type { ComplianceItem, DocumentStats } from "@/lib/types";

export function getExpiringSoon() {
  return apiGet<ComplianceItem[]>("app/documents/reports_expiring_soon.php");
}

export function getExpired() {
  return apiGet<ComplianceItem[]>("app/documents/reports_expired.php");
}

export function getMissing() {
  return apiGet<ComplianceItem[]>("app/documents/reports_missing.php");
}

export function getDocumentStats() {
  return apiGet<DocumentStats>("app/documents/reports_stats.php");
}
