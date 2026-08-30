import { apiGet, apiPost } from "./client";
import type { Settlement } from "@/lib/types";

/** Backend end-of-service figures (SettlementCalculator::compute / saved row). */
interface SettlementFigures {
  gratuity_amount?: number;
  leave_encashment?: number;
  net_amount?: number;
  [key: string]: unknown;
}

interface RawSettlement {
  employee?: { id?: number };
  last_working_day?: string;
  settlement?: (SettlementFigures & { id?: number; status?: string }) | null;
  suggested?: SettlementFigures;
}

const num = (v: unknown): number => (typeof v === "number" ? v : Number(v) || 0);

/**
 * Map the backend settlement payload to the `Settlement` shape the UI renders.
 * The backend exposes itemised figures (`gratuity_amount`, `leave_encashment`,
 * `net_amount`, …) under `suggested` (live preview) or `settlement` (saved row);
 * the UI shows gratuity / leave encashment / dues / total. We keep every raw
 * figure (so saveSettlement re-sends the full breakdown the backend expects) and
 * add the UI aliases on top: `dues` is the net remainder after gratuity & leave,
 * keeping `gratuity + leave_encashment + dues === total`.
 */
function toSettlement(raw: unknown, employeeId: number): Settlement {
  const r = (raw ?? {}) as RawSettlement;
  const fig: SettlementFigures = r.settlement ?? r.suggested ?? {};
  const gratuity = num(fig.gratuity_amount);
  const leaveEncashment = num(fig.leave_encashment);
  const total = num(fig.net_amount);
  return {
    ...(fig as object),
    id: r.settlement?.id ?? 0,
    employee_id: r.employee?.id ?? employeeId,
    last_working_day: r.last_working_day ?? "",
    gratuity,
    leave_encashment: leaveEncashment,
    dues: Math.round((total - gratuity - leaveEncashment) * 100) / 100,
    total,
    status: r.settlement?.status ?? "draft",
  } as Settlement;
}

export async function getSettlement(employeeId: number): Promise<Settlement> {
  const raw = await apiGet<unknown>("app/settlements/get.php", {
    employee_id: employeeId,
  });
  return toSettlement(raw, employeeId);
}

export async function previewSettlement(
  employeeId: number,
  lastWorkingDay: string,
): Promise<Settlement> {
  const raw = await apiGet<unknown>("app/settlements/preview.php", {
    employee_id: employeeId,
    last_working_day: lastWorkingDay,
  });
  return toSettlement(raw, employeeId);
}

export function saveSettlement(data: Partial<Settlement> & { employee_id: number }) {
  return apiPost<Settlement>("app/settlements/save.php", data);
}

export function approveSettlement(employeeId: number) {
  return apiPost<Settlement>("app/settlements/approve.php", {
    employee_id: employeeId,
  });
}

export function markSettlementPaid(employeeId: number) {
  return apiPost<Settlement>("app/settlements/mark_paid.php", {
    employee_id: employeeId,
  });
}
