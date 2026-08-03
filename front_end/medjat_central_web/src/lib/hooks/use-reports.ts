"use client";

import { useQuery } from "@tanstack/react-query";
import {
  getAttendanceReport,
  getPayrollReport,
  getEmployeesReport,
  getLeavesReport,
  getOvertimeLateReport,
  type OvertimeLateParams,
  type ReportPeriod,
} from "@/lib/api/reports";
import {
  getExpiringSoon,
  getExpired,
  getMissing,
  getDocumentStats,
} from "@/lib/api/document-reports";

export function useAttendanceReport(params: ReportPeriod) {
  return useQuery({
    queryKey: ["reports", "attendance", params],
    queryFn: () => getAttendanceReport(params),
  });
}

export function usePayrollReport(params: ReportPeriod) {
  return useQuery({
    queryKey: ["reports", "payroll", params],
    queryFn: () => getPayrollReport(params),
  });
}

export function useEmployeesReport(params: ReportPeriod) {
  return useQuery({
    queryKey: ["reports", "employees", params],
    queryFn: () => getEmployeesReport(params),
  });
}

export function useLeavesReport(params: ReportPeriod) {
  return useQuery({
    queryKey: ["reports", "leaves", params],
    queryFn: () => getLeavesReport(params),
  });
}

export function useOvertimeLateReport(params: OvertimeLateParams) {
  return useQuery({
    queryKey: ["reports", "overtime-late", params],
    queryFn: () => getOvertimeLateReport(params),
  });
}

/** The day-by-day rows behind one employee's totals (row drill-down). */
export function useOvertimeLateDays(
  params: OvertimeLateParams & { employee_id?: number },
) {
  return useQuery({
    queryKey: ["reports", "overtime-late", "days", params],
    queryFn: () => getOvertimeLateReport(params),
    enabled: !!params.employee_id,
  });
}

export function useDocumentStats() {
  return useQuery({
    queryKey: ["reports", "documents", "stats"],
    queryFn: getDocumentStats,
  });
}

export function useExpiringSoon() {
  return useQuery({
    queryKey: ["reports", "documents", "expiring"],
    queryFn: getExpiringSoon,
  });
}

export function useExpiredDocs() {
  return useQuery({
    queryKey: ["reports", "documents", "expired"],
    queryFn: getExpired,
  });
}

export function useMissingDocs() {
  return useQuery({
    queryKey: ["reports", "documents", "missing"],
    queryFn: getMissing,
  });
}
