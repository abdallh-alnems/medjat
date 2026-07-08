import { apiGet, apiPost, unwrapList } from "./client";
import type { Company, DeductionRule, AttendanceMethod } from "@/lib/types";

export interface CompanySettings extends Company {
  currency?: string;
  weekend?: number[];
  timezone?: string;
  /** Payroll/attendance cycle start day of month (1-28). */
  cycle_start_day?: number;
  /** ISO weekday the work week starts on (1=Mon..7=Sun). */
  week_start_day?: number;
  /** Branding / letterhead fields used on certificates & letters. */
  commercial_register?: string;
  company_phone?: string;
  company_address?: string;
}

export interface LeaveSettings {
  default_annual_leave_days: number;
  carryover_enabled: boolean;
  leave_carryover_max_days: number | null;
  carryover_expiry_months: number | null;
  carryover_encash_excess: boolean;
  carryover_legal_min_days: number | null;
  auto_rollover_enabled: boolean;
  apply_legal_seniority_entitlement: boolean;
}

export interface TaxBracket {
  /** Ceiling of this bracket; null = open-ended (top) tier. */
  up_to: number | null;
  /** Percentage rate 0–100. */
  rate: number;
}

export interface StatutoryPayroll {
  social_insurance_enabled: boolean;
  si_employee_rate: number | null;
  si_min_wage: number | null;
  si_max_wage: number | null;
  income_tax_enabled: boolean;
  income_tax_brackets: TaxBracket[];
  tax_personal_exemption: number | null;
  eosb_enabled: boolean;
  eosb_days_per_year: number | null;
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

// ── Attendance method resolution (company > branch > category > employee) ──
// All data is served by `app/settings/company.php` (GET). Writes go to
// company.php (tenant-level), branches/update_attendance_method.php (branch),
// and attendance/set_method_override.php (category / employee).

export interface AttendanceBranchOverride {
  id: number;
  name: string;
  qr_code?: string | null;
  attendance_methods: AttendanceMethod[] | null;
  gps_radius_meters: number;
  lat: number | null;
  lng: number | null;
  cycle_start_day: number | null;
}

export interface AttendanceCategoryOverride {
  id: number;
  name: string;
  color?: string | null;
  employee_count: number;
  attendance_methods: AttendanceMethod[] | null;
}

export interface AttendanceEmployeeOverride {
  id: number;
  name: string;
  branch_name?: string | null;
  attendance_methods: AttendanceMethod[] | null;
}

export interface AttendanceMethodConfig {
  attendance_methods: AttendanceMethod[];
  manual_attendance_admin_ids: number[] | null;
  allow_offline_attendance: boolean;
  gps_latitude: number | null;
  gps_longitude: number | null;
  gps_radius_meters: number | null;
  branches: AttendanceBranchOverride[];
  categories: AttendanceCategoryOverride[];
  employee_overrides: AttendanceEmployeeOverride[];
}

/** Full attendance-method configuration comes from company.php. */
export function getAttendanceMethodConfig() {
  return apiGet<AttendanceMethodConfig>("app/settings/company.php");
}

/** Tenant-wide methods + manual admins + offline toggle. */
export function updateAttendanceConfig(data: {
  attendance_methods: AttendanceMethod[];
  manual_attendance_admin_ids?: number[] | null;
  allow_offline_attendance?: boolean;
}) {
  return apiPost<{ message?: string }>("app/settings/company.php", data);
}

/** Company-wide GPS geofence. Pass nulls to clear it. */
export function setCompanyGeofence(data: {
  gps_latitude: number | null;
  gps_longitude: number | null;
  gps_radius_meters: number | null;
}) {
  return apiPost<{ message?: string }>("app/settings/company.php", data);
}

/** Per-branch override (methods=null → inherit company). */
export function updateBranchAttendanceConfig(data: {
  branch_id: number;
  attendance_methods: AttendanceMethod[] | null;
  gps_radius_meters?: number;
  allow_offline_attendance?: boolean | null;
}) {
  return apiPost<{ message?: string }>(
    "app/branches/update_attendance_method.php",
    data,
  );
}

/** Per-category / per-employee override (methods=null → inherit). */
export function setScopeMethodOverride(data: {
  scope_type: "category" | "employee";
  scope_id: number;
  attendance_methods: AttendanceMethod[] | null;
}) {
  return apiPost<{ message?: string }>(
    "app/attendance/set_method_override.php",
    data,
  );
}
