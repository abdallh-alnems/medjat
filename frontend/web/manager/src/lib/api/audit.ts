import { apiGet, unwrapList } from "./client";
import type { AuditLogEntry } from "@/lib/types";

export async function listAudit(): Promise<AuditLogEntry[]> {
  // Backend returns `{ items, page, has_more, actors }`.
  const raw = await apiGet<unknown>("v1/audit");
  return unwrapList<AuditLogEntry>(raw, ["items", "data"]);
}
