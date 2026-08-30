"use client";

import { useQuery } from "@tanstack/react-query";
import {
  listEmployees,
  getEmployeeProfile,
  listTerminated,
  getExpiringCompliance,
  getAttendanceHistory,
  getFinancialSummary,
  getYearToDate,
  getMissingDocuments,
  getActivationCode,
  type EmployeeListParams,
} from "@/lib/api/employees";

export function useEmployees(params: EmployeeListParams = {}) {
  return useQuery({
    queryKey: ["employees", "list", params],
    queryFn: () => listEmployees(params),
  });
}

export function useEmployee(id: number | null | undefined, enabled = true) {
  return useQuery({
    queryKey: ["employees", "detail", id],
    queryFn: () => getEmployeeProfile(id as number),
    enabled: id != null && enabled,
  });
}

export function useTerminatedEmployees() {
  return useQuery({
    queryKey: ["employees", "terminated"],
    queryFn: listTerminated,
  });
}

export function useExpiringCompliance() {
  return useQuery({
    queryKey: ["employees", "expiring-compliance"],
    queryFn: getExpiringCompliance,
  });
}

export function useAttendanceHistory(
  employeeId: number | null,
  range: { month?: string; from?: string; to?: string },
) {
  return useQuery({
    queryKey: ["employees", "attendance-history", employeeId, range],
    queryFn: () => getAttendanceHistory(employeeId as number, range),
    enabled: employeeId != null,
  });
}

export function useFinancialSummary(employeeId: number | null, month: string) {
  return useQuery({
    queryKey: ["employees", "financial", employeeId, month],
    queryFn: () => getFinancialSummary(employeeId as number, month),
    enabled: employeeId != null,
  });
}

export function useYearToDate(employeeId: number | null, year: number) {
  return useQuery({
    queryKey: ["employees", "ytd", employeeId, year],
    queryFn: () => getYearToDate(employeeId as number, year),
    enabled: employeeId != null,
  });
}

export function useMissingDocuments(employeeId: number | null) {
  return useQuery({
    queryKey: ["employees", "missing-docs", employeeId],
    queryFn: () => getMissingDocuments(employeeId as number),
    enabled: employeeId != null,
  });
}

export function useActivationCode(id: number | null) {
  return useQuery({
    queryKey: ["employees", "activation-code", id],
    queryFn: () => getActivationCode(id as number),
    enabled: id != null,
  });
}
