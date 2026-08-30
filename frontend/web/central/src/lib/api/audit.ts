import { apiGet, unwrapList } from "./client";
import type { AuditLogEntry } from "@/lib/types";

export async function listAudit(): Promise<AuditLogEntry[]> {
  // Backend returns `{ items, page, has_more, actors }`.
  const raw = await apiGet<unknown>("app/audit/list.php");
  return unwrapList<AuditLogEntry>(raw, ["items", "data"]);
}
