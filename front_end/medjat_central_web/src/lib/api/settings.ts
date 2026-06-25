import { apiGet, apiPost, unwrapList } from "./client";
import type { Company, DeductionRule, AttendanceMethod } from "@/lib/types";

export interface CompanySettings extends Company {
  currency?: string;
  weekend?: number[];
}

export interface LeaveSettings {
  annual_entitlement: number;
  sick_entitlement: number;
  carryover_enabled: boolean;
  max_carryover: number;
  encashable: boolean;
}

export interface StatutoryPayroll {
  social_insurance_rate: number;
  tax_rate: number;
  health_insurance_rate: number;
}

export function getCompanySettings() {
  return apiGet<CompanySettings>("app/settings/company.php");
}

export function updateCompanySettings(data: Partial<CompanySettings>) {
  return apiPost<CompanySettings>("app/settings/company.php", data);
}

export function getStatutoryPayroll() {
  return apiGet<StatutoryPayroll>("app/settings/statutory_payroll.php");
}

export function updateStatutoryPayroll(data: Partial<StatutoryPayroll>) {
  return apiPost<StatutoryPayroll>("app/settings/statutory_payroll.php", data);
}

export function getLeaveSettings() {
  return apiGet<LeaveSettings>("app/settings/leave_settings.php");
}

export function updateLeaveSettings(data: Partial<LeaveSettings>) {
  return apiPost<LeaveSettings>("app/settings/leave_settings.php", data);
}

export async function getDeductionSettings(): Promise<DeductionRule[]> {
  // Backend returns `{ rules, config }`.
  const raw = await apiGet<unknown>("app/deductions/get_rules.php");
  return unwrapList<DeductionRule>(raw, ["rules", "items", "data"]);
}

export function saveDeductionSettings(rules: Partial<DeductionRule>[]) {
  return apiPost<{ status?: string }>("app/deductions/save_config.php", {
    rules,
  });
}

export interface AttendanceMethodSettings {
  default_method: AttendanceMethod;
  geofence_strict: boolean;
}

export function getAttendanceMethodSettings() {
  return apiGet<AttendanceMethodSettings>("app/settings/attendance_method.php");
}

export function updateAttendanceMethodSettings(data: Partial<AttendanceMethodSettings>) {
  return apiPost<AttendanceMethodSettings>(
    "app/settings/attendance_method.php",
    data,
  );
}
