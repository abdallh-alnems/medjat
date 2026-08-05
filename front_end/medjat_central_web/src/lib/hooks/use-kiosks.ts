"use client";

import { useMutation, useQuery } from "@tanstack/react-query";
import {
  createKioskAccessCode,
  createKioskPairingCode,
  kioskCapture,
  kioskScoreDistribution,
  listKioskAttempts,
  listKiosks,
  revokeKiosk,
  setEmployeeKioskCode,
} from "@/lib/api/kiosks";
import { useToastMutation } from "@/lib/hooks/use-org";

const QK = ["kiosks"] as const;

export function useKiosks(branchId?: number) {
  return useQuery({
    queryKey: [...QK, "list", branchId ?? "all"],
    queryFn: () => listKiosks(branchId),
    // A tablet's last-seen time is the whole point of the screen; a stale one
    // shows a dead branch as healthy.
    refetchInterval: 60_000,
  });
}

export function useKioskAttempts(params: {
  branchId?: number;
  result?: string;
  limit?: number;
}) {
  return useQuery({
    queryKey: [...QK, "attempts", params],
    queryFn: () => listKioskAttempts(params),
  });
}

export function useKioskDistribution(branchId?: number) {
  return useQuery({
    queryKey: [...QK, "distribution", branchId ?? "all"],
    queryFn: () => kioskScoreDistribution(branchId),
  });
}

/**
 * Pairing and access codes are returned in plaintext exactly once.
 *
 * Deliberately plain `useMutation` rather than the toast wrapper: the code
 * itself has to reach a dialog that displays it, and a toast that flashed it
 * for three seconds would be the wrong place to show a credential somebody has
 * to type on another device.
 */
export function useCreateKioskPairingCode() {
  return useMutation({
    mutationFn: (args: { branchId: number; name?: string }) =>
      createKioskPairingCode(args.branchId, args.name),
  });
}

export function useCreateKioskAccessCode() {
  return useMutation({
    mutationFn: (stationId: number) => createKioskAccessCode(stationId),
  });
}

export function useRevokeKiosk() {
  return useToastMutation(
    (args: { stationId: number; reason?: string }) =>
      revokeKiosk(args.stationId, args.reason),
    { invalidate: [QK] },
  );
}

export function useSetEmployeeKioskCode() {
  return useMutation({
    mutationFn: (args: { employeeId: number; clear?: boolean }) =>
      setEmployeeKioskCode(args.employeeId, args.clear ?? false),
  });
}

/**
 * Fetched on demand rather than with the list: this is biometric imagery, and
 * every call is audited server-side. Prefetching would write an audit trail of
 * views that never happened.
 */
export function useKioskCapture() {
  return useMutation({
    mutationFn: (recognitionLogId: number) => kioskCapture(recognitionLogId),
  });
}
