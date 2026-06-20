"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  getBranchAttendance,
  manualCheckIn,
  manualCheckInBatch,
  setDayStatus,
  updateNote,
  type AttendanceParams,
  type ManualCheckInData,
} from "@/lib/api/attendance";

export function useBranchAttendance(params: AttendanceParams) {
  return useQuery({
    queryKey: ["attendance", "branch", params],
    queryFn: () => getBranchAttendance(params),
  });
}

export function useManualCheckIn() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: ManualCheckInData) => manualCheckIn(data),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ["attendance"], exact: false }),
  });
}

export function useManualCheckInBatch() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (records: ManualCheckInData[]) => manualCheckInBatch(records),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ["attendance"], exact: false }),
  });
}

export function useSetDayStatus() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (args: { employeeId: number; date: string; status: string }) =>
      setDayStatus(args.employeeId, args.date, args.status),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ["attendance"], exact: false }),
  });
}

export function useUpdateNote() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (args: { employeeId: number; date: string; note: string | null }) =>
      updateNote(args.employeeId, args.date, args.note),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ["attendance"], exact: false }),
  });
}
