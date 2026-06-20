"use client";

import { useQuery } from "@tanstack/react-query";
import {
  listBulkAdjustments,
  getBulkAdjustment,
} from "@/lib/api/bulk-adjustments";
import { useToastMutation } from "@/lib/hooks/use-org";
import {
  createBulkAdjustment,
  updateBulkAdjustment,
  deleteBulkAdjustment,
  removeBulkAdjustmentMember,
} from "@/lib/api/bulk-adjustments";
import type { BulkAdjustment } from "@/lib/types";

const QK = ["bulk-adjustments"] as const;

export function useBulkAdjustments() {
  return useQuery({
    queryKey: [...QK, "list"],
    queryFn: listBulkAdjustments,
  });
}

export function useBulkAdjustment(id: number | null) {
  return useQuery({
    queryKey: [...QK, "detail", id],
    queryFn: () => getBulkAdjustment(id as number),
    enabled: id != null,
  });
}

export function useCreateBulkAdjustment() {
  return useToastMutation(
    (data: Partial<BulkAdjustment>) => createBulkAdjustment(data),
    { invalidate: [QK] },
  );
}

export function useUpdateBulkAdjustment() {
  return useToastMutation(
    (args: { id: number; data: Partial<BulkAdjustment> }) =>
      updateBulkAdjustment(args.id, args.data),
    { invalidate: [QK] },
  );
}

export function useDeleteBulkAdjustment() {
  return useToastMutation(
    (id: number) => deleteBulkAdjustment(id),
    { invalidate: [QK] },
  );
}

export function useRemoveBulkMember() {
  return useToastMutation(
    (args: { id: number; employeeId: number }) =>
      removeBulkAdjustmentMember(args.id, args.employeeId),
    { invalidate: [QK] },
  );
}
