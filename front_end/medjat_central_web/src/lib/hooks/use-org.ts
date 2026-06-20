"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  listBranches,
  listShifts,
} from "@/lib/api/branches";
import { listCategories } from "@/lib/api/categories";
import { toast } from "sonner";

export function useBranches() {
  return useQuery({ queryKey: ["org", "branches"], queryFn: listBranches });
}

export function useShifts() {
  return useQuery({ queryKey: ["org", "shifts"], queryFn: listShifts });
}

export function useCategories() {
  return useQuery({
    queryKey: ["org", "categories"],
    queryFn: listCategories,
  });
}

export function useToastMutation<TArgs, TReturn>(
  mutationFn: (args: TArgs) => Promise<TReturn>,
  opts: {
    successMessage?: string;
    invalidate?: readonly (readonly unknown[])[];
    onSuccess?: (data: TReturn) => void;
  } = {},
) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn,
    onSuccess: (data) => {
      if (opts.successMessage) toast.success(opts.successMessage);
      opts.invalidate?.forEach((k) =>
        qc.invalidateQueries({ queryKey: [...k] }),
      );
      opts.onSuccess?.(data);
    },
    onError: () => toast.error("error"),
  });
}
