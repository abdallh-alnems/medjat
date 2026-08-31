"use client";

import { useQuery } from "@tanstack/react-query";
import {
  listBreaks,
  approveBreak,
  rejectBreak,
  postponeBreak,
} from "@/lib/api/breaks";
import { useToastMutation } from "@/lib/hooks/use-org";

const QK = ["breaks"] as const;

export function useBreaks() {
  return useQuery({ queryKey: [...QK, "list"], queryFn: listBreaks });
}

export function useApproveBreak() {
  return useToastMutation((id: number) => approveBreak(id), {
    invalidate: [QK, ["dashboard"] as const],
  });
}

export function useRejectBreak() {
  return useToastMutation((id: number) => rejectBreak(id), {
    invalidate: [QK, ["dashboard"] as const],
  });
}

export function usePostponeBreak() {
  return useToastMutation((id: number) => postponeBreak(id), { invalidate: [QK] });
}
