import { apiGet } from "./client";
import type { AuditLogEntry } from "@/lib/types";

export function listAudit() {
  return apiGet<AuditLogEntry[]>("app/audit/list.php");
}
