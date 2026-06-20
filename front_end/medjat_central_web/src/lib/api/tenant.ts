import { apiPost } from "./client";
import type { Company } from "@/lib/types";

export function createCompany(name: string, phone?: string) {
  return apiPost<{ company?: Company; tenant_id?: number }>(
    "app/tenant/create.php",
    { name, phone },
  );
}

export function joinCompany(code: string) {
  return apiPost<{ company?: Company; tenant_id?: number }>(
    "app/tenant/join.php",
    { code },
  );
}
