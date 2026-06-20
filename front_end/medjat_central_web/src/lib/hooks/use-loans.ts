"use client";

import { useQuery } from "@tanstack/react-query";
import { listLoans } from "@/lib/api/loans";
import { useToastMutation } from "@/lib/hooks/use-org";
import { createLoan, approveLoan, cancelLoan } from "@/lib/api/loans";
import type { Loan } from "@/lib/types";

const QK = ["loans"] as const;

export function useLoans() {
  return useQuery({ queryKey: [...QK, "list"], queryFn: listLoans });
}

export function useCreateLoan() {
  return useToastMutation(
    (data: Partial<Loan>) => createLoan(data),
    { invalidate: [QK] },
  );
}

export function useApproveLoan() {
  return useToastMutation((id: number) => approveLoan(id), { invalidate: [QK] });
}

export function useCancelLoan() {
  return useToastMutation((id: number) => cancelLoan(id), { invalidate: [QK] });
}
